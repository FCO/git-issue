#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

tap_start

path_add_project
REPO=$(with_repo)
cd "$REPO"
export EDITOR=true; export VISUAL=true

id1=$(git issue new "One" | tail -1)
id2=$(git issue new "Two" | tail -1)

out=$(git issue ls | tr -d '\r')
tap_assert "echo \"$out\" | grep -E '^[0-9a-f]{7,} - One'" "ls shows short hash and title"
tap_assert "echo \"$out\" | grep -E '^[0-9a-f]{7,} - Two'" "ls shows both issues"

show_out=$(git issue show "$id1")
tap_assert "echo \"$show_out\" | head -1 | grep -E '^[0-9a-f]{7,} - One'" "show header abb - title"

# Non-fatal informational note if authors aren't matched
if ! echo "$show_out" | grep -E '\) .+:' > /dev/null; then
  echo "# note: show output did not include author lines in expected format"
fi

tap_done
