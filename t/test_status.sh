#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

tap_start

path_add_project
REPO=$(with_repo)
cd "$REPO"
export EDITOR=true; export VISUAL=true

issue_id=$(git issue new "Status Test" | tail -1)

closed_id=$(git issue close "$issue_id" | tail -1)
tap_assert "test \"$closed_id\" = \"$issue_id\"" "close returns same issue id"
tap_assert "test \"\$(blob_content '$REPO' 'refs/issues/'$issue_id':status')\" = 'closed'" "status closed"

reopen_id=$(git issue reopen "$issue_id" | tail -1)
tap_assert "test \"$reopen_id\" = \"$issue_id\"" "reopen returns same issue id"
tap_assert "test \"\$(blob_content '$REPO' 'refs/issues/'$issue_id':status')\" = 'open'" "status open again"

tap_done
