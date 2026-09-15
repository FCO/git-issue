#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

# UX features: help/unknown-command dispatch, `new -m`, `status` (arbitrary
# status), and `ls --porcelain`.
tap_start

path_add_project
REPO=$(with_repo)
cd "$REPO"
export EDITOR=true VISUAL=true

# --- help & dispatch ---------------------------------------------------------
rc=0; git issue help >/dev/null 2>&1 || rc=$?
tap_assert "test \"$rc\" -eq 0" "help exits 0"

rc=0; git issue >/dev/null 2>&1 || rc=$?
tap_assert "test \"$rc\" -eq 0" "bare git issue exits 0"

help_file=$(mktemp)
git issue help > "$help_file" 2>&1
tap_assert "grep -q 'status' '$help_file'" "help lists status command"
tap_assert "grep -q 'new \\[-m' '$help_file'" "help lists new command"

rc=0; git issue no-such-cmd >/dev/null 2>&1 || rc=$?
tap_assert "test \"$rc\" -eq 2" "unknown command exits 2"

rc=0; git issue show-messages "" >/dev/null 2>&1 || rc=$?
tap_assert "test \"$rc\" -eq 0" "show-messages with empty id is a no-op"

# --- new -m ----------------------------------------------------------------
short=$(git issue new -m "hello body" "Ux Title" | tail -1)
full=$(git -C "$REPO" rev-parse "$short")
tap_assert "test \"$short\" != \"$full\"" "new prints short hash (not full)"
tap_assert "ref_exists '$REPO' 'refs/issues/$full'" "issue ref exists under full hash"
tap_assert "test \"\$(blob_content '$REPO' 'refs/issues/'$full':title')\" = 'Ux Title'" "new -m sets title"
first_msg=$(git -C "$REPO" ls-tree --name-only "refs/issues/$full" msgs/ | head -1)
tap_assert "test \"\$(git -C '$REPO' show 'refs/issues/'$full':$first_msg')\" = 'hello body'" "new -m sets first message"

# --- status (arbitrary status) ----------------------------------------------
git issue status "$short" "in-progress" >/dev/null 2>&1
tap_assert "test \"\$(blob_content '$REPO' 'refs/issues/'$full':status')\" = 'in-progress'" "status sets arbitrary value"

# --- ls --porcelain ----------------------------------------------------------
porc=$(git issue ls --porcelain --all | tr -d '\r' || true)
tap_assert "echo \"$porc\" | grep -qE '^'\"$full\"'\|in-progress\|Ux Title\|0$'" "porcelain format full|status|title|priority"

porc_open=$(git issue ls --porcelain | tr -d '\r' || true)
tap_assert "! echo \"$porc_open\" | grep -q 'Ux Title'" "porcelain default hides non-open"

tap_done
