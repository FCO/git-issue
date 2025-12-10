#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

tap_start

path_add_project
REPO=$(with_repo)
cd "$REPO"
export EDITOR=true; export VISUAL=true

issue_id=$(git issue new "Status Flow" | tail -1)

# Close and verify status
closed_id=$(git issue close "$issue_id" | tail -1)
tap_assert "test \"$closed_id\" = \"$issue_id\"" "close returns same id"
tap_assert "test \"\$(blob_content '$REPO' 'refs/issues/'$issue_id':status')\" = 'closed'" "status closed"

# ls closed shows it
out_closed=$(git issue ls closed | tr -d '\r')
tap_assert "echo \"$out_closed\" | grep -E '^[0-9a-f]{7,} - Status Flow'" "closed issue listed in ls closed"

# Reopen and verify status
reopen_id=$(git issue reopen "$issue_id" | tail -1)
tap_assert "test \"$reopen_id\" = \"$issue_id\"" "reopen returns same id"
tap_assert "test \"\$(blob_content '$REPO' 'refs/issues/'$issue_id':status')\" = 'open'" "status open"

# ls open lists it again
out_open=$(git issue ls open | tr -d '\r')
tap_assert "echo \"$out_open\" | grep -E '^[0-9a-f]{7,} - Status Flow'" "reopened issue listed in ls open"

tap_done
