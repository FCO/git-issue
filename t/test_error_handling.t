#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

# Error-handling / clean-output regressions:
#   - show-messages must not emit ANSI escapes when piped (bat is gated on a tty).
#   - new -m with a missing argument must fail cleanly instead of looping.
#   - new with an empty (EOF) title must fail instead of creating an empty issue.
#   - edit-title / edit-msg with an invalid id must die cleanly (no git "fatal:").
#   - edit-msg with a non-numeric / out-of-range message number must die cleanly.
#   - close/reopen accept a short (abbreviated) issue id.
tap_start

path_add_project
export EDITOR=true VISUAL=true

# --- show-messages: clean, non-colored output when piped ---------------------
REPO=$(with_repo)
cd "$REPO"
id=$(new_issue . -m "hello body" "Show Messages")

out=$(git issue show-messages "$id")
tap_assert "echo \"\$out\" | grep -Fq 'hello body'" "show-messages prints the message body"

if echo "$out" | grep -q $'\033'; then has_esc=yes; else has_esc=no; fi
tap_assert "test \"\$has_esc\" = 'no'" "show-messages emits no ANSI escapes when piped"

# --- new -m with a missing argument ------------------------------------------
rc=0; out=$(git issue new -m 2>&1) || rc=$?
tap_assert "test \"\$rc\" -eq 2" "new -m (no argument) exits 2"
tap_assert "echo \"\$out\" | grep -Fq 'requires an argument'" "new -m (no argument) prints a clean error"

# --- new with an empty title --------------------------------------------------
REPO2=$(with_repo)
cd "$REPO2"
before=$(git for-each-ref --format='%(refname)' refs/issues/ | wc -l | tr -d ' ')
rc=0; out=$(printf '\n' | git issue new 2>&1) || rc=$?
after=$(git for-each-ref --format='%(refname)' refs/issues/ | wc -l | tr -d ' ')
tap_assert "test \"\$rc\" -eq 1" "new with empty title exits 1"
tap_assert "echo \"\$out\" | grep -Fq 'Title required'" "new with empty title prints a clean error"
tap_assert "test \"\$before\" = \"\$after\"" "new with empty title creates no issue ref"

# --- edit-title / edit-msg with an invalid id ---------------------------------
rc=0; out=$(git issue edit-title deadbeef 2>&1) || rc=$?
tap_assert "test \"\$rc\" -eq 1" "edit-title invalid id exits 1"
tap_assert "echo \"\$out\" | grep -Fq 'Not a valid issue id'" "edit-title invalid id prints clean error"
tap_assert "! echo \"\$out\" | grep -Fq 'fatal:'" "edit-title invalid id does not leak git fatal output"

rc=0; out=$(git issue edit-msg deadbeef 2>&1) || rc=$?
tap_assert "test \"\$rc\" -eq 1" "edit-msg invalid id exits 1"
tap_assert "echo \"\$out\" | grep -Fq 'Not a valid issue id'" "edit-msg invalid id prints clean error"
tap_assert "! echo \"\$out\" | grep -Fq 'fatal:'" "edit-msg invalid id does not leak git fatal output"

# --- edit-msg with a non-numeric / out-of-range message number -----------------
REPO3=$(with_repo)
cd "$REPO3"
id=$(new_issue . "Edit Msg")

rc=0; out=$(git issue edit-msg "$id" abc 2>&1) || rc=$?
tap_assert "test \"\$rc\" -eq 1" "edit-msg non-numeric message number exits 1"
tap_assert "echo \"\$out\" | grep -Fq 'Message number invalid'" "edit-msg non-numeric prints clean error"
tap_assert "! echo \"\$out\" | grep -Fq 'integer expected'" "edit-msg non-numeric does not leak shell arithmetic error"

rc=0; out=$(git issue edit-msg "$id" 0 2>&1) || rc=$?
tap_assert "test \"\$rc\" -eq 1" "edit-msg message number 0 exits 1"
tap_assert "echo \"\$out\" | grep -Fq 'Message number invalid'" "edit-msg message number 0 prints clean error"

# --- close/reopen accept a short hash id --------------------------------------
id=$(new_issue . "Short Hash Flow")
short=$(git rev-parse --short "$id")
closed=$(git issue close -f "$short" 2>/dev/null | tail -1)
tap_assert "test \"\$closed\" = \"\$id\"" "close -f accepts a short hash id"
tap_assert "test \"\$(blob_content '$REPO3' 'refs/issues/$id:status')\" = 'closed'" "close short id sets status closed"

reopened=$(git issue reopen -f "$short" 2>/dev/null | tail -1)
tap_assert "test \"\$reopened\" = \"\$id\"" "reopen -f accepts a short hash id"
tap_assert "test \"\$(blob_content '$REPO3' 'refs/issues/$id:status')\" = 'open'" "reopen short id sets status open"

tap_done
