#!/usr/bin/env bash
# Remove plugin clones that the config no longer declares, keeping user work.
#
# Usage: prune-plugins.sh <plugin-root> <declared-names-file> [<candidates-file>]
#
# A directory directly under <plugin-root> is removed only when it is not
# declared, not a symlink, and is its own git work tree with no tracked
# changes, no untracked or ignored files other than generated doc/tags or
# doc/tags-<lang>, no stash, and no commit (on HEAD or any branch) missing
# from every remote-tracking ref. Anything else is kept and listed.
# With <candidates-file>, only the names it lists are considered. Empty
# *.cloning markers left by an interrupted install are removed. An empty or
# missing declared list removes nothing and exits non-zero.
set -euo pipefail

root="${1:?plugin root}"
declared_file="${2:?declared names file}"
candidates_file="${3:-}"

[ -d "$root" ] && [ ! -L "$root" ] || exit 0
if [ ! -f "$declared_file" ] || ! grep -q '[^[:space:]]' "$declared_file"; then
  printf 'prune-plugins: no declared plugins; nothing removed.\n' >&2
  exit 1
fi

declared=$'\n'"$(cat "$declared_file")"$'\n'

has_user_work() {
  local dir="$1" line
  git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  [ "$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" = "$(cd "$dir" && pwd -P)" ] || return 0
  git -C "$dir" diff --quiet HEAD -- 2>/dev/null || return 0
  # Untracked files, ignored ones included (an ignore rule is not evidence a
  # file is generated), other than generated help tags.
  while IFS= read -r line; do
    case "$line" in
      doc/tags|doc/tags-[a-z][a-z]) ;;
      *) return 0 ;;
    esac
  done < <(git -C "$dir" ls-files --others)
  [ -z "$(git -C "$dir" stash list 2>/dev/null)" ] || return 0
  # Every local commit (on HEAD, even detached, or any branch) must be on some
  # remote-tracking ref. Shallow clones stop at their upstream boundary.
  [ -z "$(git -C "$dir" rev-list HEAD --branches --not --remotes 2>/dev/null)" ] || return 0
  return 1
}

if [ -n "$candidates_file" ]; then
  names="$(cat "$candidates_file")"
else
  names="$(cd "$root" && find . -mindepth 1 -maxdepth 1 -print | sed 's#^\./##')"
fi

kept=()
while IFS= read -r name; do
  [ -n "$name" ] || continue
  case "$name" in
    */*|.|..) continue ;;
  esac
  path="${root}/${name}"
  [ -e "$path" ] || [ -L "$path" ] || continue
  [ -L "$path" ] && continue
  case "$name" in
    *.cloning)
      if [ -f "$path" ] && [ ! -s "$path" ]; then
        rm -f -- "$path"
        printf 'Removed empty marker %s\n' "$name"
      fi
      continue
      ;;
  esac
  case "$declared" in
    *$'\n'"$name"$'\n'*) continue ;;
  esac
  [ -d "$path" ] || continue
  if has_user_work "$path"; then
    kept+=("$name")
    continue
  fi
  rm -rf -- "$path"
  printf 'Removed unused plugin %s\n' "$name"
done <<<"$names"

if [ "${#kept[@]}" -gt 0 ]; then
  printf 'Kept (not declared, has local work): %s\n' "${kept[*]}"
fi
