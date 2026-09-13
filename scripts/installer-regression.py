#!/usr/bin/env python3
"""Exercise the real installer exclusively in disposable, tracked-file fixtures."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
PRIVATE = ("private.lua", "private_config.lua")


def tree(path):
    """Record contents and link identity without following fixture symlinks."""
    if path.is_symlink():
        return ("link", os.readlink(path))
    if path.is_dir():
        return {p.name: tree(p) for p in sorted(path.iterdir())}
    if path.exists():
        return path.read_bytes()
    return None


class InstallerRegression(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="nvim-installer-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.xdg = self.root / "xdg config"
        self.config = self.xdg / "nvim"
        self.checkout = self.root / "fixture checkout"
        self.checkout.mkdir()
        # Read only tracked public files, never a developer's private extensions.
        tracked = subprocess.check_output(
            ["git", "-C", str(ROOT), "ls-files", "-z"]
        ).decode().split("\0")
        for name in filter(None, tracked):
            if Path(name).name in PRIVATE:
                continue
            source = ROOT / name
            if source.is_file():
                target = self.checkout / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        # Deliberately exclude the host PATH: neither real nvim nor brew can run.
        for command in ("basename", "dirname", "head", "awk", "sed", "date",
                        "cp", "mkdir", "rm", "ln", "readlink", "mktemp", "cat"):
            location = shutil.which(command)
            self.assertIsNotNone(location, command)
            (self.bin / command).symlink_to(location)
        self.stub("brew", 'printf invoked > "$HOME/brew-invoked"; exit 99')
        self.stub("nvim", "printf 'NVIM v0.12.0\\nBuild type: Release\\n'")
        self.env = dict(os.environ, HOME=str(self.home),
                        XDG_CONFIG_HOME=str(self.xdg), PATH=str(self.bin))
        self.env.pop("BASH_ENV", None)
        self.env.pop("ENV", None)

    def stub(self, command, body):
        path = self.bin / command
        path.write_text("#!/bin/bash\n" + body + "\n")
        path.chmod(0o755)

    def install(self, success=True, no_deps=True):
        args = ["/bin/bash", str(self.checkout / "install.sh")]
        if no_deps:
            args.append("--no-deps")
        result = subprocess.run(args, env=self.env, cwd=self.root,
                                capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode == 0, success,
                         result.stdout + result.stderr)
        self.assertFalse((self.home / "brew-invoked").exists(),
                         "Installer invoked brew despite test isolation")
        return result

    def local_config(self, root=None):
        root = self.config if root is None else root
        (root / "lua/config").mkdir(parents=True)
        for name in PRIVATE:
            (root / "lua/config" / name).write_text("local " + name + "\n")
        (root / "init.lua").write_text("original init\n")
        (root / "keep.txt").write_text("unmanaged\n")
        return root

    def assert_private(self):
        for name in PRIVATE:
            self.assertEqual((self.config / "lua/config" / name).read_text(),
                             "local " + name + "\n")

    def assert_runtime(self):
        expected = [Path("init.lua"), Path("UltiSnips"), Path("lua/plugins"),
                    Path("lua/config/plugins")]
        expected += [p.relative_to(self.checkout) for p in
                     (self.checkout / "lua/config").glob("*.lua")
                     if p.name not in PRIVATE]
        for name in expected:
            target = self.config / name
            self.assertTrue(target.is_symlink(), str(name))
            self.assertEqual(target.resolve(), (self.checkout / name).resolve())
        for name in ("README.md", "README_CN.md", "LICENSE", "scripts", "docs",
                     "install.sh", "CLAUDE.md", ".git"):
            self.assertFalse((self.config / name).exists(), name)
        for name in PRIVATE:
            target = self.config / "lua/config" / name
            self.assertFalse(target.is_symlink() and
                             target.resolve() == (self.checkout / "lua/config" / name))

    def backups(self):
        return sorted(p / "config" for p in self.config.parent.glob("nvim.backup.*"))

    def test_clean_install_and_rerun_only_runtime(self):
        for name in PRIVATE:
            (self.checkout / "lua/config" / name).write_text("source personal data")
        self.install()
        self.assert_runtime()
        for name in PRIVATE:
            p = self.config / "lua/config" / name
            self.assertTrue(not p.exists() or "source personal data" not in p.read_text())
        before = tree(self.config)
        backups = self.backups()
        self.install()
        self.assertEqual(tree(self.config), before)
        self.assertEqual(self.backups(), backups)
        self.assert_runtime()

    def test_default_xdg_location(self):
        self.env.pop("XDG_CONFIG_HOME")
        self.config = self.home / ".config/nvim"
        self.install()
        self.assert_runtime()

    def test_existing_files_directories_and_independent_backup(self):
        self.local_config()
        (self.config / "UltiSnips").mkdir()
        (self.config / "UltiSnips/old.snippets").write_text("old snippet")
        (self.config / "lua/plugins").write_text("old regular file")
        before = tree(self.config)
        self.install()
        self.assert_private()
        self.assert_runtime()
        backup, = self.backups()
        self.assertEqual(tree(backup), before)
        (self.config / "lua/config/private.lua").write_text("changed later")
        (self.checkout / "init.lua").write_text("checkout changed later")
        self.assertEqual(tree(backup), before)
        restored = self.root / "restored"
        shutil.copytree(backup, restored, symlinks=True)
        self.assertEqual(tree(restored), before)

    def test_top_level_regular_file(self):
        self.xdg.mkdir()
        self.config.write_text("old config file")
        self.install()
        self.assert_runtime()
        backup, = self.backups()
        self.assertEqual(backup.read_text(), "old config file")

    def test_top_level_symlink_leaves_target_untouched(self):
        old = self.local_config(self.root / "old config")
        before = tree(old)
        self.xdg.mkdir()
        self.config.symlink_to(old, target_is_directory=True)
        self.install()
        self.assertFalse(self.config.is_symlink())
        self.assertEqual(tree(old), before)
        self.assert_private()
        self.assert_runtime()
        backup, = self.backups()
        self.assertFalse(backup.is_symlink())
        self.assertEqual(tree(backup), before)
        (old / "init.lua").write_text("old target changed")
        self.assertEqual(tree(backup), before)

    def test_intermediate_symlinks_preserve_private_and_targets(self):
        for intermediate in ("lua", "lua/config"):
            with self.subTest(intermediate=intermediate):
                if self.config.is_symlink():
                    self.config.unlink()
                elif self.config.exists():
                    shutil.rmtree(self.config)
                external = self.local_config(self.root / intermediate.replace("/", "-"))
                source = external / intermediate
                target = self.config / intermediate
                target.parent.mkdir(parents=True, exist_ok=True)
                target.symlink_to(source, target_is_directory=True)
                before = tree(external)
                self.install()
                self.assertFalse(target.is_symlink())
                self.assertEqual(tree(external), before)
                self.assert_private()
                self.assert_runtime()

    def test_leaf_symlinks_and_dangling_private_preserved(self):
        self.local_config()
        original = self.root / "old-init.lua"
        original.write_text("external original")
        (self.config / "init.lua").unlink()
        (self.config / "init.lua").symlink_to(original)
        (self.config / "UltiSnips").symlink_to(self.root / "missing-snippets")
        private = self.config / "lua/config/private_config.lua"
        private.unlink()
        private.symlink_to(self.root / "missing-private")
        self.install()
        self.assert_runtime()
        self.assertEqual(original.read_text(), "external original")
        self.assertTrue(private.is_symlink())
        self.assertEqual(os.readlink(private), str(self.root / "missing-private"))
        self.assertFalse((self.root / "missing-private").exists())
        backup, = self.backups()
        self.assertFalse((backup / "init.lua").is_symlink())
        original.write_text("changed later")
        self.assertEqual((backup / "init.lua").read_text(), "external original")

    def test_dangling_top_and_intermediate_links(self):
        for name in ("", "lua", "lua/config"):
            with self.subTest(name=name):
                if self.config.is_symlink():
                    self.config.unlink()
                elif self.config.exists():
                    shutil.rmtree(self.config)
                target = self.config / name if name else self.config
                target.parent.mkdir(parents=True, exist_ok=True)
                missing = self.root / ("missing-" + name.replace("/", "-"))
                target.symlink_to(missing)
                self.install()
                self.assert_runtime()
                self.assertFalse(missing.exists())

    def test_self_install_is_noop(self):
        self.xdg.mkdir()
        shutil.move(str(self.checkout), str(self.config))
        self.checkout = self.config
        for name in PRIVATE:
            (self.checkout / "lua/config" / name).write_text("local " + name + "\n")
        before = tree(self.checkout)
        self.install()
        self.assertEqual(tree(self.checkout), before)
        self.assertEqual(self.backups(), [])
        self.assert_private()

    def test_version_gate_has_no_side_effects(self):
        for version in (None, "0.11.9", "0.9.5", "garbage"):
            with self.subTest(version=version):
                (self.bin / "nvim").unlink(missing_ok=True)
                if version is not None:
                    self.stub("nvim", "printf 'NVIM v" + version + "\\n'")
                before = tree(self.home)
                result = self.install(success=False)
                self.assertIn("0.12", result.stdout + result.stderr)
                self.assertEqual(tree(self.home), before)
                self.assertFalse(self.xdg.exists())

    def test_version_gate_preserves_existing_configuration(self):
        self.local_config()
        before = tree(self.xdg)
        self.stub("nvim", "printf 'NVIM v0.11.9\\n'")
        self.install(success=False)
        self.assertEqual(tree(self.xdg), before)

    def test_regular_intermediate_containers_are_backed_up(self):
        for name in ("lua", "lua/config"):
            with self.subTest(name=name):
                if self.config.exists():
                    shutil.rmtree(self.config)
                target = self.config / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text("old intermediate file")
                backups = set(self.backups())
                self.install()
                self.assert_runtime()
                backup, = set(self.backups()) - backups
                self.assertEqual((backup / name).read_text(), "old intermediate file")

    def test_private_leaf_links_are_not_replaced_or_written(self):
        self.local_config()
        for name in PRIVATE:
            external = self.root / name
            external.write_text("local " + name + "\n")
            private = self.config / "lua/config" / name
            private.unlink()
            private.symlink_to(external)
        self.install()
        self.assert_private()
        for name in PRIVATE:
            private = self.config / "lua/config" / name
            self.assertTrue(private.is_symlink())
            self.assertEqual(private.resolve(), (self.root / name).resolve())
        self.install()
        self.assert_private()

    def test_backup_cycle_failure_does_not_modify_configuration(self):
        self.local_config()
        (self.config / "loop").symlink_to(self.config, target_is_directory=True)
        before = tree(self.config)
        self.install(success=False)
        self.assertEqual(tree(self.config), before)

    def test_future_neovim_version(self):
        self.stub("nvim", "printf 'NVIM v1.0.0\\n'")
        self.install()
        self.assert_runtime()

    def test_missing_brew_only_fails_when_dependencies_needed(self):
        (self.bin / "brew").unlink()
        result = self.install(success=False, no_deps=False)
        self.assertIn("brew", (result.stdout + result.stderr).lower())
        self.assertIn("--no-deps", result.stdout + result.stderr)
        for command in ("rg", "fzf", "ag", "ctags", "python3", "clang++"):
            self.stub(command, "exit 0")
        self.install(no_deps=False)
        self.assert_runtime()


if __name__ == "__main__":
    unittest.main(verbosity=2)
