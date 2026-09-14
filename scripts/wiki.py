#!/usr/bin/env python3
"""Render README links and safely synchronize a managed Wiki Home page."""

import argparse
import os
import posixpath
import re
import subprocess
import sys
from urllib.parse import quote, unquote


MARKER = "<!-- nvim-config:managed-home -->"
SOURCE = "README.md"
PAGE = "Home.md"
REPOSITORY = re.compile(r"\A[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._-]*\Z")
COMMIT = re.compile(r"\A[0-9a-f]{40}\Z")
ORIGIN = re.compile(r"github\.com[:/]+([A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._-]*?)(?:\.git)?/?\Z")
FENCE = re.compile(r"\A {0,3}(`{3,}|~{3,})")
HEADING = re.compile(r"\A {0,3}(#{1,6})\s+(.*?)\s*\Z")
DEFINITION = re.compile(r"\A {0,3}\[[^\]]+\]:\s*\S+")
INLINE = re.compile(r"!?\[([^\]]*)\]\([^)]*\)")
TITLED = re.compile(r"\A(\S+)\s+(\"[^\"]*\"|'[^']*')\Z")
EXTERNAL = re.compile(r"\A(?:[A-Za-z][A-Za-z0-9+.-]*:|//)")
SYMLINK = "120000"


class WikiError(Exception):
    """A single refusal carrying the documented machine-readable reason."""

    def __init__(self, reason, detail):
        super().__init__(reason + ": " + detail)
        self.problems = [(reason, detail)]


class ValidationError(WikiError):
    """Several link or anchor refusals reported together."""

    def __init__(self, problems):
        Exception.__init__(self, "; ".join(r + ": " + d for r, d in problems))
        self.problems = problems


def git(root, *args, reason="git-failed"):
    result = subprocess.run(["git", "-C", str(root), *args],
                            capture_output=True, text=True, timeout=120)
    if result.returncode != 0:
        raise WikiError(reason, (result.stderr or result.stdout).strip())
    return result.stdout


def tracked(root):
    """Map tracked paths to their Git modes; directories are derived from them."""
    listing = git(root, "ls-files", "-s", "-z", reason="not-a-repository")
    files, directories = {}, set()
    for entry in listing.split("\0"):
        if not entry:
            continue
        meta, _, path = entry.partition("\t")
        files[path] = meta.split()[0]
        parent = posixpath.dirname(path)
        while parent:
            directories.add(parent)
            parent = posixpath.dirname(parent)
    return files, directories


def mask_fences(text):
    """Blank fenced code blocks, preserving offsets so spans stay comparable."""
    lines = text.split("\n")
    out, fence = [], None
    for line in lines:
        match = FENCE.match(line)
        if fence is None and match:
            fence = match.group(1)
            out.append(" " * len(line))
            continue
        if fence is not None:
            closing = match and match.group(1)[0] == fence[0] \
                and len(match.group(1)) >= len(fence)
            out.append(" " * len(line))
            if closing:
                fence = None
            continue
        out.append(line)
    return "\n".join(out)


def mask_inline(text):
    """Blank inline code spans so backticked examples are never treated as links."""
    out = list(text)
    index, length = 0, len(text)
    while index < length:
        if text[index] != "`":
            index += 1
            continue
        start = index
        while index < length and text[index] == "`":
            index += 1
        ticks = index - start
        probe = index
        while probe < length:
            if text[probe] != "`":
                probe += 1
                continue
            run = probe
            while probe < length and text[probe] == "`":
                probe += 1
            if probe - run == ticks:
                for position in range(start, probe):
                    if out[position] != "\n":
                        out[position] = " "
                index = probe
                break
        else:
            break
    return "".join(out)


def slug(title):
    """GitHub's heading anchor: drop inline markup, keep word characters."""
    plain = INLINE.sub(lambda m: m.group(1), title).replace("`", "")
    plain = re.sub(r"\s*#+\s*\Z", "", plain).strip().lower()
    kept = [c if (c.isalnum() or c in " -_") else "" for c in plain]
    return "".join(kept).replace(" ", "-")


