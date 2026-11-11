#!/usr/bin/env python3
"""Test scripts/prune-plugins.sh against local git fixtures (no network)."""

from pathlib import Path
import os
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
PRUNE = ROOT / "scripts" / "prune-plugins.sh"
GIT_ENV = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t",
               GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@t",
               GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1")


def git(*args, cwd=None):
    subprocess.run(["git", *args], cwd=cwd, env=GIT_ENV, check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


class PrunePlugins(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="nvim-prune-test-")
        self.addCleanup(temp.cleanup)
        self.tmp = Path(temp.name)
        self.root = self.tmp / "lazy"
        self.root.mkdir()
        self.upstream = self.tmp / "upstream.git"
        work = self.tmp / "seed"
        git("init", "-q", "-b", "main", str(work))
        (work / "README").write_text("x\n")
        git("add", "README", cwd=work)
        git("commit", "-q", "-m", "seed", cwd=work)
        git("clone", "-q", "--bare", str(work), str(self.upstream))

    def plugin(self, name, shallow=False):
        args = ["clone", "-q"]
        if shallow:
            args += ["--depth", "1", "--single-branch", "--no-tags"]
        git(*args, "file://" + str(self.upstream), str(self.root / name))
        return self.root / name

    def prune(self, *declared, candidates=None):
        declared_file = self.tmp / "declared"
        declared_file.write_text("".join(d + "\n" for d in declared))
        args = ["/bin/bash", str(PRUNE), str(self.root), str(declared_file)]
        if candidates is not None:
            cand = self.tmp / "candidates"
            cand.write_text("".join(c + "\n" for c in candidates))
            args.append(str(cand))
        return subprocess.run(args, env=GIT_ENV, capture_output=True, text=True)

    def test_clean_undeclared_clone_is_removed(self):
        self.plugin("kept")
        self.plugin("old-theme")
        result = self.prune("kept")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.root / "kept").is_dir())
        self.assertFalse((self.root / "old-theme").exists())
        self.assertIn("old-theme", result.stdout)

    def test_shallow_and_dead_remote_clean_clones_are_removed(self):
        self.plugin("shallow", shallow=True)
        dead = self.plugin("dead-remote")
        git("remote", "set-url", "origin", "https://example.invalid/gone.git", cwd=dead)
        result = self.prune("x")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.root / "shallow").exists())
        self.assertFalse((self.root / "dead-remote").exists())

    def test_generated_helptags_do_not_count_as_work(self):
        d = self.plugin("tags-only")
        (d / "doc").mkdir()
        (d / "doc" / "tags").write_text("t\n")
        (d / "doc" / "tags-ja").write_text("t\n")
        self.prune("x")
        self.assertFalse(d.exists())

    def test_user_work_is_kept_and_listed(self):
        tracked = self.plugin("tracked-edit")
        (tracked / "README").write_text("edited\n")
        untracked = self.plugin("untracked-file")
        (untracked / "notes.txt").write_text("mine\n")
        unpushed = self.plugin("unpushed")
        (unpushed / "new").write_text("n\n")
        git("add", "new", cwd=unpushed)
        git("commit", "-q", "-m", "local", cwd=unpushed)
        stashed = self.plugin("stashed")
        (stashed / "README").write_text("wip\n")
        git("stash", "-q", cwd=stashed)
        plain = self.root / "not-git"
        plain.mkdir()
        (plain / "file").write_text("f\n")
        result = self.prune("x")
        self.assertEqual(result.returncode, 0, result.stderr)
        for d in (tracked, untracked, unpushed, stashed, plain):
            self.assertTrue(d.is_dir(), d.name)
            self.assertIn(d.name, result.stdout)

    def test_declared_plugins_and_symlinks_are_never_removed(self):
        self.plugin("declared")
        target = self.tmp / "local-plugin"
        target.mkdir()
        (self.root / "linked").symlink_to(target)
        self.prune("declared")
        self.assertTrue((self.root / "declared").is_dir())
        self.assertTrue((self.root / "linked").is_symlink())
        self.assertTrue(target.is_dir())

    def test_symlink_to_clean_clone_is_not_followed(self):
        target = self.tmp / "elsewhere"
        git("clone", "-q", "file://" + str(self.upstream), str(target))
        (self.root / "linked").symlink_to(target)
        self.prune("x")
        self.assertTrue((self.root / "linked").is_symlink())
        self.assertTrue((target / "README").exists())

    def test_candidate_cannot_name_a_path_outside_root(self):
        victim = self.tmp / "victim"
        git("clone", "-q", "file://" + str(self.upstream), str(victim))
        self.prune("x", candidates=["../victim"])
        self.assertTrue((victim / "README").exists())

    def test_plain_dir_inside_an_outer_repo_is_kept(self):
        # The plugin root sits inside another work tree; a plain directory
        # there is not its own repo and must not inherit the outer status.
        outer = self.tmp / "outer"
        git("init", "-q", "-b", "main", str(outer))
        self.root = outer / "bundle"
        (self.root / "plain").mkdir(parents=True)
        (self.root / "plain" / "file").write_text("f\n")
        git("add", ".", cwd=outer)
        git("commit", "-q", "-m", "c", cwd=outer)
        # Fully pushed, so only the own-repo check can protect the plain dir.
        git("init", "-q", "--bare", str(self.tmp / "outer-remote.git"))
        git("remote", "add", "origin", str(self.tmp / "outer-remote.git"), cwd=outer)
        git("push", "-q", "origin", "main", cwd=outer)
        git("fetch", "-q", "origin", cwd=outer)
        self.prune("x")
        self.assertTrue((self.root / "plain" / "file").exists())

    def test_empty_declared_set_removes_nothing(self):
        self.plugin("a")
        result = self.prune()
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((self.root / "a").is_dir())

    def test_blank_declared_list_removes_nothing(self):
        self.plugin("a")
        result = self.prune("", "  ")
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((self.root / "a").is_dir())

    def test_missing_declared_file_removes_nothing(self):
        self.plugin("a")
        result = subprocess.run(["/bin/bash", str(PRUNE), str(self.root), str(self.tmp / "nope")],
                                env=GIT_ENV, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((self.root / "a").is_dir())

    def test_candidate_list_limits_removal(self):
        self.plugin("listed")
        self.plugin("unlisted")
        self.prune("x", candidates=["listed"])
        self.assertFalse((self.root / "listed").exists())
        self.assertTrue((self.root / "unlisted").is_dir())

    def test_empty_cloning_marker_is_removed(self):
        marker = self.root / "animate.nvim.cloning"
        marker.write_text("")
        busy = self.root / "busy.cloning"
        busy.write_text("pid\n")
        self.prune("x")
        self.assertFalse(marker.exists())
        self.assertTrue(busy.exists())

    def test_second_run_is_a_noop(self):
        self.plugin("kept")
        self.plugin("gone")
        self.prune("kept")
        before = sorted(p.name for p in self.root.iterdir())
        result = self.prune("kept")
        self.assertEqual(before, sorted(p.name for p in self.root.iterdir()))
        self.assertNotIn("Removed", result.stdout)

    def test_root_outside_paths_untouched(self):
        outside = self.tmp / "outside.txt"
        outside.write_text("keep\n")
        result = self.prune("x", candidates=["../outside.txt", "/etc"])
        self.assertTrue(outside.exists())
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
