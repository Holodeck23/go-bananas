"""Isolated installs; never touches the operator's skill directories."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Installer(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name) / "home space's"
        self.home.mkdir()
        self.env = dict(os.environ, HOME=str(self.home),
                        XDG_STATE_HOME=str(self.home / 'state'))
        self.dests = [self.home / '.claude/skills', self.home / '.agents/skills']

    def run_install(self, *args, ok=True):
        p = subprocess.run(['bash', str(ROOT / 'install.sh'), *args], env=self.env,
                           cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if ok:
            self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        else:
            self.assertNotEqual(p.returncode, 0, p.stdout)
        return p.stdout + p.stderr

    def seed(self):
        for dest in self.dests:
            for skill in ('gb', 'go-bananas'):
                (dest / skill).mkdir(parents=True)
                (dest / skill / 'SKILL.md').write_text('unique original ' + skill)

    def receipt(self):
        return next((self.home / 'state/go-bananas/backups').iterdir())

    def test_preview_does_not_create_destination_or_receipt(self):
        self.run_install('--dry-run', '--target', 'all')
        self.assertEqual(list(self.home.iterdir()), [])

    def test_install_both_generated_variants_and_undo(self):
        self.run_install('--target', 'all')
        for runtime, dest in zip(('claude', 'codex'), self.dests):
            for skill in ('gb', 'go-bananas'):
                self.assertEqual((ROOT / runtime / skill / 'SKILL.md').read_bytes(),
                                 (dest / skill / 'SKILL.md').read_bytes())
        receipt = self.receipt()
        subprocess.check_call(['bash', str(receipt / 'restore.sh')], env=self.env)
        for dest in self.dests:
            self.assertFalse((dest / 'go-bananas').exists())
        self.assertTrue((receipt / 'restored-away/codex/go-bananas/SKILL.md').exists())

    def test_collision_does_not_change_either_runtime(self):
        self.seed()
        self.run_install('--target', 'all', ok=False)
        for dest in self.dests:
            self.assertEqual((dest / 'gb/SKILL.md').read_text(), 'unique original gb')
        self.assertFalse((self.home / 'state').exists())

    def test_replace_retains_originals_and_can_restore(self):
        self.seed()
        self.run_install('--target', 'all', '--replace')
        receipt = self.receipt()
        self.assertEqual((receipt / 'codex/gb/SKILL.md').read_text(), 'unique original gb')
        subprocess.check_call(['bash', str(receipt / 'restore.sh')], env=self.env)
        for dest in self.dests:
            self.assertEqual((dest / 'gb/SKILL.md').read_text(), 'unique original gb')
        p = subprocess.run(['bash', str(receipt / 'restore.sh')], env=self.env,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.assertNotEqual(p.returncode, 0)

    def test_explicit_target_only_installs_that_runtime(self):
        self.run_install('--target', 'codex')
        self.assertFalse(self.dests[0].exists())
        self.assertTrue((self.dests[1] / 'gb/SKILL.md').exists())

    def test_lock_prevents_replacement(self):
        self.seed()
        (self.dests[1] / '.go-bananas-install.lock').mkdir()
        self.run_install('--replace', '--target', 'all', ok=False)
        for dest in self.dests:
            self.assertEqual((dest / 'gb/SKILL.md').read_text(), 'unique original gb')
        self.assertFalse((self.dests[0] / '.go-bananas-install.lock').exists())
        self.assertTrue((self.dests[1] / '.go-bananas-install.lock').exists())

    def test_failed_swap_rolls_back_both_runtimes(self):
        import shutil
        self.seed()
        shim = self.home / 'bin'
        shim.mkdir()
        mv = shutil.which('mv')
        (shim / 'mv').write_text('''#!/usr/bin/env python3
import os, sys
args = sys.argv[1:]
if '.go-bananas-stage.' in args[0] and args[-1].endswith('/.agents/skills/gb'):
    sys.exit(1)
os.execv(os.environ['FIXTURE_MV'], [os.environ['FIXTURE_MV']] + args)
''')
        (shim / 'mv').chmod(0o755)
        self.env.update(PATH=str(shim) + os.pathsep + self.env['PATH'], FIXTURE_MV=mv)
        self.run_install('--replace', '--target', 'all', ok=False)
        for dest in self.dests:
            for skill in ('gb', 'go-bananas'):
                self.assertEqual((dest / skill / 'SKILL.md').read_text(), 'unique original ' + skill)
        self.assertTrue((self.receipt() / 'AUTOMATIC_ROLLBACK').exists())

    def test_invalid_arguments(self):
        for args in [('--target',), ('--target', 'other'), ('--ref',), ('--ref', '--evil')]:
            self.run_install(*args, ok=False)


if __name__ == '__main__':
    unittest.main(verbosity=2)
