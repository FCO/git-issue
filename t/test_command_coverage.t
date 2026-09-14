#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

# Command-coverage gap fillers.
#
# The dispatcher exposes 12 user-facing commands plus the standalone
# `git-issue-generate-page`. Most are covered, but a few only have "thin"
# coverage that asserts side effects rather than the user-visible behavior:
#   - edit-title is asserted to advance the tip / keep a title present, but
#     not that the *content* actually changed.
#   - edit-msg is asserted to preserve a message id, but not that the
#     *specific* message selected by number changed while others stay put.
#   - show is asserted only for its header line, not the full message body.
#   - fetch is asserted for ref existence, but not that the fetched ref points
#     at the remote sha (standalone, independent of pull).
#   - generate-page is asserted to produce files + a couple of headings, but
#     not that the key fields (escaped title, message bodies, status,
#     permalinks) are emitted into the HTML.
#
# This file closes those gaps. All scenarios are local (no network) and use a
# deterministic EDITOR that overwrites the file (EDITOR=true is a no-op and
# cannot prove content changed).
tap_start

path_add_project
export EDITOR=true VISUAL=true

CLEANUP_DIRS=()
cleanup() { rm -rf "${CLEANUP_DIRS[@]}" 2>/dev/null || true; }
trap cleanup EXIT

# Create an EDITOR that overwrites the target file with a fixed string, so the
# edited content is deterministic.
mk_editor_overwrite() {
  local text="$1"
  local script; script=$(mktemp)
  CLEANUP_DIRS+=("$script")
  cat > "$script" <<EOF
#!/bin/sh
printf '%s\n' "$text" > "\$1"
EOF
  chmod +x "$script"
  echo "$script"
}

mkbare() {
  local dir; dir=$(mktemp -d)
  CLEANUP_DIRS+=("$dir")
  git -C "$dir" init -q --bare
  echo "$dir"
}

mkclone() {
  local remote="$1"
  local dir; dir=$(with_repo)
  CLEANUP_DIRS+=("$dir")
  git -C "$dir" remote add origin "$remote"
  echo "$dir"
}

# ---------------------------------------------------------------------------
# edit-title: title content actually changes
# ---------------------------------------------------------------------------
REPO=$(with_repo)
CLEANUP_DIRS+=("$REPO")
cd "$REPO"

id=$(git issue new "Original title" | tail -1)
tap_assert "test \"\$(git -C '$REPO' show 'refs/issues/$id:title')\" = 'Original title'" "edit-title: title created with expected content"

ED=$(mk_editor_overwrite "Renamed title")
EDITOR="$ED" git issue edit-title "$id" >/dev/null
tap_assert "test \"\$(git -C '$REPO' show 'refs/issues/$id:title')\" = 'Renamed title'" "edit-title: title content changed"

# ---------------------------------------------------------------------------
# edit-msg: the message selected by number changes, the other stays, ids kept
# ---------------------------------------------------------------------------
REPO=$(with_repo)
CLEANUP_DIRS+=("$REPO")
cd "$REPO"

ED=$(mk_editor_overwrite "first body")
id=$(EDITOR="$ED" git issue new "Two messages" | tail -1)

ED=$(mk_editor_overwrite "second body")
EDITOR="$ED" git issue reply "$id" >/dev/null

tap_assert "test \"\$(msgs_count '$REPO' '$id')\" = '2'" "edit-msg: issue has two messages"

p1=$(git -C "$REPO" ls-tree --name-only "refs/issues/$id" msgs/ | sed -n '1p')
p2=$(git -C "$REPO" ls-tree --name-only "refs/issues/$id" msgs/ | sed -n '2p')
paths_before=$(git -C "$REPO" ls-tree --name-only "refs/issues/$id" msgs/ | sort)
c1_before=$(git -C "$REPO" show "refs/issues/$id:$p1")

ED=$(mk_editor_overwrite "second body EDITED")
EDITOR="$ED" git issue edit-msg "$id" 2 >/dev/null

