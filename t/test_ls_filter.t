#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

tap_start

path_add_project
REPO=$(with_repo)
cd "$REPO"
export EDITOR=true; export VISUAL=true

open_id=$(new_issue . "Open Issue")
closed_id=$(new_issue . "Closed Issue")
# close second issue
git issue close -f "$closed_id" > /dev/null

out_open=$(git issue ls open | tr -d '\r' || true)
out_closed=$(git issue ls closed | tr -d '\r' || true)

# open list contains open issue title, not closed
tap_assert "echo \"$out_open\" | grep -E ' - Open Issue'" "ls open shows open issues"
tap_assert "! echo \"$out_open\" | grep -E ' - Closed Issue'" "ls open hides closed issues"

# closed list contains closed issue title, not open
# note: titles are printed regardless of status filter; instead check ID presence
closed_short=$(git -C "$REPO" log --pretty=format:%h "$closed_id" | tail -1)
open_short=$(git -C "$REPO" log --pretty=format:%h "$open_id" | tail -1)
tap_assert "echo \"$out_closed\" | grep -E '^'\"$closed_short\"' '" "ls closed shows closed issue id"
tap_assert "! echo \"$out_closed\" | grep -E '^'\"$open_short\"' '" "ls closed hides open issue id"

# flag-based filtering and default (open only)
out_default=$(git issue ls | tr -d '\r' || true)
out_all=$(git issue ls --all | tr -d '\r' || true)
out_flag_closed=$(git issue ls --closed | tr -d '\r' || true)
out_flag_open=$(git issue ls --open | tr -d '\r' || true)

tap_assert "echo \"$out_default\" | grep -E ' - Open Issue'" "ls (default) shows open issues"
tap_assert "! echo \"$out_default\" | grep -E ' - Closed Issue'" "ls (default) hides closed issues"
tap_assert "echo \"$out_all\" | grep -E ' - Open Issue'" "ls --all shows open issues"
tap_assert "echo \"$out_all\" | grep -E ' - Closed Issue'" "ls --all shows closed issues"
tap_assert "echo \"$out_flag_closed\" | grep -E ' - Closed Issue'" "ls --closed shows closed issues"
tap_assert "! echo \"$out_flag_closed\" | grep -E ' - Open Issue'" "ls --closed hides open issues"
tap_assert "echo \"$out_flag_open\" | grep -E ' - Open Issue'" "ls --open shows open issues"
tap_assert "! echo \"$out_flag_open\" | grep -E ' - Closed Issue'" "ls --open hides closed issues"

tap_done
