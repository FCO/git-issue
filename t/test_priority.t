#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

# Priority: default blob, `priority` command, `ls --sort priority`, the
# --priority-* filters, and the `sort` config key.
tap_start

path_add_project
REPO=$(with_repo)
cd "$REPO"
export EDITOR=true VISUAL=true

# --- new issue gets a default priority of 0 ----------------------------------
id=$(new_issue . "Default prio")
tap_assert "test \"\$(blob_content '$REPO' 'refs/issues/$id:priority')\" = '0'" "new sets priority to 0 by default"

# --- priority command sets the blob and validates numeric ----------------------
git issue priority "$id" 42 >/dev/null
tap_assert "test \"\$(blob_content '$REPO' 'refs/issues/$id:priority')\" = '42'" "priority sets the priority blob"

rc=0; out=$(git issue priority "$id" not-a-number 2>&1) || rc=$?
tap_assert "test \"\$rc\" -eq 1" "priority non-numeric exits 1"
tap_assert "echo \"\$out\" | grep -Fq 'numeric'" "priority non-numeric prints clean error"
tap_assert "test \"\$(blob_content '$REPO' 'refs/issues/$id:priority')\" = '42'" "priority non-numeric leaves blob unchanged"

# --- sorting: date (default) vs priority (numeric descending) -----------------
id1=$(new_issue . "Nine")
id2=$(new_issue . "Ninety")
id3=$(new_issue . "Hundred")
git issue priority "$id1" 9   >/dev/null
git issue priority "$id2" 90  >/dev/null
git issue priority "$id3" 100 >/dev/null

s0=$(git log --pretty=format:%h "$id"  | tail -1)
s1=$(git log --pretty=format:%h "$id1" | tail -1)
s2=$(git log --pretty=format:%h "$id2" | tail -1)
s3=$(git log --pretty=format:%h "$id3" | tail -1)

out=$(git issue ls --all --sort priority)
pos_of() { echo "$out" | grep -n "$1" | cut -d: -f1; }
tap_assert "echo \"\$out\" | head -1 | grep -q \"\$s3\"" "ls --sort priority puts highest (100) first"
tap_assert "test \"\$(pos_of \"\$s3\")\" -lt \"\$(pos_of \"\$s2\")\"" "ls --sort priority: 100 before 90"
tap_assert "test \"\$(pos_of \"\$s2\")\" -lt \"\$(pos_of \"\$s0\")\"" "ls --sort priority: 90 before 42"
tap_assert "test \"\$(pos_of \"\$s0\")\" -lt \"\$(pos_of \"\$s1\")\"" "ls --sort priority: 42 before 9"
tap_assert "echo \"\$out\" | tail -1 | grep -q \"\$s1\"" "ls --sort priority puts lowest (9) last"

# --- priority filters ----------------------------------------------------------
tap_assert "echo \"\$(git issue ls --all --priority-gt 50)\" | grep -q \"\$s3\"" "--priority-gt 50 includes 100"
tap_assert "echo \"\$(git issue ls --all --priority-gt 50)\" | grep -q \"\$s2\"" "--priority-gt 50 includes 90"
tap_assert "! echo \"\$(git issue ls --all --priority-gt 50)\" | grep -q \"\$s0\"" "--priority-gt 50 excludes 42"
tap_assert "! echo \"\$(git issue ls --all --priority-gt 50)\" | grep -q \"\$s1\"" "--priority-gt 50 excludes 9"

tap_assert "echo \"\$(git issue ls --all --priority-lt 50)\" | grep -q \"\$s0\"" "--priority-lt 50 includes 42"
tap_assert "echo \"\$(git issue ls --all --priority-lt 50)\" | grep -q \"\$s1\"" "--priority-lt 50 includes 9"
tap_assert "! echo \"\$(git issue ls --all --priority-lt 50)\" | grep -q \"\$s2\"" "--priority-lt 50 excludes 90"
tap_assert "! echo \"\$(git issue ls --all --priority-lt 50)\" | grep -q \"\$s3\"" "--priority-lt 50 excludes 100"

exact=$(git issue ls --all --priority 90)
tap_assert "echo \"\$exact\" | grep -q \"\$s2\"" "--priority 90 includes 90"
tap_assert "test \"\$(echo \"\$exact\" | wc -l | tr -d ' ')\" = '1'" "--priority 90 matches exactly one issue"

# --- status + priority filters combine ----------------------------------------
git issue close -f "$id3" >/dev/null
combined=$(git issue ls --all --priority-gt 50 --closed)
tap_assert "echo \"\$combined\" | grep -q \"\$s3\"" "combined status+priority filter finds closed high-priority"
tap_assert "! echo \"\$combined\" | grep -q \"\$s2\"" "combined status+priority filter hides open high-priority"

# --- sort config key sets the default sort -------------------------------------
git issue config sort priority
default_sort=$(git issue ls --all)
tap_assert "echo \"\$default_sort\" | head -1 | grep -q \"\$s3\"" "config sort=priority makes ls sort by priority by default"
git issue config --unset sort

# --- show displays the priority in the header ----------------------------------
show_out=$(git issue show "$id3")
tap_assert "echo \"\$show_out\" | grep -Fq 'Priority: 100'" "show displays non-default priority"
tap_assert "echo \"\$show_out\" | head -1 | grep -E '^[0-9a-f]{7,} - Hundred'" "show header first line unchanged"

# --- ls displays non-default priority; porcelain includes priority -------------
ls_all=$(git issue ls --all --sort priority)
tap_assert "echo \"\$ls_all\" | grep -Fq '[P:100]'" "ls displays non-default priority"
porc_all=$(git issue ls --porcelain --all)
tap_assert "echo \"\$porc_all\" | grep -Fq '|100'" "porcelain includes priority field"

tap_done
