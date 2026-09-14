#!/usr/bin/env python3
"""Exercise release gates with local Git fixtures and an injected API."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))

import release  # noqa: E402


REPO = "D0n9X1n/nvim-config"
CI_JOBS = ("Unix CI", "Ubuntu x86-64", "macOS ARM64", "macOS Intel",
           "Automation contracts")
WINDOWS_JOBS = ("Neovim 0.12 / powershell", "Neovim 0.12 / pwsh")


def git(root, *args, check=True):
    """Run Git with a fixture identity; never touch user or system config."""
    env = dict(
        os.environ,
        GIT_CONFIG_GLOBAL=os.devnull,
        GIT_CONFIG_SYSTEM=os.devnull,
        GIT_CONFIG_NOSYSTEM="1",
        GIT_AUTHOR_NAME="Fixture",
        GIT_AUTHOR_EMAIL="fixture@example.invalid",
        GIT_COMMITTER_NAME="Fixture",
        GIT_COMMITTER_EMAIL="fixture@example.invalid",
        GIT_AUTHOR_DATE="2026-01-01T00:00:00+00:00",
        GIT_COMMITTER_DATE="2026-01-01T00:00:00+00:00",
    )
    result = subprocess.run(
        ["git", "-C", str(root), *args],
        env=env, check=check, capture_output=True, text=True,
    )
    return result.stdout.strip()


class FakeApi:
    """Deterministic stand-in for the GitHub REST API, with paging."""

    def __init__(self, page_size=2):
        self.page_size = page_size
        self.releases = []
        self.runs = {}
        self.jobs = {}
        self.refs = {}
        self.notes = {"name": "v1.3.0", "body": ""}
        self.failures = {}
        self.requests = []
        self.created = []
        self.pages = []

    # -- helpers used by tests -------------------------------------------------
    def add_release(self, tag, *, draft=False, prerelease=False, body="", release_id=None):
        self.releases.append({
            "id": release_id if release_id is not None else len(self.releases) + 1,
            "tag_name": tag, "draft": draft, "prerelease": prerelease,
            "body": body, "name": tag,
            "html_url": "https://github.com/%s/releases/tag/%s" % (REPO, tag),
        })

    def add_run(self, workflow, run_id, sha, jobs, *, event="push", branch="main",
                status="completed", conclusion="success", repository=REPO):
        self.runs.setdefault(workflow, []).append({
            "id": run_id, "head_sha": sha, "event": event, "head_branch": branch,
            "status": status, "conclusion": conclusion,
            "run_number": run_id, "run_attempt": 1,
            "repository": {"full_name": repository},
            "html_url": "https://github.com/%s/actions/runs/%d" % (REPO, run_id),
        })
        self.jobs[run_id] = [
            {"name": name, "status": job_status, "conclusion": job_conclusion}
            for name, job_status, job_conclusion in jobs
        ]

    def ok_jobs(self, names):
        return [(name, "completed", "success") for name in names]

    def add_tag_ref(self, tag, sha):
        self.refs[tag] = {"ref": "refs/tags/%s" % tag,
                          "object": {"sha": sha, "type": "commit"}}

    # -- transport -------------------------------------------------------------
    def __call__(self, method, path, params=None, body=None):
        params = dict(params or {})
        self.requests.append((method, path, params, body))
        for marker, status in self.failures.items():
            if marker in path:
                return status, {"message": "injected failure"}
        if method == "GET" and path == "/repos/%s/releases" % REPO:
            return 200, self._page(self.releases, params)
        if method == "GET" and path.startswith("/repos/%s/actions/workflows/" % REPO):
            workflow = path.split("/workflows/")[1].split("/runs")[0]
            runs = list(self.runs.get(workflow, []))
            for key, field in (("head_sha", "head_sha"), ("event", "event"),
                               ("branch", "head_branch"), ("status", "status")):
                if key in params:
                    wanted = params[key]
                    if key == "status" and wanted == "success":
                        runs = [r for r in runs if r["conclusion"] == "success"]
                    else:
                        runs = [r for r in runs if r[field] == wanted]
            page = self._page(runs, params)
            return 200, {"total_count": len(runs), "workflow_runs": page}
        if method == "GET" and path.endswith("/jobs"):
            run_id = int(path.split("/actions/runs/")[1].split("/jobs")[0])
            jobs = self.jobs.get(run_id, [])
            return 200, {"total_count": len(jobs), "jobs": self._page(jobs, params)}
        if method == "GET" and "/git/ref/tags/" in path:
            tag = path.split("/git/ref/tags/")[1]
            if tag not in self.refs:
                return 404, {"message": "Not Found"}
            return 200, self.refs[tag]
        if method == "POST" and path.endswith("/releases/generate-notes"):
            return 200, dict(self.notes)
        if method == "POST" and path == "/repos/%s/releases" % REPO:
            self.created.append(body)
            return 201, {"id": 999, "draft": body.get("draft"),
                         "html_url": "https://github.com/%s/releases/tag/untagged" % REPO}
        raise AssertionError("unexpected request: %s %s" % (method, path))

    def _page(self, items, params):
        page = int(params.get("page", 1))
        self.pages.append(page)
        start = (page - 1) * self.page_size
        return items[start:start + self.page_size]


class Fixture:
    """A small Git history with tagged releases and matching fake CI runs."""

    def __init__(self, testcase):
        temp = tempfile.TemporaryDirectory(prefix="nvim-release-test-")
        testcase.addCleanup(temp.cleanup)
        self.root = Path(temp.name) / "repo"
        self.root.mkdir(parents=True)
        git(self.root, "init", "-b", "main", "-q")
        self.commits = {}
        for name in ("base", "old", "new"):
            (self.root / "file.txt").write_text(name + "\n", encoding="utf-8")
            git(self.root, "add", "file.txt")
            git(self.root, "commit", "-q", "-m", name)
            self.commits[name] = git(self.root, "rev-parse", "HEAD")
        git(self.root, "tag", "v1.2.0", self.commits["old"])
        git(self.root, "tag", "v1.3.0", self.commits["new"])
        git(self.root, "update-ref", "refs/remotes/origin/main", self.commits["new"])
        self.api = FakeApi()
        self.api.add_release("v1.2.0")
        self.api.add_tag_ref("v1.3.0", self.commits["new"])
        self.api.add_run("ci.yml", 11, self.commits["new"], self.api.ok_jobs(CI_JOBS))
        self.api.add_run("windows.yml", 12, self.commits["new"], self.api.ok_jobs(WINDOWS_JOBS))
        self.api.notes = {
            "name": "v1.3.0",
            "body": "## New Features\n* feat: native PowerShell support "
                    "by @D0n9X1n in https://github.com/%s/pull/2\n" % REPO,
        }

    def check(self, tag="v1.3.0"):
        return release.collect_provenance(
            release.Git(self.root), release.GitHubApi(REPO, self.api), tag)

    def main(self, *argv):
        return release.main(list(argv) + ["--root", str(self.root), "--repo", REPO],
                            transport=self.api)


class RequiredJobContract(unittest.TestCase):
    def test_required_jobs_match_the_workflow_contract(self):
        self.assertEqual(release.REQUIRED_JOBS["ci.yml"], CI_JOBS)
        self.assertEqual(release.REQUIRED_JOBS["windows.yml"], WINDOWS_JOBS)
        self.assertEqual(sorted(release.REQUIRED_JOBS), ["ci.yml", "windows.yml"])


class TagParsing(unittest.TestCase):
    def test_accepts_exact_version(self):
        self.assertEqual(release.parse_tag("v1.3.0"), "v1.3.0")

    def test_rejects_invalid_forms(self):
        for value in ("1.3.0", "v1.3", "v1.3.0-rc1", "vv1.3.0", "v01.3.0",
                      "v1.3.0 ", "", "v1.3.0+build", "release-v1.3.0"):
            with self.subTest(value=value):
                with self.assertRaises(release.ReleaseError) as caught:
                    release.parse_tag(value)
                self.assertIn("vMAJOR.MINOR.PATCH", str(caught.exception))


class Provenance(unittest.TestCase):
    def setUp(self):
        self.fixture = Fixture(self)

    def assert_refuses(self, fragment, tag="v1.3.0"):
        with self.assertRaises(release.ReleaseError) as caught:
            self.fixture.check(tag)
        self.assertIn(fragment, str(caught.exception))
        return str(caught.exception)

    def test_valid_tag_records_sources(self):
        record = self.fixture.check()
        self.assertEqual(record["tag"], "v1.3.0")
        self.assertEqual(record["sha"], self.fixture.commits["new"])
        self.assertEqual(record["previous_tag"], "v1.2.0")
        self.assertEqual(record["previous_sha"], self.fixture.commits["old"])
        urls = sorted(run["url"] for run in record["runs"])
        self.assertEqual(urls, ["https://github.com/%s/actions/runs/11" % REPO,
                                "https://github.com/%s/actions/runs/12" % REPO])
        workflows = sorted(run["workflow"] for run in record["runs"])
        self.assertEqual(workflows, ["ci.yml", "windows.yml"])

    def test_rejects_unknown_tag(self):
        self.assert_refuses("not a tag in this checkout", "v9.9.9")

    def test_rejects_tag_not_on_main(self):
        git(self.fixture.root, "update-ref", "refs/remotes/origin/main",
            self.fixture.commits["old"])
        self.assert_refuses("not an ancestor of origin/main")

    def test_rejects_shallow_history(self):
        clone = self.fixture.root.parent / "shallow"
        subprocess.run(["git", "clone", "-q", "--depth", "1",
                        "file://%s" % self.fixture.root, str(clone)],
                       check=True, capture_output=True)
        git(clone, "update-ref", "refs/remotes/origin/main",
            git(clone, "rev-parse", "HEAD"))
        with self.assertRaises(release.ReleaseError) as caught:
            release.collect_provenance(
                release.Git(clone), release.GitHubApi(REPO, self.fixture.api), "v1.3.0")
        self.assertIn("shallow", str(caught.exception))

    def test_rejects_missing_previous_release(self):
        self.fixture.api.releases = []
        self.assert_refuses("no published predecessor release")

    def test_ignores_draft_and_prerelease_predecessors(self):
        self.fixture.api.releases = []
        self.fixture.api.add_release("v1.2.0", draft=True)
        self.fixture.api.add_release("v1.2.1", prerelease=True)
        self.assert_refuses("no published predecessor release")

    def test_rejects_predecessor_that_is_not_an_ancestor(self):
        git(self.fixture.root, "checkout", "-q", "-b", "side", self.fixture.commits["base"])
        (self.fixture.root / "side.txt").write_text("side\n", encoding="utf-8")
        git(self.fixture.root, "add", "side.txt")
        git(self.fixture.root, "commit", "-q", "-m", "side")
        git(self.fixture.root, "tag", "v1.2.9")
        git(self.fixture.root, "checkout", "-q", "main")
        self.fixture.api.releases = []
        self.fixture.api.add_release("v1.2.9")
        self.assert_refuses("no published predecessor release")

    def test_previous_release_follows_ancestry_not_tag_order(self):
        # v1.10.0 sorts after v1.2.0 lexicographically but is an older commit.
        git(self.fixture.root, "tag", "v1.10.0", self.fixture.commits["base"])
        self.fixture.api.add_release("v1.10.0")
        record = self.fixture.check()
        self.assertEqual(record["previous_tag"], "v1.2.0")

    def test_rejects_current_tag_as_its_own_predecessor(self):
        self.fixture.api.releases = []
        self.fixture.api.add_release("v1.3.0")
        self.assert_refuses("no published predecessor release")

    def test_rejects_stale_successful_run_for_another_commit(self):
        self.fixture.api.runs["ci.yml"] = []
        self.fixture.api.add_run("ci.yml", 21, self.fixture.commits["old"],
                                 self.fixture.api.ok_jobs(CI_JOBS))
        self.assert_refuses("ci.yml")

    def test_rejects_pull_request_run(self):
        self.fixture.api.runs["windows.yml"] = []
        self.fixture.api.add_run("windows.yml", 22, self.fixture.commits["new"],
                                 self.fixture.api.ok_jobs(WINDOWS_JOBS),
                                 event="pull_request")
        self.assert_refuses("windows.yml")

    def test_rejects_run_from_another_branch(self):
        self.fixture.api.runs["ci.yml"] = []
        self.fixture.api.add_run("ci.yml", 23, self.fixture.commits["new"],
                                 self.fixture.api.ok_jobs(CI_JOBS), branch="topic")
        self.assert_refuses("ci.yml")

    def test_rejects_run_from_a_fork(self):
        self.fixture.api.runs["ci.yml"] = []
        self.fixture.api.add_run("ci.yml", 24, self.fixture.commits["new"],
                                 self.fixture.api.ok_jobs(CI_JOBS),
                                 repository="someone/nvim-config")
        self.assert_refuses("repository")

    def test_rejects_pending_run(self):
        self.fixture.api.runs["ci.yml"] = []
        self.fixture.api.add_run("ci.yml", 25, self.fixture.commits["new"],
                                 self.fixture.api.ok_jobs(CI_JOBS),
                                 status="in_progress", conclusion=None)
        self.assert_refuses("ci.yml")

    def test_rejects_failed_run(self):
        self.fixture.api.runs["windows.yml"] = []
        self.fixture.api.add_run("windows.yml", 26, self.fixture.commits["new"],
                                 self.fixture.api.ok_jobs(WINDOWS_JOBS),
                                 conclusion="failure")
        self.assert_refuses("windows.yml")

    def test_rejects_missing_required_job(self):
        self.fixture.api.jobs[11] = [
            job for job in self.fixture.api.jobs[11] if job["name"] != "macOS Intel"]
        message = self.assert_refuses("macOS Intel")
        self.assertIn("missing", message)

    def test_rejects_skipped_required_job(self):
        for job in self.fixture.api.jobs[12]:
            if job["name"] == "Neovim 0.12 / pwsh":
                job["conclusion"] = "skipped"
        message = self.assert_refuses("Neovim 0.12 / pwsh")
        self.assertIn("skipped", message)

    def test_rejects_failed_required_job(self):
        for job in self.fixture.api.jobs[11]:
            if job["name"] == "Unix CI":
                job["conclusion"] = "failure"
        self.assert_refuses("Unix CI")

    def test_paginates_releases_and_jobs_exhaustively(self):
        self.fixture.api.page_size = 1
        for index in range(4):
            self.fixture.api.add_release("v0.%d.0" % index)
        record = self.fixture.check()
        self.assertEqual(record["previous_tag"], "v1.2.0")
        self.assertGreater(max(self.fixture.api.pages), 1)

    def test_api_errors_propagate_without_empty_fallback(self):
        self.fixture.api.failures["/releases"] = 500
        self.assert_refuses("500")

    def test_job_api_errors_propagate(self):
        self.fixture.api.failures["/jobs"] = 403
        self.assert_refuses("403")


class Message(unittest.TestCase):
    def setUp(self):
        self.fixture = Fixture(self)
        self.record = self.fixture.check()
        self.body = release.build_body(self.record, self.fixture.api.notes["body"])

    def test_has_title_and_required_sections(self):
        self.assertTrue(self.body.startswith("# Neovim config v1.3.0\n"))
        for heading in ("## Highlights", "## Upgrade", "## Verification",
                        "## Known limitations", "## Changes"):
            self.assertIn(heading, self.body)

    def test_upgrade_shows_both_installers(self):
        self.assertIn("```bash\n./install.sh --no-deps\n```", self.body)
        self.assertIn("```powershell\n./install.ps1 -NoDeps\n```", self.body)
        self.assertIn("private", self.body.lower())

    def test_verification_lists_exact_run_urls_and_job_names(self):
        self.assertIn("https://github.com/%s/actions/runs/11" % REPO, self.body)
        self.assertIn("https://github.com/%s/actions/runs/12" % REPO, self.body)
        for name in CI_JOBS + WINDOWS_JOBS:
            self.assertIn(name, self.body)
        self.assertIn("0.12", self.body)

    def test_highlights_reuse_changelog_titles_only(self):
        self.assertIn("native PowerShell support", self.body)
        self.assertIn("#2", self.body)

    def test_highlights_fall_back_to_a_pointer(self):
        body = release.build_body(self.record, "* commit without a pull request\n")
        self.assertIn("## Highlights", body)
        self.assertIn("Changes", body.split("## Upgrade")[0])

    def test_no_artifact_table_or_publishable_placeholders(self):
        lowered = self.body.lower()
        for banned in ("todo", "tbd", "fixme", "xxx", "download", "checksum",
                       "binaries", "| asset", "placeholder"):
            self.assertNotIn(banned, lowered)

    def test_no_blanket_testing_claims(self):
        self.assertNotIn("fully tested", self.body.lower())
        self.assertIn("not exercised", self.body.lower())


class CommandLine(unittest.TestCase):
    def setUp(self):
        self.fixture = Fixture(self)
        self.record_path = self.fixture.root.parent / "record.json"

    def test_check_writes_record_and_outputs(self):
        outputs = self.fixture.root.parent / "outputs.txt"
        status = self.fixture.main("check", "--tag", "v1.3.0",
                                   "--record", str(self.record_path),
                                   "--github-output", str(outputs))
        self.assertEqual(status, 0)
        record = json.loads(self.record_path.read_text(encoding="utf-8"))
        self.assertEqual(record["sha"], self.fixture.commits["new"])
        self.assertEqual(record["previous_tag"], "v1.2.0")
        text = outputs.read_text(encoding="utf-8")
        self.assertIn("sha=%s" % self.fixture.commits["new"], text)
        self.assertIn("previous_tag=v1.2.0", text)
        self.assertEqual(self.fixture.api.created, [])

    def test_check_makes_no_write_requests(self):
        self.fixture.main("check", "--tag", "v1.3.0", "--record", str(self.record_path))
        methods = {method for method, _, _, _ in self.fixture.api.requests}
        self.assertEqual(methods, {"GET"})

    def test_check_rejects_invalid_tag_with_reason(self):
        status = self.fixture.main("check", "--tag", "v1.3")
        self.assertEqual(status, 1)

    def test_draft_creates_a_draft_release_only(self):
        status = self.fixture.main("draft", "--tag", "v1.3.0",
                                   "--expect-sha", self.fixture.commits["new"])
        self.assertEqual(status, 0)
        self.assertEqual(len(self.fixture.api.created), 1)
        created = self.fixture.api.created[0]
        self.assertIs(created["draft"], True)
        self.assertIs(created["prerelease"], False)
        self.assertEqual(created["tag_name"], "v1.3.0")
        self.assertEqual(created["target_commitish"], self.fixture.commits["new"])
        self.assertIn("# Neovim config v1.3.0", created["body"])

    def test_draft_requests_generated_notes_with_explicit_predecessor(self):
        self.fixture.main("draft", "--tag", "v1.3.0")
        posts = [body for method, path, _, body in self.fixture.api.requests
                 if method == "POST" and path.endswith("generate-notes")]
        self.assertEqual(len(posts), 1)
        self.assertEqual(posts[0]["tag_name"], "v1.3.0")
        self.assertEqual(posts[0]["previous_tag_name"], "v1.2.0")
        self.assertEqual(posts[0]["configuration_file_path"], ".github/release.yml")
        self.assertEqual(posts[0]["target_commitish"], self.fixture.commits["new"])

    def test_draft_refuses_when_the_expected_sha_differs(self):
        status = self.fixture.main("draft", "--tag", "v1.3.0",
                                   "--expect-sha", self.fixture.commits["old"])
        self.assertEqual(status, 1)
        self.assertEqual(self.fixture.api.created, [])

    def test_draft_refuses_a_record_bound_to_another_commit(self):
        self.fixture.main("check", "--tag", "v1.3.0", "--record", str(self.record_path))
        record = json.loads(self.record_path.read_text(encoding="utf-8"))
        record["sha"] = self.fixture.commits["old"]
        self.record_path.write_text(json.dumps(record), encoding="utf-8")
        status = self.fixture.main("draft", "--tag", "v1.3.0",
                                   "--record", str(self.record_path))
        self.assertEqual(status, 1)
        self.assertEqual(self.fixture.api.created, [])

    def test_draft_never_creates_a_tag(self):
        self.fixture.api.refs.clear()
        status = self.fixture.main("draft", "--tag", "v1.3.0")
        self.assertEqual(status, 1)
        self.assertEqual(self.fixture.api.created, [])
        self.assertFalse([request for request in self.fixture.api.requests
                          if request[0] == "POST" and "/git/" in request[1]])

    def test_draft_refuses_when_the_remote_tag_moved(self):
        self.fixture.api.add_tag_ref("v1.3.0", self.fixture.commits["old"])
        status = self.fixture.main("draft", "--tag", "v1.3.0")
        self.assertEqual(status, 1)
        self.assertEqual(self.fixture.api.created, [])

    def test_draft_refuses_to_touch_a_published_release(self):
        self.fixture.api.add_release("v1.3.0")
        status = self.fixture.main("draft", "--tag", "v1.3.0")
        self.assertEqual(status, 1)
        self.assertEqual(self.fixture.api.created, [])

    def test_draft_is_a_no_op_for_an_identical_existing_draft(self):
        record = self.fixture.check()
        body = release.build_body(record, self.fixture.api.notes["body"])
        self.fixture.api.add_release("v1.3.0", draft=True, body=body)
        status = self.fixture.main("draft", "--tag", "v1.3.0")
        self.assertEqual(status, 0)
        self.assertEqual(self.fixture.api.created, [])

    def test_draft_refuses_a_conflicting_existing_draft(self):
        self.fixture.api.add_release("v1.3.0", draft=True, body="hand written")
        status = self.fixture.main("draft", "--tag", "v1.3.0")
        self.assertEqual(status, 1)
        self.assertEqual(self.fixture.api.created, [])

    def test_draft_refuses_an_empty_changelog(self):
        git(self.fixture.root, "tag", "-f", "v1.2.0", self.fixture.commits["new"])
        status = self.fixture.main("draft", "--tag", "v1.3.0")
        self.assertEqual(status, 1)
        self.assertEqual(self.fixture.api.created, [])

    def test_draft_refuses_empty_generated_notes(self):
        self.fixture.api.notes = {"name": "v1.3.0", "body": "   \n"}
        status = self.fixture.main("draft", "--tag", "v1.3.0")
        self.assertEqual(status, 1)
        self.assertEqual(self.fixture.api.created, [])

    def test_rejects_repository_path_injection(self):
        status = release.main(['--repo', 'owner/repo/../../other', 'check', '--tag', 'v1.3.0'],
                              transport=self.fixture.api)
        self.assertEqual(status, 1)
        self.assertEqual(self.fixture.api.requests, [])

    def test_arguments_are_never_evaluated_as_code(self):
        status = self.fixture.main("check", "--tag", "v1.3.0; rm -rf /")
        self.assertEqual(status, 1)


class Workflows(unittest.TestCase):
    root = Path(__file__).resolve().parents[1]

    def read(self, name):
        return (self.root / name).read_text(encoding="utf-8")

    def test_release_workflow_is_fail_closed(self):
        text = self.read(".github/workflows/release.yml")
        self.assertIn("3d3c42e5aac5ba805825da76410c181273ba90b1", text)
        self.assertIn("persist-credentials: false", text)
        self.assertIn("fetch-depth: 0", text)
        self.assertIn("cancel-in-progress: false", text)
        self.assertIn("timeout-minutes:", text)
        self.assertIn("workflow_dispatch", text)
        self.assertIn("contents: write", text)
        self.assertIn("needs: validate", text)
        self.assertNotIn("${{ inputs.tag }}\"", text)
        self.assertNotIn("softprops", text)

    def test_release_workflow_never_interpolates_into_shell(self):
        for line in self.read(".github/workflows/release.yml").splitlines():
            stripped = line.strip()
            if stripped.startswith(("python ", "bash ", "gh ", "- run:")) or \
                    stripped.startswith("git "):
                self.assertNotIn("${{", stripped, line)

    def test_release_notes_configuration_has_categories(self):
        text = self.read(".github/release.yml")
        for label in ("feat", "fix", "docs", "ci", "'*'"):
            self.assertIn(label, text)

    def test_windows_workflow_is_untouched_contract(self):
        text = self.read(".github/workflows/windows.yml")
        self.assertIn("name: Neovim 0.12 / ${{ matrix.shell }}", text)
        self.assertIn("shell: [powershell, pwsh]", text)


if __name__ == "__main__":
    unittest.main()
