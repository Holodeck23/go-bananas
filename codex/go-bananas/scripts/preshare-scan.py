#!/usr/bin/env python3
"""Scan staged blobs without printing matched content. Python standard library only."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

# Signals, not a guarantee of privacy. Names and narrative context need review.
RULES = [
    ('private-key', re.compile(r'-----BEGIN (?:[A-Z]+ )?PRIVATE KEY-----')),
    ('credential-token', re.compile(r'\b(?:sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[A-Z0-9]{16})\b')),
    ('credential-assignment', re.compile(r'''(?i)\b(?:api[_-]?key|access[_-]?token|auth[_-]?token|password|secret)\b\s*[:=]\s*["']?([^\s"'`;,]{8,})''')),
    ('personal-path', re.compile(r'/(?:Users|home)/(?!Shared(?:/|\b)|<)[A-Za-z0-9_.-]+(?:/|\b)')),
    ('chat-transcript', re.compile(r'(?i)^\s*(?:user|assistant|human|system)\s*:\s+\S')),
    ('chat-export', re.compile(r'''(?i)(?:<oai-''' + r'''mem-citation>|<\|(?:im_start|im_end)\|>|"role"\s*:\s*"(?:user|assistant|system)")''')),
    ('contact-field', re.compile(r'(?i)^\s*(?:phone|mobile|street address|home address|date of birth)\s*:\s*\S')),
]
EMAIL = re.compile(r'\b[A-Za-z0-9.!#$%&*+/=?^_`{|}~-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b')
SYNTHETIC_DOMAINS = {'example.com', 'example.org', 'example.net', 'example.invalid'}
PLACEHOLDERS = {'placeholder', 'changeme', 'redacted', 'your_api_key', 'your_token', 'example'}


def git(*args):
    return subprocess.check_output(['git', *args], stderr=subprocess.PIPE)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--deny-file', type=Path,
                        help='Private local file: one literal name/identifier per line; never echoed')
    args = parser.parse_args()
    try:
        git('rev-parse', '--show-toplevel')
        names = git('diff', '--cached', '--name-only', '--diff-filter=ACMR', '-z').split(b'\0')
        denied = []
        if args.deny_file:
            denied = [s.strip() for s in args.deny_file.read_text().splitlines()
                      if s.strip() and not s.lstrip().startswith('#')]
        findings = []
        scanned = 0
        for raw in filter(None, names):
            name = raw.decode('utf-8', 'surrogateescape')
            basename = Path(name).name.lower()
            if (basename == '.env' or basename.startswith('.env.')) and basename not in {'.env.example', '.env.sample', '.env.template'}:
                findings.append((name, 0, 'sensitive-filename'))
            if basename in {'credentials.json', 'id_rsa', 'id_ed25519'}:
                findings.append((name, 0, 'sensitive-filename'))
            mode = git('ls-files', '--stage', '-z', '--', name).split(b' ', 1)[0]
            if mode in (b'120000', b'160000'):
                findings.append((name, 0, 'linked-content-needs-review'))
                continue
            content = git('show', ':' + name)
            if b'\0' in content:
                findings.append((name, 0, 'binary-content-needs-review'))
                continue
            try:
                text = content.decode('utf-8')
            except UnicodeDecodeError:
                findings.append((name, 0, 'non-utf8-content-needs-review'))
                continue
            scanned += 1
            for number, line in enumerate(text.splitlines(), 1):
                for category, pattern in RULES:
                    match = pattern.search(line)
                    if match:
                        if category == 'credential-assignment':
                            value = match.group(1).lower().strip('<>{}')
                            if value in PLACEHOLDERS or value.startswith(('$', '${', 'os.environ', 'process.env')):
                                continue
                        findings.append((name, number, category))
                for match in EMAIL.finditer(line):
                    address = match.group().lower()
                    domain = address.rsplit('@', 1)[1]
                    if domain not in SYNTHETIC_DOMAINS and not address.endswith('@users.noreply.github.com'):
                        findings.append((name, number, 'email-address'))
                if any(item.casefold() in line.casefold() for item in denied):
                    findings.append((name, number, 'private-deny-list'))
        for name, number, category in sorted(set(findings)):
            # No excerpts, secret values, deny-list entries or repository paths.
            print(json.dumps({'file': name, 'line': number, 'category': category}, ensure_ascii=True))
        if findings:
            print('BLOCKED: resolve the findings before sharing. No matched content was printed.')
            return 1
        print(f'Staged scan: {scanned} text files; no configured pattern matches.')
        print('Still review the exact staged diff for personal names, client details and private conversation context.')
        return 0
    except (subprocess.CalledProcessError, OSError, UnicodeError):
        # Tool stderr or a decoding exception can contain sensitive blob content.
        print('Scan unavailable: inspect Git state or the deny-file locally. Nothing is cleared for sharing.', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
