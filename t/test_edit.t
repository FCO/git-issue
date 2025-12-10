#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

tap_start

path_add_project
REPO=$(with_repo)
cd "$REPO"
export EDITOR=true; export VISUAL=true

issue_id=$(git issue new "Title A" | tail -1)
orig_tip=$(issue_tip "$REPO" "$issue_id")

git issue edit-title "$issue_id" > /dev/null
new_tip=$(issue_tip "$REPO" "$issue_id")
tap_assert "test \"$orig_tip\" != \"$new_tip\"" "tip advanced after edit-title"

msg_count=$(msgs_count "$REPO" "$issue_id")
tap_assert "test \"$msg_count\" -ge 1" "has at least one message"
msg_id_before=$(git -C "$REPO" ls-tree --name-only "refs/issues/$issue_id" msgs/ | sed 's#msgs/##' | head -1)

git issue edit-msg "$issue_id" 1 > /dev/null
msg_id_after=$(git -C "$REPO" ls-tree --name-only "refs/issues/$issue_id" msgs/ | sed 's#msgs/##' | head -1)
tap_assert "test \"$msg_id_before\" = \"$msg_id_after\"" "message id preserved after edit-msg"

tap_done
