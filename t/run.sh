#!/usr/bin/env bash
set -euo pipefail

# Wrapper to emit TAP for prove

echo "TAP version 13"
plan=0

run_one() {
  local t="$1"
  bash "$t"
  # Count tests by parsing the plan line at the end of each script
  local count=$(bash "$t" | tail -1 | sed -n 's/^1..\([0-9]\+\)$/\1/p')
  plan=$((plan+count))
}

for t in "$(dirname "$0")"/test_*.sh; do
  run_one "$t"
done

echo "1..$plan"
