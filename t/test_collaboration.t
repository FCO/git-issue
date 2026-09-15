#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

# Collaboration test: two users ("alice" and "bob") share a single bare
# "origin" repository and converge on the same issues via pull/show/edit/push.
# All scenarios are local (no network) and deterministic.
tap_start

path_add_project
export EDITOR=true VISUAL=true

CLEANUP_DIRS=()
cleanup() { rm -rf "${CLEANUP_DIRS[@]}" 2>/dev/null || true; }
trap cleanup EXIT

# A bare repo acting as the shared "origin".
mkbare() {
  local dir; dir=$(mktemp -d)
  CLEANUP_DIRS+=("$dir")
  git -C "$dir" init -q --bare
  echo "$dir"
}

# A working clone with a named identity and "origin" pointing at the bare repo.
mkclone() {
  local remote="$1" name="$2" email="$3"
  local dir; dir=$(mktemp -d)
  CLEANUP_DIRS+=("$dir")
  git -C "$dir" init -q
  git -C "$dir" config user.name "$name"
  git -C "$dir" config user.email "$email"
  git -C "$dir" remote add origin "$remote"
  echo "$dir"
}

# Generate an EDITOR script that appends $1 (plus newline) to the file it edits.
mk_editor() {
  local text="$1"
  local script; script=$(mktemp)
  CLEANUP_DIRS+=("$script")
  cat > "$script" <<EOF
#!/bin/sh
printf '%s\n' "$text" >> "\$1"
EOF
  chmod +x "$script"
  echo "$script"
}

# Concatenated contents of every message under refs/issues/<id>/msgs.
msgs_text() {
  local dir="$1" id="$2"
  git -C "$dir" ls-tree --name-only "refs/issues/$id" msgs/ | while read -r p; do
    git -C "$dir" show "refs/issues/$id:$p"
  done
}

# The title blob of an issue.
title_of() {
  git -C "$1" show "refs/issues/$2:title"
}

# ---------------------------------------------------------------------------
# Scenario A — sequential collaboration (happy path, no conflict)
# ---------------------------------------------------------------------------
REMOTE=$(mkbare)
A=$(mkclone "$REMOTE" alice alice@example.com)
B=$(mkclone "$REMOTE" bob bob@example.com)
EDITOR_ALICE=$(mk_editor "alice-reply")
EDITOR_BOB=$(mk_editor "bob-reply")

# Alice creates an issue and pushes it to the shared origin.
id=$(new_issue "$A" "Sequential feature")
git -C "$A" issue push origin "$id" >/dev/null 2>&1
tap_assert "ref_exists '$REMOTE' 'refs/issues/$id'" "A: new issue reached origin"

# Bob pulls, views it (renders), edits it (reply) and pushes.
git -C "$B" issue pull origin "$id" >/dev/null 2>&1
tap_assert "test \"\$(title_of '$B' '$id')\" = 'Sequential feature'" "B: pulled title matches"
show_out=$(git -C "$B" issue show "$id" 2>&1)
tap_assert "echo \"$show_out\" | grep -q 'Sequential feature'" "B: show renders the issue"

EDITOR="$EDITOR_BOB" git -C "$B" issue reply "$id" >/dev/null 2>&1
tap_assert "test \"\$(msgs_count '$B' '$id')\" = '2'" "B: reply added a second message"
git -C "$B" issue push origin "$id" >/dev/null 2>&1

# Alice pulls, sees Bob's change, makes her own edit and pushes.
git -C "$A" issue pull origin "$id" >/dev/null 2>&1
tap_assert "test \"\$(msgs_count '$A' '$id')\" = '2'" "A: sees Bob's reply after pull"
tap_assert "echo \"\$(msgs_text '$A' '$id')\" | grep -q 'bob-reply'" "A: Bob's reply content present"

EDITOR="$EDITOR_ALICE" git -C "$A" issue reply "$id" >/dev/null 2>&1
git -C "$A" issue push origin "$id" >/dev/null 2>&1

# Bob pulls again and verifies convergence: union of messages, same title.
git -C "$B" issue pull origin "$id" >/dev/null 2>&1
tap_assert "test \"\$(msgs_count '$B' '$id')\" = '3'" "B: sees union of 3 messages"
tap_assert "echo \"\$(msgs_text '$B' '$id')\" | grep -q 'bob-reply'" "B: Bob's reply still present"
tap_assert "echo \"\$(msgs_text '$B' '$id')\" | grep -q 'alice-reply'" "B: Alice's reply present"
tap_assert "test \"\$(title_of '$B' '$id')\" = 'Sequential feature'" "B: title unchanged through the round trip"

# After sync, A, B and origin all point at the same tip.
git -C "$A" issue sync origin "$id" >/dev/null 2>&1
git -C "$B" issue sync origin "$id" >/dev/null 2>&1
a_tip=$(issue_tip "$A" "$id")
b_tip=$(issue_tip "$B" "$id")
o_tip=$(issue_tip "$REMOTE" "$id")
tap_assert "test \"$a_tip\" = \"$b_tip\" && test \"$b_tip\" = \"$o_tip\"" "A/B/origin converge to the same tip"