def anchors(text):
    """Every heading anchor in a document, including GitHub's duplicate suffixes."""
    seen, found = {}, set()
    for line in mask_fences(text).split("\n"):
        match = HEADING.match(line)
        if not match:
            continue
        base = slug(match.group(2))
        count = seen.get(base, 0)
        seen[base] = count + 1
        found.add(base if count == 0 else base + "-" + str(count))
    return found


def close_bracket(text, start, end):
    depth, index = 0, start
    while index < end:
        char = text[index]
        if char == "\\":
            index += 2
            continue
        if char == "[":
            depth += 1
        elif char == "]":
            depth -= 1
            if depth == 0:
                return index
        index += 1
    return None


def close_paren(text, start, end):
    depth, index = 0, start
    while index < end:
        char = text[index]
        if char == "\\":
            index += 2
            continue
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                return index
        index += 1
    return None


def iter_links(text, start=0, end=None):
    """Yield (kind, span_start, span_end, destination) for inline constructs."""
    end = len(text) if end is None else end
    index = start
    while index < end:
        char = text[index]
        if char == "\\":
            index += 2
            continue
        if char != "[" and not (char == "!" and text[index:index + 2] == "!["):
            index += 1
            continue
        image = char == "!"
        opening = index + 1 if image else index
        closing = close_bracket(text, opening, end)
        if closing is None:
            index += 1
            continue
        following = text[closing + 1:closing + 2]
        if following == "(":
            paren = close_paren(text, closing + 1, end)
            if paren is not None:
                # Nested constructs first: a badge image inside a link's text.
                yield from iter_links(text, opening + 1, closing)
                yield ("image" if image else "link", closing + 2, paren,
                       text[closing + 2:paren])
                index = paren + 1
                continue
        if following == "[":
            yield ("reference", index, closing + 1, text[index:closing + 1])
        index = closing + 1


def line_of(text, offset):
    return text.count("\n", 0, offset) + 1


def read_source(root, files, path, reason):
    if files.get(path) == SYMLINK or os.path.islink(os.path.join(root, path)):
        raise WikiError(reason, path + " is a symbolic link")
    try:
        return open(os.path.join(root, path), "rb").read().decode("utf-8")
    except FileNotFoundError:
        raise WikiError("missing-source", path + " is absent from the worktree")
    except UnicodeDecodeError:
        raise WikiError("invalid-encoding", path + " is not valid UTF-8")


def resolve(destination, kind, root, files, directories, cache, own):
    """Validate one destination and return its replacement, or None to keep it."""
    target = destination.strip()
    if target.startswith("<") and target.endswith(">"):
        target = target[1:-1]
    if not target:
        raise WikiError("invalid-destination", "empty link destination")
    if "\\" in target or "\n" in target:
        raise WikiError("invalid-destination", target)
    title = TITLED.match(target)
    if title:
        target = title.group(1)
    elif re.search(r"\s", target):
        raise WikiError("unsupported-link-syntax", target)
    if target.startswith("#"):
        if slugify_fragment(target[1:]) not in own:
            raise WikiError("missing-anchor", target)
        return None
    if EXTERNAL.match(target):
        return None
    if target.startswith("/"):
        raise WikiError("absolute-path", target)
    path, _, fragment = target.partition("#")
    plain = posixpath.normpath(unquote(path))
    if plain == ".." or plain.startswith("../") or plain == ".":
        raise WikiError("escapes-repository", target)
    mode = files.get(plain)
    probe = root
    for part in plain.split('/'):
        probe = os.path.join(probe, part)
        if os.path.islink(probe):
            raise WikiError("symlink-target", target)
    if mode == SYMLINK:
        raise WikiError("symlink-target", target)
    if (mode is None and plain not in directories) or not os.path.exists(probe):
        raise WikiError("missing-target", target)
    directory = mode is None
    if fragment and not directory and plain.lower().endswith(".md"):
        if plain not in cache:
            cache[plain] = anchors(read_source(root, files, plain,
                                               "symlink-target"))
        if slugify_fragment(fragment) not in cache[plain]:
            raise WikiError("missing-anchor", target)
    if kind == "image":
        if directory:
            raise WikiError("invalid-image-target", target)
        return "RAW/" + quote(plain, safe="/._-")
    prefix = "TREE/" if directory else "BLOB/"
    return prefix + quote(plain, safe="/._-") + ("#" + fragment if fragment else "")


