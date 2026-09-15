#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

# `show` status filtering: `--all` / `--open` / `--closed` flags select the
# status filter passed to the interactive picker (iss-id). The picker itself
# (fzf / numbered prompt) is not exercised here; instead we pass an explicit
# issue id *alongside* the flag and verify the flag is consumed (not treated
# as the id) and the correct issue is shown. All scenarios are local and
# deterministic.
tap_start

path_add_project
REPO=$(with_repo)
cd "$REPO"
export EDITOR=true VISUAL=true

open_id=$(new_issue . "Open Issue")
closed_id=$(new_issue . "Closed Issue")
git issue close -f "$closed_id" > /dev/null

open_short=$(git -C "$REPO" log --pretty=format:%h "$open_id" | tail -1)
closed_short=$(git -C "$REPO" log --pretty=format:%h "$closed_id" | tail -1)

# --all accepts an explicit id and shows it (open and closed both reachable)
out=$(git issue show --all "$open_id")
tap_assert "echo \"\$out\" | head -1 | grep -E '^'\"$open_short\"' - Open Issue'" "show --all <open-id> shows the open issue"

out=$(git issue show --all "$closed_id")
tap_assert "echo \"\$out\" | head -1 | grep -E '^'\"$closed_short\"' - Closed Issue'" "show --all <closed-id> shows the closed issue"

# --closed consumes the flag and treats the following token as the id
out=$(git issue show --closed "$closed_id")
tap_assert "echo \"\$out\" | head -1 | grep -E '^'\"$closed_short\"' - Closed Issue'" "show --closed <closed-id> shows the closed issue"

# --open consumes the flag and treats the following token as the id
out=$(git issue show --open "$open_id")
tap_assert "echo \"\$out\" | head -1 | grep -E '^'\"$open_short\"' - Open Issue'" "show --open <open-id> shows the open issue"

# The status flag only affects the picker filter; an explicit id is still
# resolved and shown regardless of its status (default `open` is unchanged).
out=$(git issue show "$closed_id")
tap_assert "echo \"\$out\" | head -1 | grep -E '^'\"$closed_short\"' - Closed Issue'" "show <closed-id> (no flag) still resolves the explicit id"

tap_done
