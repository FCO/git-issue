#!/usr/bin/env bash
set -euo pipefail

# TAP helpers for prove (MAP/TAP protocol)
ASSERT_COUNT=0
TAP_VERSION_PRINTED=0

tap_start() {
  if [ "$TAP_VERSION_PRINTED" -eq 0 ]; then
    echo "TAP version 13"
    TAP_VERSION_PRINTED=1
  fi
}

tap_assert() {
  local expr="$1"; shift
  local msg="$*"
  ASSERT_COUNT=$((ASSERT_COUNT+1))
  if eval "$expr"; then
    echo "ok $ASSERT_COUNT - $msg"
  else
    echo "not ok $ASSERT_COUNT - $msg"
  fi
  return 0
}

tap_done() {
  echo "1..$ASSERT_COUNT"
}

# Determine project root (parent of tests directory)
PROJECT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

mkrepo() {
  REPO_DIR=$(mktemp -d)
  git -C "$REPO_DIR" init -q
  git -C "$REPO_DIR" config user.name tester
  git -C "$REPO_DIR" config user.email tester@example.com
  echo "$REPO_DIR"
}

with_repo() {
  local dir; dir=$(mkrepo)
  echo "$dir"
}

path_add_project() {
  export PATH="$PROJECT_DIR:$PATH"
}

issue_tip() {
  local dir="$1"; local id="$2"
  git -C "$dir" show-ref --verify --hash "refs/issues/$id"
}

ref_exists() {
  local dir="$1"; local ref="$2"
  git -C "$dir" show-ref --verify --quiet "$ref"
}

blob_content() {
  local dir="$1"; local ref="$2"
  git -C "$dir" show "$ref"
}

msgs_count() {
  local dir="$1"; local id="$2"
  git -C "$dir" ls-tree --name-only "refs/issues/$id" msgs/ | wc -l | tr -d ' '
}

# Resolve a (possibly short) issue id to the full ref-name hash.
resolve_id() {
  local dir="$1"; local id="$2"
  git -C "$dir" log --pretty=format:%H "$id" 2>/dev/null | tail -1 || echo "$id"
}

# Create an issue and return its FULL id (the ref name). `git issue new`
# prints the short hash, so resolve it back to the full hash here.
new_issue() {
  local dir="$1"; shift
  local short
  short=$(git -C "$dir" issue new "$@" | tail -1)
  resolve_id "$dir" "$short"
}
