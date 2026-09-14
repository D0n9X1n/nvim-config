#!/usr/bin/env python3
"""Validate exact-commit CI evidence before creating a release draft."""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request


API_ROOT = "https://api.github.com"
API_VERSION = "2022-11-28"
CONFIG_PATH = ".github/release.yml"
RECORD_SCHEMA = "nvim-config/release-provenance/1"
PER_PAGE = 100
MAX_PAGES = 200
TIMEOUT = 30

TAG_PATTERN = re.compile(r"v(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)")

# The exact job names each workflow must report as completed successes for the
# tagged commit. Keep aligned with .github/workflows/ci.yml and windows.yml.
REQUIRED_JOBS = {
    "ci.yml": ("Unix CI", "Ubuntu x86-64", "macOS ARM64", "macOS Intel",
               "Automation contracts"),
    "windows.yml": ("Neovim 0.12 / powershell", "Neovim 0.12 / pwsh"),
}

REQUIRED_EVENT = "push"
REQUIRED_BRANCH = "main"
BASE_REF = "refs/remotes/origin/main"

PR_LINE = re.compile(
    r"^\s*[*-]\s+(?P<title>.+?)\s+by\s+@[A-Za-z0-9][A-Za-z0-9-]*\s+in\s+"
    r"https://github\.com/[^/\s]+/[^/\s]+/pull/(?P<number>\d+)\s*$")


class ReleaseError(Exception):
    """A refusal with a reason a human can act on."""


def parse_tag(value):
    """Accept only an exact vMAJOR.MINOR.PATCH tag, with no affixes."""
    if not isinstance(value, str) or not TAG_PATTERN.fullmatch(value):
        raise ReleaseError(
            "%r is not an exact version tag; expected vMAJOR.MINOR.PATCH "
            "with no prefix, suffix, or pre-release identifier." % (value,))
    return value


class Git:
    """Read-only Git queries against one checkout; never a shell, never config writes."""

    def __init__(self, root):
        self.root = str(root)

    def _run(self, *args):
        return subprocess.run(["git", "-C", self.root, *args],
                              capture_output=True, text=True, check=False)

    def _out(self, *args):
        result = self._run(*args)
        if result.returncode != 0:
            raise ReleaseError("git %s failed: %s" % (
                " ".join(args), result.stderr.strip() or result.stdout.strip()))
        return result.stdout.strip()

    def assert_complete(self):
        if self._out("rev-parse", "--is-shallow-repository") == "true":
            raise ReleaseError(
                "the checkout has shallow history; release validation needs the "
                "full history (checkout with fetch-depth: 0).")

    def commit_of(self, ref):
        """Resolve a ref to a commit, peeling annotated tags; None when absent."""
        result = self._run("rev-parse", "--verify", "--quiet", "%s^{commit}" % ref)
        return result.stdout.strip() or None

    def is_ancestor(self, ancestor, descendant):
        result = self._run("merge-base", "--is-ancestor", ancestor, descendant)
        if result.returncode in (0, 1):
            return result.returncode == 0
        raise ReleaseError("git merge-base failed: %s" % result.stderr.strip())

    def distance(self, ancestor, descendant):
        return int(self._out("rev-list", "--count", "%s..%s" % (ancestor, descendant)))


class GitHubApi:
    """Thin REST client over an injected transport, with exhaustive paging."""

    def __init__(self, repo, transport):
        self.repo = repo
        self.transport = transport

    def _call(self, method, path, params=None, body=None):
        status, data = self.transport(method, path, params=params, body=body)
        if status >= 400:
            message = ""
            if isinstance(data, dict):
                message = str(data.get("message", ""))
            raise ReleaseError("GitHub API %s %s failed with status %s%s" % (
                method, path, status, ": %s" % message if message else ""))
        return data

    def get(self, path, params=None):
        return self._call("GET", path, params=params)

    def get_optional(self, path, params=None):
        """Return None for 404 only; every other failure still propagates."""
        status, data = self.transport("GET", path, params=params, body=None)
        if status == 404:
            return None
        if status >= 400:
            raise ReleaseError("GitHub API GET %s failed with status %s" % (path, status))
        return data

    def post(self, path, body):
        return self._call("POST", path, body=body)

    def paginate(self, path, params=None, key=None):
        """Walk every page until one comes back empty; never silently truncate."""
        collected = []
        page = 1
        while page <= MAX_PAGES:
            query = dict(params or {}, per_page=PER_PAGE, page=page)
            data = self.get(path, query)
            items = data if key is None else data.get(key)
            if items is None:
                raise ReleaseError("GitHub API GET %s returned no %r field" % (path, key))
            if not items:
                return collected
            collected.extend(items)
            page += 1
        raise ReleaseError(
            "GitHub API GET %s did not finish paginating within %d pages; refusing "
            "to act on a partial result." % (path, MAX_PAGES))


