#!/usr/bin/env python3
"""Run install.sh's real lazy query (real nvim, no network) on fixture specs."""

from pathlib import Path
import os
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
NVIM = shutil.which("nvim")
LAZY = Path(os.environ.get("NVIM_LAZY_SOURCE",
                           Path.home() / ".local/share/nvim/lazy/lazy.nvim"))


def query_command():
    """The exact headless query line install.sh runs."""
    text = (ROOT / "install.sh").read_text()
    match = re.search(r'^\s*(nvim --headless "\+lua local ok, err = pcall.*)$', text, re.M)
    assert match, "install.sh has no plugin query"
    return match.group(1).rsplit(" || true", 1)[0]


@unittest.skipUnless(NVIM and LAZY.is_dir(), "needs nvim and an installed lazy.nvim")
class PluginQuery(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="nvim-query-test-")
        self.addCleanup(temp.cleanup)
        self.tmp = Path(temp.name)
        self.config = self.tmp / "config/nvim"
        (self.config / "lua/config").mkdir(parents=True)
        self.data = self.tmp / "data/nvim/lazy"
        self.data.mkdir(parents=True)
        (self.data / "lazy.nvim").symlink_to(LAZY)
        for name in ("plain", "custom-dir", "old"):
            (self.data / name).mkdir()

    def run_query(self, spec, private=None):
        (self.config / "init.lua").write_text(f"""
vim.opt.rtp:prepend(vim.fn.stdpath('data') .. '/lazy/lazy.nvim')
local spec = {spec}
local ok, extra = pcall(require, 'config.private')
if ok and type(extra) == 'table' then vim.list_extend(spec, extra) end
require('lazy').setup(spec, {{ install = {{ missing = false }}, checker = {{ enabled = false }},
  change_detection = {{ enabled = false }}, rocks = {{ enabled = false }}, pkg = {{ enabled = false }} }})
""")
        if private is not None:
            (self.config / "lua/config/private.lua").write_text(private)
        out = self.tmp / "out"
        out.mkdir(exist_ok=True)
        env = dict(os.environ, XDG_CONFIG_HOME=str(self.tmp / "config"),
                   XDG_DATA_HOME=str(self.tmp / "data"), XDG_STATE_HOME=str(self.tmp / "state"),
                   XDG_CACHE_HOME=str(self.tmp / "cache"),
                   NVIM_PRUNE_DECLARED=str(out / "declared"),
                   NVIM_PRUNE_CANDIDATES=str(out / "candidates"),
                   NVIM_PRUNE_ROOT=str(out / "root"))
        result = subprocess.run(["/bin/bash", "-c", query_command()], env=env,
                                capture_output=True, text=True, timeout=60)
        read = lambda n: (out / n).read_text().split() if (out / n).exists() else None
        return result, read("declared"), read("candidates")

    def test_renamed_plugin_protects_its_directory(self):
        _, declared, candidates = self.run_query(
            "{ { 'owner/plain' }, { 'owner/whatever', name = 'renamed', dir = vim.fn.stdpath('data') .. '/lazy/custom-dir' } }")
        self.assertIn("custom-dir", declared)
        self.assertIn("plain", declared)
        self.assertIn("old", candidates)
        # lazy may list the renamed directory as a candidate; the declared list
        # still names it, and prune-plugins.sh never removes a declared name.

    def test_private_plugins_are_declared(self):
        _, declared, candidates = self.run_query("{ { 'owner/plain' } }",
                                                 private="return { { 'owner/old' } }")
        self.assertIn("old", declared)
        self.assertNotIn("old", candidates or [])

    def test_broken_private_writes_no_list(self):
        result, declared, _ = self.run_query("{ { 'owner/plain' } }",
                                             private="error('boom')")
        self.assertIsNone(declared, result.stderr)
        self.assertIn("private.lua failed", result.stderr)

    def test_spec_error_writes_no_list(self):
        result, declared, _ = self.run_query("{ { 'owner/plain' }, { 42 } }")
        # Either no list or an empty one: prune-plugins.sh removes nothing for both.
        self.assertFalse(declared, result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
