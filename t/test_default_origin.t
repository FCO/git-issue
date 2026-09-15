#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

# Verify that `git issue push` / `pull` / `fetch` / `sync` default to the
# `origin` remote when no repository argument is supplied.
#
# Each of these functions reads its remote as `${1:-origin}`, so with NO
# positional args the remote is `origin` and the issue pattern is `*`
# (all issues). All scenarios use a local bare repo registered as `origin`
# (no network) and are deterministic.
#
# Subtlety documented at the end: the dispatcher forwards args positionally
# (remote first, then issue id). A SINGLE positional argument is therefore
# interpreted as the REMOTE, never as the issue id — so `push <id>` and
# `pull <id>` do NOT default to origin.
tap_start

path_add_project
export EDITOR=true VISUAL=true

CLEANUP_DIRS=()
cleanup() { rm -rf "${CLEANUP_DIRS[@]}" 2>/dev/null || true; }
trap cleanup EXIT

mkbare() {
  local dir; dir=$(mktemp -d)
  CLEANUP_DIRS+=("$dir")
  git -C "$dir" init -q --bare
  echo "$dir"
}

mkclone() {
  local remote="$1"
  local dir; dir=$(mkrepo)
  CLEANUP_DIRS+=("$dir")
  git -C "$dir" remote add origin "$remote"
  echo "$dir"
}

title_of() { git -C "$1" show "refs/issues/$2:title"; }

# ---------------------------------------------------------------
# 1) push / fetch / pull with NO repo argument default to origin
# ---------------------------------------------------------------
REMOTE=$(mkbare)
A=$(mkclone "$REMOTE")
B=$(mkclone "$REMOTE")

id=$(new_issue "$A" "Default origin")

# push with no args -> origin (all issues)
git -C "$A" issue push >/dev/null 2>&1
tap_assert "ref_exists '$REMOTE' 'refs/issues/$id'" "push (no args) reaches origin"

# fetch with no args -> origin
git -C "$B" issue fetch >/dev/null 2>&1
tap_assert "ref_exists '$B' 'refs/remote-issues/$id'" "fetch (no args) reads from origin"
if ref_exists "$B" "refs/issues/$id"; then b_imported=yes; else b_imported=no; fi
tap_assert "test \"$b_imported\" = 'no'" "fetch (no args) does not import into refs/issues"

# pull with no args -> origin
git -C "$B" issue pull >/dev/null 2>&1
tap_assert "ref_exists '$B' 'refs/issues/$id'" "pull (no args) imports from origin"
tap_assert "test \"\$(title_of '$B' '$id')\" = 'Default origin'" "pulled title correct"

# ---------------------------------------------------------------
# 2) sync with NO repo argument round-trips through origin
# ---------------------------------------------------------------
REMOTE=$(mkbare)
A=$(mkclone "$REMOTE")
B=$(mkclone "$REMOTE")

id1=$(new_issue "$A" "Sync default one")
id2=$(new_issue "$A" "Sync default two")

git -C "$A" issue sync >/dev/null 2>&1
tap_assert "ref_exists '$REMOTE' 'refs/issues/$id1'" "sync (no args) pushes id1 to origin"
tap_assert "ref_exists '$REMOTE' 'refs/issues/$id2'" "sync (no args) pushes id2 to origin"

git -C "$B" issue sync >/dev/null 2>&1
tap_assert "ref_exists '$B' 'refs/issues/$id1'" "sync (no args) pulls id1 from origin"
tap_assert "ref_exists '$B' 'refs/issues/$id2'" "sync (no args) pulls id2 from origin"

# B replies to id1 and syncs (no args); A syncs (no args) to converge
git -C "$B" issue reply "$id1" >/dev/null 2>&1
git -C "$B" issue sync >/dev/null 2>&1
git -C "$A" issue sync >/dev/null 2>&1

a_tip=$(issue_tip "$A" "$id1"); r_tip=$(issue_tip "$REMOTE" "$id1")
tap_assert "test \"$a_tip\" = \"$r_tip\"" "sync (no args) converges A and origin on id1"
tap_assert "test \"\$(msgs_count '$A' '$id1')\" = '2'" "A sees the synced reply on id1"

# ---------------------------------------------------------------
# 3) subtlety: a single positional arg is the REMOTE, not the issue id.
#    `push <id>` / `pull <id>` therefore do NOT default to origin.
# ---------------------------------------------------------------
REMOTE=$(mkbare)
A=$(mkclone "$REMOTE")
B=$(mkclone "$REMOTE")

id=$(new_issue "$A" "Single arg")

# Publish id to origin properly (with an explicit remote) so that a
# hypothetical "id-only defaults to origin" behavior would be observable.
git -C "$A" issue push origin "$id" >/dev/null 2>&1

# `push <id>` treats <id> as the remote name, so a brand-new issue does NOT
# reach origin (it fails instead of defaulting to origin).
id2=$(new_issue "$A" "Single arg push")
git -C "$A" issue push "$id2" >/dev/null 2>&1 || true
if ref_exists "$REMOTE" "refs/issues/$id2"; then pushed=yes; else pushed=no; fi
tap_assert "test \"$pushed\" = 'no'" "push <id> (no repo) does NOT default to origin (id treated as remote)"

# `pull <id>` treats <id> as the remote name, so a fresh clone does NOT
# import the issue from origin (it fails instead of defaulting to origin).
git -C "$B" issue pull "$id" >/dev/null 2>&1 || true
if ref_exists "$B" "refs/issues/$id"; then imported=yes; else imported=no; fi
tap_assert "test \"$imported\" = 'no'" "pull <id> (no repo) does NOT default to origin (id treated as remote)"

tap_done