def _published_releases(api):
    releases = api.paginate("/repos/%s/releases" % api.repo)
    return [item for item in releases
            if not item.get("draft") and not item.get("prerelease")]


def find_previous_release(git, api, tag, sha):
    """Nearest published predecessor by Git ancestry, never by tag ordering."""
    best = None
    for item in _published_releases(api):
        candidate = item.get("tag_name")
        if not isinstance(candidate, str) or candidate == tag:
            continue
        commit = git.commit_of("refs/tags/%s" % candidate)
        if commit is None or commit == sha:
            continue
        if not git.is_ancestor(commit, sha):
            continue
        distance = git.distance(commit, sha)
        if best is None or distance < best[0]:
            best = (distance, candidate, commit)
    if best is None:
        raise ReleaseError(
            "%s has no published predecessor release that is an ancestor of the "
            "tagged commit; refusing to guess a baseline." % tag)
    return best[1], best[2]


def _validate_jobs(api, workflow, run, required):
    jobs = api.paginate("/repos/%s/actions/runs/%d/jobs" % (api.repo, run["id"]),
                        key="jobs")
    seen = {}
    for job in jobs:
        seen.setdefault(job.get("name"), job)
    for name in required:
        job = seen.get(name)
        if job is None:
            raise ReleaseError(
                "%s run %s is missing the required job %r." % (workflow, run["id"], name))
        if job.get("status") != "completed":
            raise ReleaseError("%s job %r is still %s, not completed." % (
                workflow, name, job.get("status")))
        conclusion = job.get("conclusion")
        if conclusion != "success":
            raise ReleaseError("%s job %r concluded %s, not success." % (
                workflow, name, conclusion))
    return [name for name in required]


def validate_workflow(api, workflow, sha, required):
    """Require one successful main-push run for this exact commit and repository."""
    runs = api.paginate(
        "/repos/%s/actions/workflows/%s/runs" % (api.repo, workflow),
        params={"head_sha": sha, "event": REQUIRED_EVENT, "branch": REQUIRED_BRANCH},
        key="workflow_runs")
    rejected = []
    candidates = []
    for run in runs:
        if run.get("head_sha") != sha:
            rejected.append("run %s ran for %s, not the tagged commit" % (
                run.get("id"), run.get("head_sha")))
            continue
        if run.get("event") != REQUIRED_EVENT:
            rejected.append("run %s was triggered by %s, not %s" % (
                run.get("id"), run.get("event"), REQUIRED_EVENT))
            continue
        if run.get("head_branch") != REQUIRED_BRANCH:
            rejected.append("run %s ran on branch %s, not %s" % (
                run.get("id"), run.get("head_branch"), REQUIRED_BRANCH))
            continue
        full_name = (run.get("repository") or {}).get("full_name")
        if full_name != api.repo:
            rejected.append("run %s belongs to repository %s, not %s" % (
                run.get("id"), full_name, api.repo))
            continue
        if run.get("status") != "completed":
            rejected.append("run %s is still %s" % (run.get("id"), run.get("status")))
            continue
        if run.get("conclusion") != "success":
            rejected.append("run %s concluded %s" % (
                run.get("id"), run.get("conclusion")))
            continue
        candidates.append(run)
    if not candidates:
        detail = "; ".join(rejected) if rejected else "no run reported this commit"
        raise ReleaseError(
            "%s has no successful %s run on %s for commit %s (%s)." % (
                workflow, REQUIRED_EVENT, REQUIRED_BRANCH, sha, detail))
    run = max(candidates, key=lambda item: (item.get("run_number") or 0,
                                            item.get("run_attempt") or 0,
                                            item.get("id") or 0))
    jobs = _validate_jobs(api, workflow, run, required)
    return {"workflow": workflow, "run_id": run["id"], "url": run.get("html_url"),
            "jobs": jobs}