# ---------------------------------------------------------------------------
# Scenario B1 — parallel replies (divergent, clean union merge)
# ---------------------------------------------------------------------------
REMOTE=$(mkbare)
A=$(mkclone "$REMOTE" alice alice@example.com)
B=$(mkclone "$REMOTE" bob bob@example.com)
EDITOR_ALICE=$(mk_editor "alice-parallel-reply")
EDITOR_BOB=$(mk_editor "bob-parallel-reply")

id=$(new_issue "$A" "Parallel replies")
git -C "$A" issue push origin "$id" >/dev/null 2>&1
git -C "$B" issue pull origin "$id" >/dev/null 2>&1

# Both reply independently, without pulling each other first (simultaneous work).
EDITOR="$EDITOR_ALICE" git -C "$A" issue reply "$id" >/dev/null 2>&1
EDITOR="$EDITOR_BOB" git -C "$B" issue reply "$id" >/dev/null 2>&1
tap_assert "test \"\$(msgs_count '$A' '$id')\" = '2'" "B1: A has 2 messages before push"
tap_assert "test \"\$(msgs_count '$B' '$id')\" = '2'" "B1: B has 2 messages before push"

# A fast-forwards; B is rejected then auto-pulls and merges the divergent trees.
git -C "$A" issue push origin "$id" >/dev/null 2>&1
git -C "$B" issue push origin "$id" >/dev/null 2>&1

tap_assert "test \"\$(msgs_count '$B' '$id')\" = '3'" "B1: union of 3 messages (no clobber)"
tap_assert "echo \"\$(msgs_text '$B' '$id')\" | grep -q 'alice-parallel-reply'" "B1: Alice's reply present"
tap_assert "echo \"\$(msgs_text '$B' '$id')\" | grep -q 'bob-parallel-reply'" "B1: Bob's reply present"

parent_words=$(git -C "$B" rev-list --parents -n 1 "refs/issues/$id" | wc -w | tr -d ' ')
tap_assert "test \"$parent_words\" = '3'" "B1: two-parent merge commit produced"

# A pulls and both sync to a consistent state.
git -C "$A" issue pull origin "$id" >/dev/null 2>&1
tap_assert "test \"\$(msgs_count '$A' '$id')\" = '3'" "B1: A sees the union after pull"
git -C "$A" issue sync origin "$id" >/dev/null 2>&1
git -C "$B" issue sync origin "$id" >/dev/null 2>&1
a_tip=$(issue_tip "$A" "$id")
b_tip=$(issue_tip "$B" "$id")
o_tip=$(issue_tip "$REMOTE" "$id")
tap_assert "test \"$a_tip\" = \"$b_tip\" && test \"$b_tip\" = \"$o_tip\"" "B1: A/B/origin converge to the same tip"

# ---------------------------------------------------------------------------
# Scenario B2 — concurrent edit-title (content conflict, manageable)
# ---------------------------------------------------------------------------
REMOTE=$(mkbare)
A=$(mkclone "$REMOTE" alice alice@example.com)
B=$(mkclone "$REMOTE" bob bob@example.com)
EDITOR_ALICE=$(mk_editor " [alice]")
EDITOR_BOB=$(mk_editor " [bob]")

id=$(new_issue "$A" "Title conflict")
git -C "$A" issue push origin "$id" >/dev/null 2>&1
git -C "$B" issue pull origin "$id" >/dev/null 2>&1

# Both edit the title concurrently (diverge from the shared base).
EDITOR="$EDITOR_ALICE" git -C "$A" issue edit-title "$id" >/dev/null 2>&1
EDITOR="$EDITOR_BOB" git -C "$B" issue edit-title "$id" >/dev/null 2>&1
tap_assert "test \"\$(title_of '$A' '$id')\" = 'Title conflict [alice]'" "B2: Alice edited the title"
tap_assert "test \"\$(title_of '$B' '$id')\" = 'Title conflict [bob]'" "B2: Bob edited the title"

# Alice pushes first (fast-forward); Bob's push is rejected.
git -C "$A" issue push origin "$id" >/dev/null 2>&1

if push_out=$(git -C "$B" issue push origin "$id" 2>&1); then
  push_rc=0
else
  push_rc=$?
fi

tap_assert "echo \"$push_out\" | grep -q 'rejected'" "B2: Bob's push was rejected"
tap_assert "echo \"$push_out\" | grep -q 'CONFLICT'" "B2: title conflict was detected"

# No data loss and no ref destruction: both titles survive in their own refs.
tap_assert "ref_exists '$B' 'refs/issues/$id'" "B2: Bob's ref still exists"
tap_assert "ref_exists '$REMOTE' 'refs/issues/$id'" "B2: origin ref still exists"
tap_assert "test \"\$(title_of '$B' '$id')\" = 'Title conflict [bob]'" "B2: Bob's title preserved (no clobber)"
tap_assert "test \"\$(title_of '$REMOTE' '$id')\" = 'Title conflict [alice]'" "B2: origin title preserved (no clobber)"

# Honest behavior: the three-way merge detects the conflict but does NOT
# auto-resolve it into a merge commit; the push reports failure and the two
# sides stay inspectably divergent (resolvable by a human, nothing destroyed).
tap_assert "test \"$push_rc\" -ne 0" "B2: push reports failure (conflict not auto-resolved)"
parent_words=$(git -C "$B" rev-list --parents -n 1 "refs/issues/$id" | wc -w | tr -d ' ')
tap_assert "test \"$parent_words\" = '2'" "B2: Bob's tip not merged (single parent, divergence intact)"

tap_done
