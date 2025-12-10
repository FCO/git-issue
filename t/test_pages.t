#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

tap_start

path_add_project
REPO=$(with_repo)
cd "$REPO"
export EDITOR=true; export VISUAL=true

id1=$(git issue new "Web Test" | tail -1)
reply_id=$(git issue reply "$id1" | tail -1)

"$PROJECT_DIR/git-issue-generate-page" > /dev/null

tap_assert "test -f \"$PROJECT_DIR/docs/index.html\"" "index.html exists in docs"
abb=$(git -C "$REPO" log --pretty=format:%h "$id1" | tail -1)
tap_assert "test -f \"$PROJECT_DIR/docs/issues/$abb.html\"" "issue page exists"

index_html=$(cat "$PROJECT_DIR/docs/index.html")
issue_html=$(cat "$PROJECT_DIR/docs/issues/$abb.html")
tap_assert "echo \"$index_html\" | grep -F 'Issues'" "index has title"
tap_assert "echo \"$issue_html\" | grep -F 'Opened by'" "issue page shows opener"
tap_assert "echo \"$issue_html\" | grep -F 'Messages'" "issue page shows messages section"

tap_done
