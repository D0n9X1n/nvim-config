#!/usr/bin/env python3
"""Test Wiki rendering and safe publication against disposable Git remotes."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
WIKI = ROOT / "scripts" / "wiki.py"
REPO = "D0n9X1n/nvim-config"
SHA = "0123456789abcdef0123456789abcdef01234567"
OTHER_SHA = "89abcdef0123456789abcdef0123456789abcdef"
MARKER = "<!-- nvim-config:managed-home -->"

README = """# Fixture

[![License](https://img.shields.io/badge/license.svg)](LICENSE)

A port of [m-vim](https://example.com/external) documented in
[`CLAUDE.md`](CLAUDE.md#deep-section), with sources under [lua](lua).

![logo](docs/logo.png)

## Setup Guide

Jump to [setup](#setup-guide). Inline `[inline](missing.md)` stays literal.

```bash
[fenced](missing.md)
```
"""


class WikiTestCase(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="nvim-wiki-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        home = self.root / "home"
        home.mkdir()
        # Hermetic Git: no global/system config, identity only from the env.
        self.env = dict(
            os.environ,
            HOME=str(home),
            GIT_CONFIG_GLOBAL=str(self.root / "absent-global"),
            GIT_CONFIG_SYSTEM=str(self.root / "absent-system"),
            GIT_TERMINAL_PROMPT="0",
            GIT_AUTHOR_NAME="Fixture",
            GIT_AUTHOR_EMAIL="fixture@example.invalid",
            GIT_COMMITTER_NAME="Fixture",
            GIT_COMMITTER_EMAIL="fixture@example.invalid",
        )

    def git(self, *args, cwd, check=True):
        result = subprocess.run(["git", *args], cwd=str(cwd), env=self.env,
                                capture_output=True, text=True, timeout=60)
        if check:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def cli(self, *args, expect=0, cwd=None):
        result = subprocess.run([sys.executable, str(WIKI), *args], env=self.env,
                                cwd=None if cwd is None else str(cwd),
                                capture_output=True, text=True, timeout=60)
        self.assertEqual(result.returncode, expect, result.stdout + result.stderr)
        return result

    def assert_reason(self, result, reason):
        """Assert the specific documented failure, never just "it failed"."""
        self.assertIn(reason, result.stderr)

    def source(self, readme=README, name="source"):
        repo = self.root / name
        repo.mkdir()
        self.git("init", "-q", "-b", "main", cwd=repo)
        (repo / "README.md").write_text(readme, encoding="utf-8")
        (repo / "LICENSE").write_text("MIT\n", encoding="utf-8")
        (repo / "CLAUDE.md").write_text("# Guide\n\n## Deep Section\n",
                                        encoding="utf-8")
        (repo / "docs").mkdir()
        (repo / "docs" / "logo.png").write_bytes(b"\x89PNG\r\n")
        (repo / "lua").mkdir()
        (repo / "lua" / "init.lua").write_text("-- fixture\n", encoding="utf-8")
        self.git("add", "-A", cwd=repo)
        self.git("commit", "-qm", "fixture", cwd=repo)
        return repo

    def rejected_source(self, readme, reason, extra=None, name="source"):
        repo = self.source(readme, name=name)
        if extra:
            extra(repo)
            self.git("add", "-A", cwd=repo)
            self.git("commit", "-qm", "extra", cwd=repo)
        result = self.cli("check", "--root", str(repo), "--repo", REPO,
                          "--sha", SHA, expect=1)
        self.assert_reason(result, reason)
        return result

    # ---------------------------------------------------------------- render

    def test_renders_managed_home_and_rewrites_repository_links(self):
        repo = self.source()
        out = self.root / "Home.md"
        self.cli("build", "--root", str(repo), "--repo", REPO, "--sha", SHA,
                 "--output", str(out))
        text = out.read_text(encoding="utf-8")
        self.assertTrue(text.startswith(MARKER + "\n"), text[:120])
        self.assertIn("<!-- source-sha: " + SHA + " -->", text)
        blob = "https://github.com/" + REPO + "/blob/" + SHA
        self.assertIn("](" + blob + "/LICENSE)", text)
        self.assertIn("](" + blob + "/CLAUDE.md#deep-section)", text)
        self.assertIn("](https://github.com/" + REPO + "/tree/" + SHA + "/lua)",
                      text)
        self.assertIn(
            "](https://raw.githubusercontent.com/" + REPO + "/" + SHA
            + "/docs/logo.png)", text)
        # External destinations, badge images, anchors and code stay intact.
        self.assertIn("[m-vim](https://example.com/external)", text)
        self.assertIn("![License](https://img.shields.io/badge/license.svg)", text)
        self.assertIn("[setup](#setup-guide)", text)
        self.assertIn("`[inline](missing.md)`", text)
        self.assertIn("[fenced](missing.md)", text)

    def test_render_is_deterministic(self):
        repo = self.source()
        first, second = self.root / "a.md", self.root / "b.md"
        for out in (first, second):
            self.cli("build", "--root", str(repo), "--repo", REPO, "--sha", SHA,
                     "--output", str(out))
        self.assertEqual(first.read_bytes(), second.read_bytes())

    def test_current_readme_renders_and_validates(self):
        out = self.root / "Home.md"
        self.cli("check", "--root", str(ROOT), "--repo", REPO, "--sha", SHA,
                 "--output", str(out))
        text = out.read_text(encoding="utf-8")
        blob = "https://github.com/" + REPO + "/blob/" + SHA
        self.assertIn("](" + blob + "/LICENSE)", text)
        self.assertIn("](" + blob + "/CLAUDE.md)", text)
        self.assertIn("https://img.shields.io/", text)

    def test_check_without_arguments_infers_repository_from_cwd(self):
        """CI runs a bare `wiki.py check` from the checkout root."""
        repo = self.source()
        self.git("remote", "add", "origin",
                 "git@github.com:" + REPO + ".git", cwd=repo)
        result = self.cli("check", cwd=repo)
        head = self.git("rev-parse", "HEAD", cwd=repo).stdout.strip()
        self.assertIn(REPO, result.stdout)
        self.assertIn(head, result.stdout)

    def test_check_without_arguments_reports_broken_links(self):
        repo = self.source("# T\n\n[gone](docs/missing.md)\n")
        self.git("remote", "add", "origin",
                 "https://github.com/" + REPO + ".git", cwd=repo)
        self.assert_reason(self.cli("check", cwd=repo, expect=1), "missing-target")

    # -------------------------------------------------------- source refusal

    def test_missing_link_target_is_rejected(self):
        self.rejected_source("# T\n\n[gone](docs/missing.md)\n", "missing-target")

    def test_deleted_tracked_target_is_rejected(self):
        repo = self.source('# T\n\n[license](LICENSE)\n')
        (repo / 'LICENSE').unlink()
        result = self.cli('check', '--root', str(repo), '--repo', REPO, '--sha', SHA, expect=1)
        self.assert_reason(result, 'missing-target')

    def test_symlinked_target_parent_is_rejected(self):
        repo = self.source('# T\n\n[logo](docs/logo.png)\n')
        external = self.root / 'external'
        (repo / 'docs').rename(external)
        (repo / 'docs').symlink_to(external, target_is_directory=True)
        result = self.cli('check', '--root', str(repo), '--repo', REPO, '--sha', SHA, expect=1)
        self.assert_reason(result, 'symlink-target')

    def test_missing_anchor_is_rejected(self):
        self.rejected_source("# T\n\n[bad](CLAUDE.md#no-such-heading)\n",
                             "missing-anchor", name="cross-file")
        self.rejected_source("# T\n\n[bad](#no-such-heading)\n", "missing-anchor",
                             name="own-anchor")

    def test_path_traversal_is_rejected(self):
        self.rejected_source("# T\n\n[out](../secrets.txt)\n",
                             "escapes-repository")

    def test_absolute_path_is_rejected(self):
        self.rejected_source("# T\n\n[abs](/etc/passwd)\n", "absolute-path")

    def test_symlink_target_is_rejected(self):
        def add_symlink(repo):
            (repo / "link.md").symlink_to("CLAUDE.md")
        self.rejected_source("# T\n\n[link](link.md)\n", "symlink-target",
                             extra=add_symlink)

    def test_symlinked_readme_is_rejected(self):
        repo = self.source()
        (repo / "README.md").unlink()
        (repo / "README.md").symlink_to("CLAUDE.md")
        self.git("add", "-A", cwd=repo)
        self.git("commit", "-qm", "symlink readme", cwd=repo)
        result = self.cli("check", "--root", str(repo), "--repo", REPO,
                          "--sha", SHA, expect=1)
        self.assert_reason(result, "symlink-source")

    def test_empty_source_is_rejected(self):
        self.rejected_source("   \n\n", "empty-source")

    def test_untracked_target_is_rejected(self):
        repo = self.source("# T\n\n[scratch](scratch.md)\n")
        (repo / "scratch.md").write_text("untracked\n", encoding="utf-8")
        result = self.cli("check", "--root", str(repo), "--repo", REPO,
                          "--sha", SHA, expect=1)
        self.assert_reason(result, "missing-target")

    def test_reference_style_links_are_rejected_as_unsupported(self):
        self.rejected_source("# T\n\n[text][ref]\n\n[ref]: https://example.com\n",
                             "unsupported-link-syntax")

    def test_invalid_repository_and_sha_are_rejected(self):
        repo = self.source()
        bad_repo = self.cli("check", "--root", str(repo), "--repo",
                            "https://github.com/a/b", "--sha", SHA, expect=1)
        self.assert_reason(bad_repo, "invalid-repository")
        bad_sha = self.cli("check", "--root", str(repo), "--repo", REPO,
                           "--sha", "main", expect=1)
        self.assert_reason(bad_sha, "invalid-sha")

    # ------------------------------------------------------------ wiki sync

    def remote(self, seeded=True):
        bare = self.root / "wiki.git"
        self.git("init", "-q", "--bare", "-b", "master", str(bare), cwd=self.root)
        if seeded:
            seed = self.root / "seed"
            self.git("clone", "-q", str(bare), str(seed), cwd=self.root)
            (seed / "Sidebar.md").write_text("unrelated\n", encoding="utf-8")
            (seed / "Notes.md").write_text("hand written\n", encoding="utf-8")
            self.git("add", "-A", cwd=seed)
            self.git("commit", "-qm", "seed wiki", cwd=seed)
            self.git("push", "-q", "origin", "HEAD:refs/heads/master", cwd=seed)
        return bare

    def clone(self, bare, name="wiki"):
        path = self.root / name
        self.git("clone", "-q", str(bare), str(path), cwd=self.root)
        return path

    def sync(self, repo, wiki, sha=SHA, expect=0, *extra):
        return self.cli("sync", "--root", str(repo), "--repo", REPO,
                        "--sha", sha, "--wiki", str(wiki), *extra, expect=expect)

    def commits(self, path, ref="HEAD"):
        return self.git("rev-list", "--count", ref, cwd=path).stdout.strip()

    def test_publish_update_and_no_op_preserve_other_pages(self):
        repo = self.source()
        wiki = self.clone(self.remote())
        before = self.commits(wiki)

        first = self.sync(repo, wiki)
        self.assertIn("committed", first.stdout)
        home = wiki / "Home.md"
        self.assertTrue(home.read_text(encoding="utf-8").startswith(MARKER))
        self.assertEqual(int(self.commits(wiki)), int(before) + 1)

        # Re-running with an unchanged source writes no new commit.
        repeat = self.sync(repo, wiki)
        self.assertIn("unchanged", repeat.stdout)
        self.assertEqual(int(self.commits(wiki)), int(before) + 1)

        # An updated README produces exactly one further commit.
        (repo / "README.md").write_text(README + "\nNew line.\n", encoding="utf-8")
        self.git("add", "-A", cwd=repo)
        self.git("commit", "-qm", "update readme", cwd=repo)
        update = self.sync(repo, wiki)
        self.assertIn("committed", update.stdout)
        self.assertIn("New line.", home.read_text(encoding="utf-8"))
        self.assertEqual(int(self.commits(wiki)), int(before) + 2)

        # Unrelated pages are untouched throughout.
        self.assertEqual((wiki / "Sidebar.md").read_text(encoding="utf-8"),
                         "unrelated\n")
        self.assertEqual((wiki / "Notes.md").read_text(encoding="utf-8"),
                         "hand written\n")
        status = self.git("status", "--porcelain", cwd=wiki).stdout
        self.assertEqual(status.strip(), "")

    def test_unowned_home_is_never_adopted(self):
        repo = self.source()
        bare = self.remote()
        seed = self.clone(bare, "seed2")
        (seed / "Home.md").write_text("# Hand written home\n", encoding="utf-8")
        self.git("add", "-A", cwd=seed)
        self.git("commit", "-qm", "manual home", cwd=seed)
        self.git("push", "-q", "origin", "HEAD:refs/heads/master", cwd=seed)
        wiki = self.clone(bare)
        result = self.sync(repo, wiki, expect=1)
        self.assert_reason(result, "unowned-home")
        self.assertEqual((wiki / "Home.md").read_text(encoding="utf-8"),
                         "# Hand written home\n")

    def test_dirty_wiki_worktree_is_rejected(self):
        repo = self.source()
        wiki = self.clone(self.remote())
        (wiki / "Sidebar.md").write_text("locally edited\n", encoding="utf-8")
        result = self.sync(repo, wiki, expect=1)
        self.assert_reason(result, "dirty-worktree")

    def test_untracked_home_collision_is_rejected(self):
        repo = self.source()
        wiki = self.clone(self.remote())
        (wiki / "Home.md").write_text("scratch\n", encoding="utf-8")
        result = self.sync(repo, wiki, expect=1)
        self.assert_reason(result, "untracked-home-collision")

    def test_symlinked_home_is_rejected(self):
        repo = self.source()
        bare = self.remote()
        seed = self.clone(bare, "seed3")
        (seed / "Home.md").symlink_to("Notes.md")
        self.git("add", "-A", cwd=seed)
        self.git("commit", "-qm", "symlink home", cwd=seed)
        self.git("push", "-q", "origin", "HEAD:refs/heads/master", cwd=seed)
        wiki = self.clone(bare)
        result = self.sync(repo, wiki, expect=1)
        self.assert_reason(result, "home-symlink")
        self.assertTrue((wiki / "Home.md").is_symlink())

    def test_uninitialized_wiki_is_rejected(self):
        repo = self.source()
        wiki = self.clone(self.remote(seeded=False))
        result = self.sync(repo, wiki, expect=1)
        self.assert_reason(result, "unknown-remote-branch")

    def test_non_repository_destination_is_rejected(self):
        repo = self.source()
        plain = self.root / "plain"
        plain.mkdir()
        result = self.sync(repo, plain, expect=1)
        self.assert_reason(result, "not-a-worktree")

    # ------------------------------------------------------------ push rules

    def test_push_publishes_and_concurrent_update_is_rejected(self):
        repo = self.source()
        bare = self.remote()
        wiki = self.clone(bare)
        pushed = self.sync(repo, wiki, SHA, 0, "--push")
        self.assertIn("pushed", pushed.stdout)
        remote_home = self.git("show", "master:Home.md", cwd=bare).stdout
        self.assertTrue(remote_home.startswith(MARKER))

        # Someone else advances the wiki while our clone is stale.
        other = self.clone(bare, "other")
        (other / "Notes.md").write_text("concurrent edit\n", encoding="utf-8")
        self.git("add", "-A", cwd=other)
        self.git("commit", "-qm", "concurrent", cwd=other)
        self.git("push", "-q", "origin", "HEAD:refs/heads/master", cwd=other)
        remote_tip = self.git("rev-parse", "master", cwd=bare).stdout.strip()

        (repo / "README.md").write_text(README + "\nLater.\n", encoding="utf-8")
        self.git("add", "-A", cwd=repo)
        self.git("commit", "-qm", "later", cwd=repo)
        rejected = self.sync(repo, wiki, SHA, 1, "--push")
        self.assert_reason(rejected, "push-rejected")
        # The concurrent commit survives: nothing was force-pushed over it.
        self.assertEqual(self.git("rev-parse", "master", cwd=bare).stdout.strip(),
                         remote_tip)
        self.assertEqual(self.git("show", "master:Notes.md", cwd=bare).stdout,
                         "concurrent edit\n")

    def test_unexpected_base_is_rejected_before_pushing(self):
        repo = self.source()
        wiki = self.clone(self.remote())
        result = self.sync(repo, wiki, SHA, 1, "--push", "--expect-base",
                           OTHER_SHA)
        self.assert_reason(result, "unexpected-base")

    def test_tool_never_force_pushes(self):
        source = WIKI.read_text(encoding="utf-8")
        for forbidden in ("--force", "-f ", "+refs/", "push --delete"):
            self.assertNotIn(forbidden, source)

    def test_sync_never_writes_git_configuration(self):
        source = WIKI.read_text(encoding="utf-8")
        self.assertNotIn('"config"', source)
        self.assertNotIn("git config", source)


if __name__ == "__main__":
    unittest.main()
