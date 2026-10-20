"""Privacy checks exercise staged content; test data is synthetic."""
import os
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'src/scripts/preshare-scan.py'


class PreshareScan(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.repo = Path(self.tmp.name)
        self.env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM='1')
        self.git('init', '-q')

    def git(self, *args):
        return subprocess.check_output(['git', *args], cwd=self.repo, env=self.env, stderr=subprocess.PIPE)

    def stage(self, value, name='HANDOVER.md'):
        (self.repo / name).write_bytes(value if isinstance(value, bytes) else value.encode())
        self.git('add', '--', name)

    def scan(self, *args, code=0):
        p = subprocess.run(['python3', str(SCRIPT), *args], cwd=self.repo,
                           env=self.env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.assertEqual(p.returncode, code, p.stdout + p.stderr)
        return p.stdout + p.stderr

    def test_clean_handover(self):
        self.stage('# Handover\nGoal: finish authorized work.\nVerified: tests passed.\n')
        self.assertIn('1 text files', self.scan())

    def test_credentials_block_without_echo(self):
        secret = 'sk-' + 'a' * 32
        self.stage('API_KEY=' + secret)
        out = self.scan(code=1)
        self.assertIn('credential-token', out)
        self.assertNotIn(secret, out)

    def test_named_secret_assignment(self):
        value = 'synthetic-' + 'credential-value'
        self.stage('password = "' + value + '"')
        self.assertIn('credential-assignment', self.scan(code=1))

    def test_personal_path_blocks_without_echo(self):
        value = '/' + 'Users/' + 'private-person/Documents/notes'
        self.stage('Evidence: ' + value)
        self.assertNotIn(value, self.scan(code=1))

    def test_email_blocks_without_echo(self):
        value = 'private-person' + '@' + 'mail.test'
        self.stage('Contact: ' + value)
        self.assertNotIn(value, self.scan(code=1))

    def test_synthetic_email_allowed(self):
        self.stage('Contact: sample@example.invalid')
        self.scan()

    def test_transcript_blocks_without_echo(self):
        value = 'a synthetic private conversation detail'
        self.stage('user: ' + value)
        out = self.scan(code=1)
        self.assertIn('chat-transcript', out)
        self.assertNotIn(value, out)

    def test_structured_chat_export(self):
        self.stage(json.dumps({'role': 'user', 'content': 'synthetic'}))
        self.assertIn('chat-export', self.scan(code=1))

    def test_local_deny_list(self):
        private = 'Synthetic Private Client'
        self.stage('Client: ' + private)
        deny = self.repo / 'private-deny.txt'
        deny.write_text(private + '\n')
        out = self.scan('--deny-file', str(deny), code=1)
        self.assertIn('private-deny-list', out)
        self.assertNotIn(private, out)

    def test_staged_version_is_scanned_even_if_worktree_fixed(self):
        self.stage('user: staged private context')
        (self.repo / 'HANDOVER.md').write_text('clean but not staged')
        self.assertIn('chat-transcript', self.scan(code=1))

    def test_unstaged_private_work_does_not_enter_scan(self):
        self.stage('clean staged document')
        (self.repo / 'local.txt').write_text('user: local private context')
        self.scan()

    def test_binary_is_not_cleared(self):
        self.stage(b'opaque\0blob', 'opaque.bin')
        self.assertIn('binary-content-needs-review', self.scan(code=1))

    def test_environment_file_needs_review_even_with_unrecognized_values(self):
        self.stage('SERVICE_VALUE=synthetic', '.env')
        self.assertIn('sensitive-filename', self.scan(code=1))

    def test_symlink_is_not_cleared(self):
        (self.repo / 'linked').symlink_to('elsewhere')
        self.git('add', 'linked')
        self.assertIn('linked-content-needs-review', self.scan(code=1))

    def test_missing_deny_file_fails_closed(self):
        self.stage('clean')
        self.assertIn('Nothing is cleared', self.scan('--deny-file', 'absent', code=2))

    def test_no_staged_files(self):
        self.assertIn('0 text files', self.scan())

    def test_scanner_source_is_not_mistaken_for_a_chat_export(self):
        self.stage(SCRIPT.read_text(), 'scanner.py')
        self.scan()


if __name__ == '__main__':
    unittest.main(verbosity=2)
