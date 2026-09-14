import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class BootstrapTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='nvim-ci-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / 'repo'
        (self.repo / 'scripts').mkdir(parents=True)
        shutil.copy2(ROOT / 'scripts/ci-unix.sh', self.repo / 'scripts/ci-unix.sh')
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.runner = self.root / 'runner'
        self.runner.mkdir()
        self.env = dict(os.environ, GITHUB_ACTIONS='true', RUNNER_TEMP=str(self.runner),
                        PATH=str(self.bin) + os.pathsep + '/usr/bin:/bin')
        for name in ('BASH_ENV', 'ENV', 'NVIM_APPNAME'):
            self.env.pop(name, None)
        for name in ('git', 'rg', 'ag', 'fzf', 'ctags'):
            self.stub(self.bin / name, 'exit 0')
        self.stub(self.bin / 'python3', 'if [[ ${1:-} == - ]]; then /bin/cat >/dev/null; fi; exit 0')
        self.stub(self.bin / 'nvim', '''
if [[ "$*" == *'Lazy! sync'* ]]; then
  if [[ ${FAULT:-} == setup ]]; then exit 19; fi
  if [[ ${FAULT:-} != marker ]]; then printf passed > "$NVIM_SMOKE_SUCCESS"; fi
fi
exit 0
''')
        self.stub(self.repo / 'install.sh', 'test "${1:-}" = --no-deps; exit 0')
        self.stub(self.repo / 'scripts/smoke.sh', 'if [[ ${FAULT:-} == smoke ]]; then exit 21; fi; printf "fixture smoke passed\\n"')

    def stub(self, path, body):
        path.write_text('#!/bin/bash\nset -euo pipefail\n' + body + '\n')
        path.chmod(0o755)

    def invoke(self, fault=''):
        return subprocess.run(['bash', str(self.repo / 'scripts/ci-unix.sh')],
                              env=dict(self.env, FAULT=fault), cwd=self.repo,
                              text=True, capture_output=True, timeout=15)

    def test_success_reaches_smoke(self):
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('fixture smoke passed', result.stdout)
        self.assertTrue((self.runner / 'nvim-unix-logs/smoke.log').is_file())

    def test_setup_failure_stops_before_smoke(self):
        result = self.invoke('setup')
        self.assertEqual(result.returncode, 19, result.stdout + result.stderr)
        self.assertNotIn('fixture smoke passed', result.stdout)

    def test_missing_marker_stops_before_smoke(self):
        result = self.invoke('marker')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('fixture smoke passed', result.stdout)

    def test_smoke_failure_is_not_masked_by_tee(self):
        result = self.invoke('smoke')
        self.assertEqual(result.returncode, 21, result.stdout + result.stderr)

    def test_refuses_non_ci_host(self):
        self.env.pop('GITHUB_ACTIONS')
        result = self.invoke()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('disposable GitHub runner', result.stderr)
        self.assertEqual(list(self.runner.iterdir()), [])


if __name__ == '__main__':
    unittest.main(verbosity=2)
