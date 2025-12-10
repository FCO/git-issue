#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

tap_start

path_add_project
REPO=$(with_repo)
cd "$REPO"
export EDITOR=true; export VISUAL=true

issue_id=$(git issue new "Initial" | tail -1)

# Edit title content changed
git issue edit-title "$issue_id" > /dev/null
new_title=$(git -C "$REPO" show "refs/issues/$issue_id:title")
tap_assert "test -n \"$new_title\"" "title exists after edit"

# Add a reply and then edit that reply content
reply_id=$(git issue reply "$issue_id" | tail -1)
# Ensure file exists
reply_file=$(git -C "$REPO" ls-tree --name-only "refs/issues/$issue_id" msgs/ | sed 's#msgs/##' | grep -Fx "$reply_id" || true)
tap_assert "test -n \"$reply_file\"" "reply file exists"
# Edit msg number: last one
msg_count=$(msgs_count "$REPO" "$issue_id")
git issue edit-msg "$issue_id" "$msg_count" > /dev/null
# Check id preserved
after_last=$(git -C "$REPO" ls-tree --name-only "refs/issues/$issue_id" msgs/ | sed 's#msgs/##' | tail -1)
tap_assert "test \"$after_last\" = \"$reply_id\"" "edited reply id preserved"

tap_done
