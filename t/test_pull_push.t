#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

# Tests for the share/import/export commands: push, pull, fetch, sync.
# All scenarios use a local bare repo as the "remote" (no network).
tap_start

path_add_project
export EDITOR=true VISUAL=true

CLEANUP_DIRS=()
cleanup() { rm -rf "${CLEANUP_DIRS[@]}" 2>/dev/null || true; }
trap cleanup EXIT

# Create a bare "remote" repo in a temp dir
mkbare() {
  local dir; dir=$(mktemp -d)
  CLEANUP_DIRS+=("$dir")
  git -C "$dir" init -q --bare
  echo "$dir"
}

# Create a non-bare repo with the given bare repo as its "origin"
mkclone() {
  local remote="$1"
  local dir; dir=$(mkrepo)
  CLEANUP_DIRS+=("$dir")
  git -C "$dir" remote add origin "$remote"
  echo "$dir"
}

# ---------------------------------------------------------------
# 1) push a new issue to a bare remote; fetch + pull into a second repo
# ---------------------------------------------------------------
REMOTE=$(mkbare)
A=$(mkclone "$REMOTE")
B=$(mkclone "$REMOTE")

id=$(new_issue "$A" "Shared issue")

tap_assert "ref_exists '$A' 'refs/issues/$id'" "new issue ref exists locally"

git -C "$A" issue push origin "$id" >/dev/null 2>&1
tap_assert "ref_exists '$REMOTE' 'refs/issues/$id'" "remote ref exists after push"
tap_assert "test \"\$(git -C '$REMOTE' show-ref --verify --hash 'refs/issues/$id')\" = \"\$(git -C '$A' show-ref --verify --hash 'refs/issues/$id')\"" "remote tip matches local tip"

# fetch populates refs/remote-issues/<id> but does not import into refs/issues
git -C "$B" issue fetch origin "$id" >/dev/null 2>&1
tap_assert "ref_exists '$B' 'refs/remote-issues/$id'" "fetch populates refs/remote-issues/<id>"
if ref_exists "$B" "refs/issues/$id"; then imported_before=yes; else imported_before=no; fi
tap_assert "test \"$imported_before\" = 'no'" "fetch alone does not import into refs/issues"

# pull imports the brand-new issue
git -C "$B" issue pull origin "$id" >/dev/null 2>&1
tap_assert "ref_exists '$B' 'refs/issues/$id'" "pull imports new issue into refs/issues"
pulled_title=$(git -C "$B" show "refs/issues/$id:title")
pulled_status=$(git -C "$B" show "refs/issues/$id:status")
tap_assert "test \"$pulled_title\" = 'Shared issue'" "pulled title matches"
tap_assert "test \"$pulled_status\" = 'open'" "pulled status is open"

# ---------------------------------------------------------------
# 2) divergent merge: both repos reply, pull merges to union; re-pull idempotent
# ---------------------------------------------------------------
REMOTE=$(mkbare)
A=$(mkclone "$REMOTE")
B=$(mkclone "$REMOTE")

id=$(new_issue "$A" "Divergent")
git -C "$A" issue push origin "$id" >/dev/null 2>&1
git -C "$B" issue pull origin "$id" >/dev/null 2>&1

# both repos reply independently (diverge from the shared base)
git -C "$A" issue reply "$id" >/dev/null 2>&1
git -C "$B" issue reply "$id" >/dev/null 2>&1

tap_assert "test \"\$(msgs_count '$A' '$id')\" = '2'" "A has 2 messages after reply"
tap_assert "test \"\$(msgs_count '$B' '$id')\" = '2'" "B has 2 messages after reply"

# A pushes its reply; B pulls and three-way-merges the divergent trees
git -C "$A" issue push origin "$id" >/dev/null 2>&1
git -C "$B" issue pull origin "$id" >/dev/null 2>&1
tap_assert "test \"\$(msgs_count '$B' '$id')\" = '3'" "pull merges divergent replies into 3 messages"