def collect_provenance(git, api, tag):
    """Prove the tag is releasable and return the evidence record."""
    tag = parse_tag(tag)
    git.assert_complete()
    sha = git.commit_of("refs/tags/%s" % tag)
    if sha is None:
        raise ReleaseError("%s is not a tag in this checkout; fetch tags first "
                           "(this tool never creates tags)." % tag)
    base = git.commit_of(BASE_REF)
    if base is None:
        raise ReleaseError(
            "%s is missing; release validation needs the fetched main branch." % BASE_REF)
    if not git.is_ancestor(sha, base):
        raise ReleaseError(
            "%s (%s) is not an ancestor of origin/main; only tags on main are "
            "releasable." % (tag, sha))
    previous_tag, previous_sha = find_previous_release(git, api, tag, sha)
    if git.distance(previous_sha, sha) == 0:
        raise ReleaseError("%s contains no commits after %s; nothing to release." % (
            tag, previous_tag))
    runs = [validate_workflow(api, workflow, sha, REQUIRED_JOBS[workflow])
            for workflow in sorted(REQUIRED_JOBS)]
    return {"schema": RECORD_SCHEMA, "repository": api.repo, "tag": tag, "sha": sha,
            "previous_tag": previous_tag, "previous_sha": previous_sha, "runs": runs}


def _highlights(notes):
    bullets = []
    for line in (notes or "").splitlines():
        match = PR_LINE.match(line)
        if match:
            title = match.group("title").strip()
            bullets.append("- %s (#%s)" % (title, match.group("number")))
        if len(bullets) == 6:
            break
    if bullets:
        return bullets
    # Never invent highlights: point at the generated changelog instead.
    return ["- See the Changes section below for the reviewed changelog."]


def build_body(record, notes):
    """Compose the draft message. Deterministic: identical inputs, identical text."""
    lines = ["# Neovim config %s" % record["tag"], "", "## Highlights", ""]
    lines.extend(_highlights(notes))
    lines += [
        "",
        "## Upgrade",
        "",
        "Update your original checkout and reinstall from it. Local private "
        "extension files are preserved by both installers.",
        "",
        "macOS and Linux:",
        "",
        "```bash",
        "./install.sh --no-deps",
        "```",
        "",
        "Windows PowerShell:",
        "",
        "```powershell",
        "./install.ps1 -NoDeps",
        "```",
        "",
        "## Verification",
        "",
        "Drafted from tagged commit `%s`, validated against successful "
        "main-branch runs for that exact commit:" % record["sha"],
        "",
    ]
    for run in record["runs"]:
        lines.append("- `%s` — %s — %s" % (
            run["workflow"], ", ".join(run["jobs"]), run["url"]))
    lines += [
        "",
        "Those runs exercise Neovim 0.12+ against this configuration. Coverage is "
        "limited to the jobs named above.",
        "",
        "## Known limitations",
        "",
        "- Browser-backed Markdown preview and other optional external tools are "
        "not exercised by the runs above.",
        "- QuickRun language runners are not exercised by the runs above.",
        "- Windows behaviour and its overrides are covered only by the two Windows "
        "jobs listed above; other shells and Windows versions are not exercised.",
        "",
        "## Changes",
        "",
        (notes or "").strip(),
        "",
    ]
    return "\n".join(lines)


def _remote_tag_commit(api, tag):
    """Read the tag that must already exist remotely; this tool never creates one."""
    ref = api.get_optional("/repos/%s/git/ref/tags/%s" % (
        api.repo, urllib.parse.quote(tag, safe="")))
    if ref is None:
        raise ReleaseError(
            "tag %s does not exist on the remote; push the tag yourself first "
            "(this tool never creates tags)." % tag)
    obj = ref.get("object") or {}
    if obj.get("type") == "tag":
        annotated = api.get("/repos/%s/git/tags/%s" % (api.repo, obj.get("sha")))
        obj = annotated.get("object") or {}
    return obj.get("sha")


def _existing_release(api, tag):
    for item in api.paginate("/repos/%s/releases" % api.repo):
        if item.get("tag_name") == tag:
            return item
    return None


def command_check(git, api, args):
    record = collect_provenance(git, api, args.tag)
    if args.record:
        path = Path(args.record)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n",
                        encoding="utf-8")
    if args.github_output:
        with open(args.github_output, "a", encoding="utf-8") as handle:
            handle.write("tag=%s\n" % record["tag"])
            handle.write("sha=%s\n" % record["sha"])
            handle.write("previous_tag=%s\n" % record["previous_tag"])
            handle.write("run_urls=%s\n" % " ".join(
                run["url"] for run in record["runs"]))
    print("%s validated at %s (after %s); runs: %s" % (
        record["tag"], record["sha"], record["previous_tag"],
        ", ".join(run["url"] for run in record["runs"])))
    return 0


