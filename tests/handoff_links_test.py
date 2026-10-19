"""Real Git state transitions with local transport replacing network access only."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'src/scripts/handoff-links.sh'
GIT = shutil.which('git')


class HandoffLinks(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.repo = self.base / "My Proj é's"
        self.repo.mkdir()
        self.remote = self.base / 'origin.git'
        self.env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull,
                        GIT_CONFIG_NOSYSTEM='1', GIT_TERMINAL_PROMPT='0')
        for key in ('CODEX_CLOUD', 'CLAUDE_CODE_REMOTE', 'GIT_DIR', 'GIT_WORK_TREE'):
            self.env.pop(key, None)
        self.git('init', '-q', '--bare', str(self.remote), cwd=self.base)
        self.git('init', '-q', '-b', 'feature/x')
        self.git('config', 'user.name', 'Fixture')
        self.git('config', 'user.email', 'fixture@example.invalid')
        self.git('config', 'core.hooksPath', os.devnull)
        (self.repo / 'HANDOVER.md').write_text('# Task\nResume rules: preserve scope.\n')
        self.git('add', 'HANDOVER.md')
        self.git('commit', '-qm', 'checkpoint')
        self.git('remote', 'add', 'origin', 'https://github.com/acme/demo.git')
        self.push()
        shim = self.base / 'bin'
        shim.mkdir()
        # Preserve every Git operation except the network transport. The remote
        # branch contents are real, and ls-remote still runs against a bare repo.
        (shim / 'git').write_text('''#!/usr/bin/env python3
import os, sys
args = sys.argv[1:]
if 'ls-remote' in args:
    if os.environ.get('FIXTURE_OFFLINE'):
        sys.exit(128)
    i = args.index('ls-remote')
    tail = args[i+1:]
    assert tail[1] == 'origin', tail
    args = ['ls-remote', tail[0], os.environ['FIXTURE_REMOTE']] + tail[2:]
os.execv(os.environ['FIXTURE_GIT'], [os.environ['FIXTURE_GIT']] + args)
''')
        (shim / 'git').chmod(0o755)
        self.env.update(PATH=str(shim) + os.pathsep + self.env['PATH'],
                        FIXTURE_REMOTE=str(self.remote), FIXTURE_GIT=GIT)

    def git(self, *args, cwd=None):
        return subprocess.check_output([GIT, *args], cwd=cwd or self.repo,
                                       env=self.env, stderr=subprocess.PIPE, text=True).strip()

    def push(self):
        self.git('push', '-q', str(self.remote), 'HEAD:refs/heads/feature/x')

    def run_helper(self, *args, extra=None, cwd=None, code=0):
        before = self.git('status', '--porcelain')
        refs = self.git('show-ref')
        result = subprocess.run(['bash', str(SCRIPT), *args], cwd=cwd or self.repo,
                                env=dict(self.env, **(extra or {})), text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.assertEqual(result.returncode, code, result.stderr)
        self.assertEqual(before, self.git('status', '--porcelain'))
        self.assertEqual(refs, self.git('show-ref'))
        return result.stdout + result.stderr

    def unavailable(self, output, reason):
        self.assertNotIn('https://claude.ai/code/new?', output)
        self.assertIn(reason, output)
        self.assertIn('Fallback:', output)

    def test_pushed_without_upstream_is_ready(self):
        out = self.run_helper('--for', 'claude')
        self.assertIn('&repo=acme%2Fdemo&branch=feature%2Fx', out)
        self.assertNotIn('⚠️', out)
        self.assertIn('My%20Proj%20%C3%A9%27s', out)

    def test_codex_prefill_and_terminal_use_intended_folder(self):
        out = self.run_helper('--for', 'codex')
        self.assertIn('codex://threads/new?prompt=Resume', out)
        self.assertIn('&path=%2F', out)
        command = out.split('Terminal (on this computer): `', 1)[1].split('`', 1)[0]
        # Substitute only the actual Codex executable. Verify shell quoting and cwd.
        probe = 'codex() { pwd; printf "%s\\n" "$*"; }; ' + command
        r = subprocess.check_output(['bash', '-c', probe], cwd=self.base, text=True)
        self.assertIn(str(self.repo), r)
        self.assertIn('Resume from HANDOVER.md', r)

    def test_untracked_handover_never_offers_cloud(self):
        self.git('rm', '--cached', 'HANDOVER.md')
        self.git('commit', '-qm', 'untrack')
        self.push()
        self.unavailable(self.run_helper(), 'not committed')

    def test_ignored_handover_never_offers_cloud(self):
        self.git('rm', '--cached', 'HANDOVER.md')
        (self.repo / '.gitignore').write_text('HANDOVER.md\n')
        self.git('add', '.gitignore')
        self.git('commit', '-qm', 'ignore')
        self.push()
        self.unavailable(self.run_helper(), 'not committed')

    def test_modified_handover_never_offers_cloud(self):
        with (self.repo / 'HANDOVER.md').open('a') as f:
            f.write('new unresolved work\n')
        self.unavailable(self.run_helper(), 'uncommitted changes')

    def test_staged_handover_never_offers_cloud(self):
        (self.repo / 'HANDOVER.md').write_text('new checkpoint\n')
        self.git('add', 'HANDOVER.md')
        self.unavailable(self.run_helper(), 'remote copy is stale')

    def test_missing_handover_has_no_local_launch_either(self):
        (self.repo / 'HANDOVER.md').unlink()
        out = self.run_helper('--for', 'codex')
        self.unavailable(out, 'missing or empty')
        self.assertNotIn('codex://', out)

    def test_empty_handover(self):
        (self.repo / 'HANDOVER.md').write_text('')
        self.unavailable(self.run_helper(), 'missing or empty')

    def test_symlink_does_not_promise_cloud_availability(self):
        target = self.base / 'private.md'
        target.write_text('local only')
        (self.repo / 'HANDOVER.md').unlink()
        (self.repo / 'HANDOVER.md').symlink_to(target)
        self.git('add', 'HANDOVER.md')
        self.git('commit', '-qm', 'symlink')
        self.push()
        self.unavailable(self.run_helper(), 'symlink')

    def test_uncommitted_required_file(self):
        (self.repo / 'required.txt').write_text('unfinished')
        self.unavailable(self.run_helper(), 'Uncommitted changes')

    def test_unpushed_commit(self):
        self.git('commit', '--allow-empty', '-qm', 'local only')
        self.unavailable(self.run_helper(), 'live origin branch differs')

    def test_wrong_upstream_does_not_claim_ready(self):
        self.git('update-ref', 'refs/remotes/other/feature/x', 'HEAD')
        self.git('config', 'branch.feature/x.remote', 'other')
        self.git('config', 'branch.feature/x.merge', 'refs/heads/feature/x')
        self.git('commit', '--allow-empty', '-qm', 'different origin')
        self.git('update-ref', 'refs/remotes/other/feature/x', 'HEAD')
        self.unavailable(self.run_helper(), 'live origin branch differs')

    def test_remote_ahead_of_stale_tracking(self):
        local = self.git('rev-parse', 'HEAD')
        self.git('commit', '--allow-empty', '-qm', 'remote advanced')
        self.push()
        self.git('reset', '--hard', local)
        self.unavailable(self.run_helper(), 'live origin branch differs')

    def test_deleted_remote_branch(self):
        self.git('update-ref', '-d', 'refs/heads/feature/x', cwd=self.remote)
        self.unavailable(self.run_helper(), 'Could not verify')

    def test_offline_does_not_retry_or_offer_cloud(self):
        self.unavailable(self.run_helper(extra={'FIXTURE_OFFLINE': '1'}), 'No retry')

    def test_detached_head(self):
        self.git('checkout', '--detach', '-q')
        self.unavailable(self.run_helper(), 'Detached HEAD')

    def test_non_github_origin(self):
        self.git('remote', 'set-url', 'origin', 'https://gitlab.com/acme/demo.git')
        self.unavailable(self.run_helper(), 'No supported GitHub origin')

    def test_github_lookalike_is_not_supported(self):
        self.git('remote', 'set-url', 'origin', 'https://github.example/acme/demo.git')
        self.unavailable(self.run_helper(), 'No supported GitHub origin')

    def test_ssh_github_origin(self):
        self.git('remote', 'set-url', 'origin', 'git@github.com:acme/demo.git')
        self.assertIn('&repo=acme%2Fdemo', self.run_helper())

    def test_no_origin(self):
        self.git('remote', 'remove', 'origin')
        self.unavailable(self.run_helper(), 'No supported GitHub origin')

    def test_cloud_hides_local_paths_and_launches(self):
        for extra in ({'CLAUDE_CODE_REMOTE': 'true'}, {'CODEX_CLOUD': '1'}):
            out = self.run_helper('--for', 'codex', extra=extra)
            self.assertIn('https://claude.ai/', out)
            self.assertNotIn('codex://', out)
            self.assertNotIn('Terminal (on this computer)', out)

    def test_no_git_project_still_supports_local(self):
        plain = self.base / 'plain'
        plain.mkdir()
        (plain / 'HANDOVER.md').write_text('local checkpoint')
        out = self.run_helper('--for', 'codex', cwd=plain)
        self.unavailable(out, 'not a Git repository')
        self.assertIn('codex://', out)

    def test_task_specific_handover(self):
        (self.repo / 'handovers').mkdir()
        self.git('mv', 'HANDOVER.md', 'handovers/task one.md')
        self.git('commit', '-qm', 'task-specific checkpoint')
        self.push()
        out = self.run_helper('--handover', 'handovers/task one.md')
        self.assertIn('handovers%2Ftask%20one.md', out)
        self.assertNotIn('⚠️', out)

    def test_bad_arguments_stop(self):
        for args in [('--for',), ('--handover',), ('--for', 'other'),
                     ('--handover', '../private.md'), ('--unknown',)]:
            self.run_helper(*args, code=2)


if __name__ == '__main__':
    unittest.main(verbosity=2)