paths_after=$(git -C "$REPO" ls-tree --name-only "refs/issues/$id" msgs/ | sort)
c1_after=$(git -C "$REPO" show "refs/issues/$id:$p1")
c2_after=$(git -C "$REPO" show "refs/issues/$id:$p2")

tap_assert "test \"\$c2_after\" = 'second body EDITED'" "edit-msg: selected message (number 2) content changed"
tap_assert "test \"\$c1_after\" = \"\$c1_before\"" "edit-msg: other message content untouched"
tap_assert "test \"\$paths_before\" = \"\$paths_after\"" "edit-msg: message ids (filenames) preserved"

# ---------------------------------------------------------------------------
# show: full message body and author line are printed, not just the header
# ---------------------------------------------------------------------------
REPO=$(with_repo)
CLEANUP_DIRS+=("$REPO")
cd "$REPO"

ED=$(mk_editor_overwrite "the-visible-body")
id=$(EDITOR="$ED" git issue new "Show title" | tail -1)
show_out=$(git issue show "$id")

tap_assert "echo \"\$show_out\" | head -1 | grep -E '^[0-9a-f]{7,} - Show title'" "show: header line has abb - title"
tap_assert "echo \"\$show_out\" | grep -F 'the-visible-body'" "show: prints full message body"
tap_assert "echo \"\$show_out\" | grep -F '1) tester:'" "show: prints the message author line"

# ---------------------------------------------------------------------------
# fetch (standalone): populates refs/remote-issues/* at the remote sha
# ---------------------------------------------------------------------------
REMOTE=$(mkbare)
A=$(mkclone "$REMOTE")
B=$(mkclone "$REMOTE")

id=$(git -C "$A" issue new "Fetched" | tail -1)
git -C "$A" issue push origin "$id" >/dev/null 2>&1
git -C "$B" issue fetch origin "$id" >/dev/null 2>&1

remote_sha=$(git -C "$REMOTE" show-ref --verify --hash "refs/issues/$id")
fetched_sha=$(git -C "$B" show-ref --verify --hash "refs/remote-issues/$id")
tap_assert "ref_exists '$B' 'refs/remote-issues/$id'" "fetch: populates refs/remote-issues/<id>"
tap_assert "test \"\$fetched_sha\" = \"\$remote_sha\"" "fetch: remote-issues ref points at the remote sha"
if ref_exists "$B" "refs/issues/$id"; then imported=yes; else imported=no; fi
tap_assert "test \"\$imported\" = 'no'" "fetch: does not import into refs/issues (standalone)"

# ---------------------------------------------------------------------------
# generate-page: key fields are emitted into the generated HTML
# ---------------------------------------------------------------------------
REPO=$(with_repo)
CLEANUP_DIRS+=("$REPO")
cd "$REPO"

ED=$(mk_editor_overwrite "first page body")
id=$(EDITOR="$ED" git issue new "Escape & Test" | tail -1)

ED=$(mk_editor_overwrite "second page body")
EDITOR="$ED" git issue reply "$id" >/dev/null

"$PROJECT_DIR/git-issue-generate-page" >/dev/null

abb=$(git -C "$REPO" log --pretty=format:%h "$id" | tail -1)
index_html=$(cat "$PROJECT_DIR/docs/index.html")
issue_html=$(cat "$PROJECT_DIR/docs/issues/$abb.html")

tap_assert "echo \"\$index_html\" | grep -F 'Escape &amp; Test'" "generate-page: index escapes and shows the title"
tap_assert "echo \"\$index_html\" | grep -F \"issues/$abb.html\"" "generate-page: index links to the issue page"
tap_assert "echo \"\$issue_html\" | grep -F 'first page body'" "generate-page: issue page contains the first message body"
tap_assert "echo \"\$issue_html\" | grep -F 'second page body'" "generate-page: issue page contains the reply body"
tap_assert "echo \"\$issue_html\" | grep -F 'class=\"status\">open'" "generate-page: issue page shows the open status"
tap_assert "echo \"\$issue_html\" | grep -F 'class=\"permalink\"'" "generate-page: issue page emits message permalinks"

tap_done