def slugify_fragment(fragment):
    return unquote(fragment).strip().lower()


def render(root, repository, sha):
    """Produce the managed Home page, refusing any source we cannot vouch for."""
    if not REPOSITORY.match(repository or ""):
        raise WikiError("invalid-repository", str(repository))
    if not COMMIT.match(sha or ""):
        raise WikiError("invalid-sha", str(sha))
    files, directories = tracked(root)
    if SOURCE not in files:
        raise WikiError("missing-source", SOURCE + " is not tracked")
    text = read_source(root, files, SOURCE, "symlink-source")
    if not text.strip():
        raise WikiError("empty-source", SOURCE + " has no content")

    fenced = mask_fences(text)
    masked = mask_inline(fenced)
    for number, line in enumerate(fenced.split("\n"), 1):
        if DEFINITION.match(line):
            raise WikiError("unsupported-link-syntax",
                            "reference definition on line " + str(number))

    own, cache, problems, edits = anchors(text), {}, [], []
    blob = "https://github.com/" + repository + "/blob/" + sha + "/"
    tree = "https://github.com/" + repository + "/tree/" + sha + "/"
    raw = "https://raw.githubusercontent.com/" + repository + "/" + sha + "/"
    checked = 0
    for kind, start, end, destination in iter_links(masked):
        where = " (line " + str(line_of(masked, start)) + ")"
        if kind == "reference":
            problems.append(("unsupported-link-syntax",
                             destination.strip() + where))
            continue
        checked += 1
        try:
            replacement = resolve(destination, kind, root, files, directories,
                                  cache, own)
        except WikiError as error:
            problems.extend((r, d + where) for r, d in error.problems)
            continue
        if replacement is None:
            continue
        replacement = replacement.replace("RAW/", raw, 1)
        replacement = replacement.replace("BLOB/", blob, 1)
        replacement = replacement.replace("TREE/", tree, 1)
        edits.append((start, end, replacement))
    if problems:
        raise ValidationError(problems)

    body = []
    cursor = 0
    for start, end, replacement in sorted(edits):
        body.append(text[cursor:start])
        body.append(replacement)
        cursor = end
    body.append(text[cursor:])
    header = (MARKER + "\n"
              + "<!-- source-sha: " + sha + " -->\n"
              + "<!-- Generated from " + SOURCE + " by scripts/wiki.py."
              + " Edit the README, not this page. -->\n\n")
    return header + "".join(body).rstrip("\n") + "\n", checked, len(edits)


def worktree(path):
    if not os.path.isdir(path):
        raise WikiError("not-a-worktree", str(path) + " is not a directory")
    top = git(path, "rev-parse", "--show-toplevel",
              reason="not-a-worktree").strip()
    if os.path.realpath(top) != os.path.realpath(path):
        raise WikiError("not-a-worktree", str(path) + " is not a worktree root")
    return top


def remote_branch(path):
    try:
        head = git(path, "symbolic-ref", "--short", "refs/remotes/origin/HEAD",
                   reason="unknown-remote-branch").strip()
    except WikiError:
        raise WikiError("unknown-remote-branch",
                        "the Wiki has no initial page; create Home once in the"
                        " GitHub Wiki UI before publishing")
    return head.split("/", 1)[1] if "/" in head else head


