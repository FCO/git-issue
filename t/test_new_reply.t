#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

tap_start

path_add_project
REPO=$(with_repo)
cd "$REPO"

export EDITOR=true
export VISUAL=true
issue_id=$(git issue new "Test issue" | tail -1)

tap_assert "ref_exists '$REPO' 'refs/issues/$issue_id'" "issue ref exists"

tap_assert "test \"\$(blob_content '$REPO' 'refs/issues/'$issue_id':title')\" = 'Test issue'" "title matches"
tap_assert "test \"\$(blob_content '$REPO' 'refs/issues/'$issue_id':status')\" = 'open'" "status open"

first_msg=$(git -C "$REPO" ls-tree --name-only "refs/issues/$issue_id" msgs/ | head -1 | sed 's#msgs/##')
tap_assert "[[ ! \$first_msg =~ ^$issue_id- ]]" "first message is <gen_id>"

reply_id=$(git issue reply "$issue_id" | tail -1)
tap_assert "test \"\$(msgs_count '$REPO' '$issue_id')\" -ge 2" "at least two messages now"
tap_assert "echo \"$reply_id\" | grep -E '^[0-9a-f]{7,}-'" "reply id matches <ISSUE_ID>-<gen_id> pattern"
reply_file=$(git -C "$REPO" ls-tree --name-only "refs/issues/$issue_id" msgs/ | sed 's#msgs/##' | grep -Fx "$reply_id" || true)
tap_assert "test -n \"$reply_file\"" "reply file exists under msgs/ with echoed id"

tap_done
