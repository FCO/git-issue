#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

# Tests for the "all issues" (wildcard `*`) path of push/pull/fetch/sync:
# invoking these commands with NO issue id must operate on every local issue,
# across the mix of "new to local", "fast-forward" and "divergent merge" cases.
# All scenarios use a local bare repo as the "remote" (no network).
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

title_of()  { git -C "$1" show "refs/issues/$2:title"; }
status_of() { git -C "$1" show "refs/issues/$2:status"; }

# ---------------------------------------------------------------
# 1) push all issues at once; fetch all; pull all into a second repo
# ---------------------------------------------------------------
REMOTE=$(mkbare)
A=$(mkclone "$REMOTE")
B=$(mkclone "$REMOTE")

id1=$(new_issue "$A" "Alpha")
id2=$(new_issue "$A" "Beta")
id3=$(new_issue "$A" "Gamma")

# push all three with no id (wildcard *)
git -C "$A" issue push origin >/dev/null 2>&1
tap_assert "ref_exists '$REMOTE' 'refs/issues/$id1'" "push * sends id1"
tap_assert "ref_exists '$REMOTE' 'refs/issues/$id2'" "push * sends id2"
tap_assert "ref_exists '$REMOTE' 'refs/issues/$id3'" "push * sends id3"

# fetch all with no id populates every refs/remote-issues/* ref
git -C "$B" issue fetch origin >/dev/null 2>&1
tap_assert "ref_exists '$B' 'refs/remote-issues/$id1'" "fetch * populates remote-issues id1"
tap_assert "ref_exists '$B' 'refs/remote-issues/$id2'" "fetch * populates remote-issues id2"
tap_assert "ref_exists '$B' 'refs/remote-issues/$id3'" "fetch * populates remote-issues id3"

# pull all with no id imports all three (new-to-local)
git -C "$B" issue pull origin >/dev/null 2>&1
tap_assert "ref_exists '$B' 'refs/issues/$id1'" "pull * imports id1"
tap_assert "ref_exists '$B' 'refs/issues/$id2'" "pull * imports id2"
tap_assert "ref_exists '$B' 'refs/issues/$id3'" "pull * imports id3"
tap_assert "test \"\$(title_of '$B' '$id1')\" = 'Alpha'" "id1 title correct"
tap_assert "test \"\$(title_of '$B' '$id2')\" = 'Beta'"  "id2 title correct"
tap_assert "test \"\$(title_of '$B' '$id3')\" = 'Gamma'" "id3 title correct"
tap_assert "test \"\$(status_of '$B' '$id1')\" = 'open'" "id1 status open"
tap_assert "test \"\$(msgs_count '$B' '$id1')\" = '1'" "id1 has 1 message"
tap_assert "test \"\$(msgs_count '$B' '$id2')\" = '1'" "id2 has 1 message"
tap_assert "test \"\$(msgs_count '$B' '$id3')\" = '1'" "id3 has 1 message"

# ---------------------------------------------------------------
# 2) single wildcard pull handles fast-forward + divergent merge + new import
# ---------------------------------------------------------------
REMOTE=$(mkbare)
A=$(mkclone "$REMOTE")
B=$(mkclone "$REMOTE")

id1=$(new_issue "$A" "Fast-forward")
id2=$(new_issue "$A" "Divergent")
git -C "$A" issue push origin >/dev/null 2>&1
git -C "$B" issue pull origin >/dev/null 2>&1

# id1: only A advances (B fast-forwards)
git -C "$A" issue reply "$id1" >/dev/null 2>&1
# id2: both advance independently (B three-way merges)
git -C "$A" issue reply "$id2" >/dev/null 2>&1
git -C "$B" issue reply "$id2" >/dev/null 2>&1
# id3: brand-new issue on A (new to B)
id3=$(new_issue "$A" "Brand new")

git -C "$A" issue push origin >/dev/null 2>&1

