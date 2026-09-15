#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

# `git issue config`: list / get / set / unset, backed by refs/issue-config.
tap_start

path_add_project
REPO=$(with_repo)
cd "$REPO"
export EDITOR=true VISUAL=true

# --- empty: list and get both print nothing, exit 0 -------------------------
rc=0; out=$(git issue config 2>&1) || rc=$?
tap_assert "test \"\$rc\" -eq 0" "config (list, empty) exits 0"
tap_assert "test -z \"\$out\"" "config (list, empty) prints nothing"

rc=0; out=$(git issue config sort 2>&1) || rc=$?
tap_assert "test \"\$rc\" -eq 0" "config <key> (unset) exits 0"
tap_assert "test -z \"\$out\"" "config <key> (unset) prints nothing"

# --- set then get ------------------------------------------------------------
git issue config sort priority
tap_assert "test \"\$(git issue config sort)\" = 'priority'" "config set + get round-trips value"
tap_assert "ref_exists '$REPO' 'refs/issue-config'" "config set creates refs/issue-config ref"

# --- set a second key and list (sorted) --------------------------------------
git issue config theme dark
out=$(git issue config)
tap_assert "test \"\$(echo \"\$out\" | grep -Fx 'sort = priority')\" = 'sort = priority'" "config list shows sort key"
tap_assert "test \"\$(echo \"\$out\" | grep -Fx 'theme = dark')\" = 'theme = dark'" "config list shows theme key"
tap_assert "echo \"\$out\" | head -1 | grep -q 'sort'" "config list is sorted (sort before theme)"

# --- overwrite an existing key ------------------------------------------------
git issue config sort date
tap_assert "test \"\$(git issue config sort)\" = 'date'" "config set overwrites existing key"

# --- unset removes only the target key ----------------------------------------
git issue config --unset theme
tap_assert "test -z \"\$(git issue config theme)\"" "config --unset removes the key"
tap_assert "test \"\$(git issue config sort)\" = 'date'" "config --unset leaves other keys intact"

# --- unset the last key deletes the ref ---------------------------------------
git issue config --unset sort
tap_assert "! ref_exists '$REPO' 'refs/issue-config'" "config --unset of last key deletes refs/issue-config"

# --- set a key with a multi-word-ish value is taken literally -----------------
git issue config note "hello world"
tap_assert "test \"\$(git issue config note)\" = 'hello world'" "config set stores the value verbatim"

tap_done