def sync(root, repository, sha, wiki, push, expect_base, name, email):
    content, checked, rewritten = render(root, repository, sha)
    top = worktree(wiki)
    status = [line for line in git(top, "status", "--porcelain").split("\n")
              if line.strip()]
    untracked = {line[3:] for line in status if line.startswith("??")}
    if [line for line in status if not line.startswith("??")] \
            or untracked - {PAGE}:
        raise WikiError("dirty-worktree",
                        "refusing to publish into a modified Wiki checkout")
    if PAGE in untracked:
        raise WikiError("untracked-home-collision",
                        PAGE + " exists but is untracked")

    branch = remote_branch(top)
    base = git(top, "rev-parse", "HEAD", reason="unknown-remote-branch").strip()
    if expect_base and base != expect_base:
        raise WikiError("unexpected-base",
                        "wiki is at " + base + ", expected " + expect_base)

    page = os.path.join(top, PAGE)
    if os.path.islink(page):
        raise WikiError("home-symlink", PAGE + " is a symbolic link")
    if os.path.exists(page):
        try:
            existing = open(page, "rb").read().decode("utf-8")
        except UnicodeDecodeError:
            raise WikiError("unowned-home", PAGE + " is not valid UTF-8")
        if not existing.startswith(MARKER):
            raise WikiError("unowned-home",
                            PAGE + " was written by hand; it is never adopted"
                            " automatically")
        if existing == content:
            print("wiki: unchanged (" + str(checked) + " links checked)")
            return 0
    with open(page, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(content)
    git(top, "add", "--", PAGE)
    message = "docs(wiki): sync Home from README@" + sha[:7]
    git(top, "-c", "user.name=" + name, "-c", "user.email=" + email,
        "commit", "-q", "-m", message, reason="commit-failed")
    commit = git(top, "rev-parse", "HEAD").strip()
    print("wiki: committed " + commit[:12] + " to " + branch
          + " (" + str(rewritten) + " links rewritten)")
    if push:
        # A plain, non-forced push: a concurrent Wiki edit makes Git refuse.
        result = subprocess.run(
            ["git", "-C", top, "push", "origin", "HEAD:refs/heads/" + branch],
            capture_output=True, text=True, timeout=120)
        if result.returncode != 0:
            raise WikiError("push-rejected",
                            (result.stderr or result.stdout).strip())
        print("wiki: pushed " + commit[:12] + " to " + branch)
    return 0


def infer_repository(root):
    try:
        url = git(root, "remote", "get-url", "origin").strip()
    except WikiError:
        return os.environ.get("GITHUB_REPOSITORY")
    match = ORIGIN.search(url)
    return match.group(1) if match else os.environ.get("GITHUB_REPOSITORY")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("command", choices=("build", "check", "sync"))
    parser.add_argument("--root", default=os.getcwd(),
                        help="source checkout (default: current directory)")
    parser.add_argument("--repo", help="owner/name (default: the origin remote)")
    parser.add_argument("--sha", help="source commit (default: HEAD)")
    parser.add_argument("--output", help="write the rendered page here")
    parser.add_argument("--wiki", help="path to an existing Wiki clone")
    parser.add_argument("--push", action="store_true",
                        help="push the sync commit to the Wiki remote")
    parser.add_argument("--expect-base",
                        help="require this Wiki commit before publishing")
    parser.add_argument("--author-name", default="nvim-config wiki bot")
    parser.add_argument("--author-email",
                        default="nvim-config-wiki-bot@users.noreply.github.com")
    args = parser.parse_args(argv)

    try:
        root = os.path.abspath(args.root)
        repository = args.repo or infer_repository(root)
        sha = args.sha
        if not sha:
            sha = git(root, "rev-parse", "HEAD", reason="invalid-sha").strip()
        if args.command == "sync":
            if not args.wiki:
                raise WikiError("missing-argument", "sync requires --wiki")
            return sync(root, repository, sha, os.path.abspath(args.wiki),
                        args.push, args.expect_base, args.author_name,
                        args.author_email)
        if args.command == "build" and not args.output:
            raise WikiError("missing-argument", "build requires --output")
        content, checked, rewritten = render(root, repository, sha)
        if args.output:
            directory = os.path.dirname(os.path.abspath(args.output))
            if directory:
                os.makedirs(directory, exist_ok=True)
            with open(args.output, "w", encoding="utf-8", newline="\n") as out:
                out.write(content)
        print("wiki: rendered " + PAGE + " from " + SOURCE + " at "
              + repository + "@" + sha + " (" + str(checked) + " links checked, "
              + str(rewritten) + " rewritten)")
        return 0
    except WikiError as error:
        for reason, detail in error.problems:
            sys.stderr.write("wiki: error: " + reason + ": " + detail + "\n")
        return 1


if __name__ == "__main__":
    sys.exit(main())