# one wildcard pull handles fast-forward + merge + import together
git -C "$B" issue pull origin >/dev/null 2>&1
tap_assert "test \"\$(msgs_count '$B' '$id1')\" = '2'" "single pull fast-forwards id1 to 2 msgs"
tap_assert "test \"\$(msgs_count '$B' '$id2')\" = '3'" "single pull merges divergent id2 to 3 msgs"
tap_assert "ref_exists '$B' 'refs/issues/$id3'" "single pull imports brand-new id3"
tap_assert "test \"\$(title_of '$B' '$id3')\" = 'Brand new'" "imported id3 title correct"

parent_words=$(git -C "$B" rev-list --parents -n 1 "refs/issues/$id2" | wc -w | tr -d ' ')
tap_assert "test \"$parent_words\" = '3'" "id2 tip is a two-parent merge commit"

# ---------------------------------------------------------------
# 3) wildcard push auto-retry when MULTIPLE issues are rejected at once
# ---------------------------------------------------------------
REMOTE=$(mkbare)
A=$(mkclone "$REMOTE")
B=$(mkclone "$REMOTE")

id1=$(new_issue "$A" "Retry one")
id2=$(new_issue "$A" "Retry two")
git -C "$A" issue push origin >/dev/null 2>&1
git -C "$B" issue pull origin >/dev/null 2>&1

# both users diverge on both issues
git -C "$A" issue reply "$id1" >/dev/null 2>&1
git -C "$A" issue reply "$id2" >/dev/null 2>&1
git -C "$B" issue reply "$id1" >/dev/null 2>&1
git -C "$B" issue reply "$id2" >/dev/null 2>&1

git -C "$B" issue push origin >/dev/null 2>&1

# A pushes all: both refs are rejected, then auto-pulled and re-pushed
push_out=$(git -C "$A" issue push origin 2>&1 || true)
tap_assert "echo \"$push_out\" | grep -q 'rejected'" "wildcard push rejected on first attempt"

a_tip1=$(issue_tip "$A" "$id1"); r_tip1=$(issue_tip "$REMOTE" "$id1")
a_tip2=$(issue_tip "$A" "$id2"); r_tip2=$(issue_tip "$REMOTE" "$id2")
tap_assert "test \"$a_tip1\" = \"$r_tip1\"" "id1 converges after auto-retry"
tap_assert "test \"$a_tip2\" = \"$r_tip2\"" "id2 converges after auto-retry"
tap_assert "test \"\$(msgs_count '$REMOTE' '$id1')\" = '3'" "remote id1 holds union of 3 msgs"
tap_assert "test \"\$(msgs_count '$REMOTE' '$id2')\" = '3'" "remote id2 holds union of 3 msgs"

# ---------------------------------------------------------------
# 4) mixed wildcard push: fast-forward an ahead issue + new issue + unchanged
# ---------------------------------------------------------------
REMOTE=$(mkbare)
A=$(mkclone "$REMOTE")
B=$(mkclone "$REMOTE")

id1=$(new_issue "$A" "Existing")
id2=$(new_issue "$A" "Existing ahead")
git -C "$A" issue push origin >/dev/null 2>&1
git -C "$B" issue pull origin >/dev/null 2>&1

# B advances id1 (ahead) and creates a brand-new id3 (new to remote)
git -C "$B" issue reply "$id1" >/dev/null 2>&1
id3=$(new_issue "$B" "Brand new")

git -C "$B" issue push origin >/dev/null 2>&1
tap_assert "test \"\$(msgs_count '$REMOTE' '$id1')\" = '2'" "push * fast-forwards ahead issue id1"
tap_assert "ref_exists '$REMOTE' 'refs/issues/$id3'" "push * sends brand-new issue id3"
tap_assert "test \"\$(msgs_count '$REMOTE' '$id2')\" = '1'" "push * leaves unchanged issue id2 intact"

# ---------------------------------------------------------------
# 5) sync (no id) round-trips converge
# ---------------------------------------------------------------
REMOTE=$(mkbare)
A=$(mkclone "$REMOTE")
B=$(mkclone "$REMOTE")