def command_draft(git, api, args):
    record = collect_provenance(git, api, args.tag)
    if args.expect_sha and args.expect_sha != record["sha"]:
        raise ReleaseError(
            "validated commit %s does not match the expected commit %s; the tag "
            "moved between validation and drafting." % (record["sha"], args.expect_sha))
    if args.record:
        try:
            saved = json.loads(Path(args.record).read_text(encoding="utf-8"))
        except (OSError, ValueError) as error:
            raise ReleaseError("cannot read the provenance record: %s" % error)
        if saved.get("tag") != record["tag"] or saved.get("sha") != record["sha"]:
            raise ReleaseError(
                "the provenance record is bound to %s at %s, not %s at %s." % (
                    saved.get("tag"), saved.get("sha"), record["tag"], record["sha"]))
    remote_sha = _remote_tag_commit(api, record["tag"])
    if remote_sha != record["sha"]:
        raise ReleaseError("remote tag %s points at %s, not the validated commit %s." % (
            record["tag"], remote_sha, record["sha"]))
    existing = _existing_release(api, record["tag"])
    if existing is not None and not existing.get("draft"):
        raise ReleaseError(
            "a published release already exists for %s (%s); it is never "
            "overwritten." % (record["tag"], existing.get("html_url")))
    notes = api.post("/repos/%s/releases/generate-notes" % api.repo, {
        "tag_name": record["tag"],
        "previous_tag_name": record["previous_tag"],
        "target_commitish": record["sha"],
        "configuration_file_path": CONFIG_PATH,
    })
    generated = (notes or {}).get("body") or ""
    if not generated.strip():
        raise ReleaseError(
            "GitHub generated an empty changelog between %s and %s; refusing to "
            "draft an empty release." % (record["previous_tag"], record["tag"]))
    body = build_body(record, generated)
    if existing is not None:
        if (existing.get("body") or "") == body:
            print("draft for %s already matches; nothing to do." % record["tag"])
            return 0
        raise ReleaseError(
            "a different draft already exists for %s (%s); delete or reconcile it "
            "before regenerating." % (record["tag"], existing.get("html_url")))
    created = api.post("/repos/%s/releases" % api.repo, {
        "tag_name": record["tag"],
        "target_commitish": record["sha"],
        "name": record["tag"],
        "body": body,
        "draft": True,
        "prerelease": False,
    })
    print("draft created for %s: %s" % (record["tag"], created.get("html_url")))
    return 0


def http_transport(method, path, params=None, body=None):
    """Real transport. Token comes from the environment, never from an argument."""
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if not token:
        raise ReleaseError("GH_TOKEN or GITHUB_TOKEN must be set for API access.")
    url = API_ROOT + path
    if params:
        url += "?" + urllib.parse.urlencode(params)
    payload = None if body is None else json.dumps(body).encode("utf-8")
    request = urllib.request.Request(url, data=payload, method=method)
    request.add_header("Accept", "application/vnd.github+json")
    request.add_header("X-GitHub-Api-Version", API_VERSION)
    request.add_header("Authorization", "Bearer %s" % token)
    request.add_header("User-Agent", "nvim-config-release")
    if payload is not None:
        request.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        raw = error.read()
        try:
            data = json.loads(raw) if raw else {}
        except ValueError:
            data = {"message": "unparsable response"}
        return error.code, data
    except urllib.error.URLError as error:
        raise ReleaseError("GitHub API request failed: %s" % error)


def main(argv=None, transport=None):
    # --root/--repo are accepted before or after the subcommand. The shared copy
    # suppresses its defaults so an absent flag never clobbers the outer value.
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--root", default=argparse.SUPPRESS,
                        help="repository checkout to inspect")
    common.add_argument("--repo", default=argparse.SUPPRESS,
                        help="owner/name of the repository")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", default=".", help="repository checkout to inspect")
    parser.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY"),
                        help="owner/name of the repository")
    subcommands = parser.add_subparsers(dest="command", required=True)
    check = subcommands.add_parser("check", parents=[common],
                                   help="read-only provenance validation")
    check.add_argument("--tag", required=True)
    check.add_argument("--record", help="write the evidence record to this path")
    check.add_argument("--github-output", help="append step outputs to this path")
    draft = subcommands.add_parser("draft", parents=[common],
                                   help="create a GitHub draft release")
    draft.add_argument("--tag", required=True)
    draft.add_argument("--expect-sha", help="commit the validation job proved")
    draft.add_argument("--record", help="evidence record to re-bind against")
    args = parser.parse_args(argv)
    try:
        if not args.repo or not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", args.repo):
            raise ReleaseError("--repo or GITHUB_REPOSITORY must be an owner/repository name.")
        git = Git(args.root)
        api = GitHubApi(args.repo, transport if transport is not None else http_transport)
        if args.command == "check":
            return command_check(git, api, args)
        return command_draft(git, api, args)
    except ReleaseError as error:
        print("release: %s" % error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