parent_words=$(git -C "$B" rev-list --parents -n 1 "refs/issues/$id" | wc -w | tr -d ' ')
tap_assert "test \"$parent_words\" = '3'" "pull created a two-parent merge commit"

before=$(git -C "$B" show-ref --verify --hash "refs/issues/$id")
git -C "$B" issue pull origin "$id" >/dev/null 2>&1
after=$(git -C "$B" show-ref --verify --hash "refs/issues/$id")
tap_assert "test \"$before\" = \"$after\"" "re-pull is idempotent"

# ---------------------------------------------------------------
# 3) push auto-retry on rejection
# ---------------------------------------------------------------
REMOTE=$(mkbare)
A=$(mkclone "$REMOTE")
B=$(mkclone "$REMOTE")

id=$(new_issue "$A" "Retry")
git -C "$A" issue push origin "$id" >/dev/null 2>&1
git -C "$B" issue pull origin "$id" >/dev/null 2>&1

# both reply; B pushes first, then A pushes and must auto-pull + retry
git -C "$A" issue reply "$id" >/dev/null 2>&1
git -C "$B" issue reply "$id" >/dev/null 2>&1
git -C "$B" issue push origin "$id" >/dev/null 2>&1

push_out=$(DEBUG=1 git -C "$A" issue push origin "$id" 2>&1 || true)
if echo "$push_out" | grep -q 'rejected'; then was_rejected=yes; else was_rejected=no; fi
tap_assert "test \"$was_rejected\" = 'yes'" "A push was rejected on first attempt"

a_tip=$(git -C "$A" show-ref --verify --hash "refs/issues/$id")
remote_tip=$(git -C "$REMOTE" show-ref --verify --hash "refs/issues/$id")
tap_assert "test \"$a_tip\" = \"$remote_tip\"" "A converges with remote after auto-retry"
tap_assert "test \"\$(msgs_count '$REMOTE' '$id')\" = '3'" "remote holds the union of 3 messages"

# ---------------------------------------------------------------
# 4) sync (pull; push; pull) round-trips converge
# ---------------------------------------------------------------
REMOTE=$(mkbare)
A=$(mkclone "$REMOTE")
B=$(mkclone "$REMOTE")

id=$(new_issue "$A" "Sync")
git -C "$A" issue sync origin "$id" >/dev/null 2>&1
tap_assert "ref_exists '$REMOTE' 'refs/issues/$id'" "sync pushes new issue to remote"

git -C "$B" issue sync origin "$id" >/dev/null 2>&1
tap_assert "ref_exists '$B' 'refs/issues/$id'" "sync pulls issue into second repo"

# B replies and syncs; A syncs to converge
git -C "$B" issue reply "$id" >/dev/null 2>&1
git -C "$B" issue sync origin "$id" >/dev/null 2>&1
git -C "$A" issue sync origin "$id" >/dev/null 2>&1

a_tip=$(git -C "$A" show-ref --verify --hash "refs/issues/$id")
remote_tip=$(git -C "$REMOTE" show-ref --verify --hash "refs/issues/$id")
tap_assert "test \"$a_tip\" = \"$remote_tip\"" "sync round-trip converges A and remote"
tap_assert "test \"\$(msgs_count '$A' '$id')\" = '2'" "A sees the synced reply"

# ---------------------------------------------------------------
# 5) fetch with default wildcard ('*') populates all remote-issues refs
# ---------------------------------------------------------------
REMOTE=$(mkbare)
A=$(mkclone "$REMOTE")
B=$(mkclone "$REMOTE")

id1=$(new_issue "$A" "Wild one")
id2=$(new_issue "$A" "Wild two")
git -C "$A" issue push origin >/dev/null 2>&1   # push all issues (default *)

git -C "$B" issue fetch origin >/dev/null 2>&1  # fetch all issues (default *)
tap_assert "ref_exists '$B' 'refs/remote-issues/$id1'" "wildcard fetch populates remote-issues for id1"
tap_assert "ref_exists '$B' 'refs/remote-issues/$id2'" "wildcard fetch populates remote-issues for id2"

tap_done