id1=$(new_issue "$A" "Sync one")
id2=$(new_issue "$A" "Sync two")
git -C "$A" issue sync origin >/dev/null 2>&1
tap_assert "ref_exists '$REMOTE' 'refs/issues/$id1'" "sync * pushes id1"
tap_assert "ref_exists '$REMOTE' 'refs/issues/$id2'" "sync * pushes id2"

git -C "$B" issue sync origin >/dev/null 2>&1
tap_assert "ref_exists '$B' 'refs/issues/$id1'" "sync * pulls id1 into B"
tap_assert "ref_exists '$B' 'refs/issues/$id2'" "sync * pulls id2 into B"

# B replies to both and syncs; A syncs to converge
git -C "$B" issue reply "$id1" >/dev/null 2>&1
git -C "$B" issue reply "$id2" >/dev/null 2>&1
git -C "$B" issue sync origin >/dev/null 2>&1
git -C "$A" issue sync origin >/dev/null 2>&1

a_tip1=$(issue_tip "$A" "$id1"); r_tip1=$(issue_tip "$REMOTE" "$id1")
a_tip2=$(issue_tip "$A" "$id2"); r_tip2=$(issue_tip "$REMOTE" "$id2")
tap_assert "test \"$a_tip1\" = \"$r_tip1\"" "sync * converges id1"
tap_assert "test \"$a_tip2\" = \"$r_tip2\"" "sync * converges id2"
tap_assert "test \"\$(msgs_count '$A' '$id1')\" = '2'" "A sees synced reply for id1"
tap_assert "test \"\$(msgs_count '$A' '$id2')\" = '2'" "A sees synced reply for id2"

# ---------------------------------------------------------------
# 6) empty wildcard push/pull/fetch are clean no-ops (no local issues)
# ---------------------------------------------------------------
REMOTE=$(mkbare)
A=$(mkclone "$REMOTE")

push_out=$(git -C "$A" issue push origin 2>&1) && push_rc=0 || push_rc=$?
tap_assert "test \"$push_rc\" = '0'" "empty wildcard push returns 0"
tap_assert "! echo \"$push_out\" | grep -qE 'fatal|error|No refs in common'" "empty wildcard push produces no error output"

pull_out=$(git -C "$A" issue pull origin 2>&1) && pull_rc=0 || pull_rc=$?
tap_assert "test \"$pull_rc\" = '0'" "empty wildcard pull returns 0"

fetch_out=$(git -C "$A" issue fetch origin 2>&1) && fetch_rc=0 || fetch_rc=$?
tap_assert "test \"$fetch_rc\" = '0'" "empty wildcard fetch returns 0"

# ---------------------------------------------------------------
# 7) stale refs/remote-issues/* are pruned: deleted remote issues not resurrected
# ---------------------------------------------------------------
REMOTE=$(mkbare)
A=$(mkclone "$REMOTE")
B=$(mkclone "$REMOTE")

id1=$(new_issue "$A" "Survivor")
id2=$(new_issue "$A" "Deleted")
git -C "$A" issue push origin >/dev/null 2>&1

# B fetches both (populating refs/remote-issues/*) but does not import them
git -C "$B" issue fetch origin >/dev/null 2>&1
tap_assert "ref_exists '$B' 'refs/remote-issues/$id2'" "B has fetched remote-issues for id2"

# id2 is deleted on the remote
git -C "$REMOTE" update-ref -d "refs/issues/$id2"

# B pulls all: id2 must not be resurrected from the stale remote-issues ref
git -C "$B" issue pull origin >/dev/null 2>&1
if ref_exists "$B" "refs/issues/$id1"; then got1=yes; else got1=no; fi
if ref_exists "$B" "refs/issues/$id2"; then got2=yes; else got2=no; fi
tap_assert "test \"$got1\" = 'yes'" "pull * imports surviving issue id1"
tap_assert "test \"$got2\" = 'no'" "pull * does not resurrect deleted issue id2"
if ref_exists "$B" "refs/remote-issues/$id2"; then stale2=yes; else stale2=no; fi
tap_assert "test \"$stale2\" = 'no'" "fetch * prunes stale remote-issues ref for id2"

tap_done
