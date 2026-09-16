#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

# `git issue import` — non-network test using a `curl` shim that returns
# canned GitHub API JSON. Verifies title/status/labels→tags/author/body mapping
# and idempotent re-import (gh-<n> dedup tag).
tap_start

path_add_project
REPO=$(with_repo)
cd "$REPO"
export EDITOR=true VISUAL=true

SHIM=$(mktemp -d)
cat > "$SHIM/curl" <<'EOF'
#!/bin/sh
printf '%s\n' "$CANNED_JSON"
EOF
chmod +x "$SHIM/curl"

export CANNED_JSON='[
  {
    "number": 1,
    "title": "Imported issue",
    "body": "The body text",
    "state": "open",
    "user": {"login": "alice", "id": 123},
    "created_at": "2020-01-02T03:04:05Z",
    "labels": [{"name": "bug"}, {"name": "enhancement"}]
  }
]'

export PATH="$SHIM:$PATH"

git issue import owner/repo >/dev/null 2>&1

id=$(git for-each-ref --format='%(refname)' refs/issues/ | sed 's#^refs/issues/##' | head -1)

tap_assert "test -n \"$id\"" "import created an issue"
tap_assert "test \"\$(blob_content '$REPO' 'refs/issues/'$id':title')\" = 'Imported issue'" "import maps title"
tap_assert "test \"\$(blob_content '$REPO' 'refs/issues/'$id':status')\" = 'open'" "import maps state"
tap_assert "git -C '$REPO' show 'refs/issues/'$id':tags' | grep -Fxq 'gh-1'" "import adds gh-1 dedup tag"
tap_assert "git -C '$REPO' show 'refs/issues/'$id':tags' | grep -Fxq 'bug'" "import maps label to tag"
tap_assert "git -C '$REPO' show 'refs/issues/'$id':tags' | grep -Fxq 'enhancement'" "import maps second label"
tap_assert "test \"\$(msgs_count '$REPO' '$id')\" = '1'" "import stores the body as one message"
tap_assert "git -C '$REPO' log -1 --format='%aN' 'refs/issues/'$id | grep -q 'alice'" "import preserves author"
tap_assert "git -C '$REPO' log -1 --format='%ae' 'refs/issues/'$id | grep -q '123+alice@users.noreply.github.com'" "import uses noreply email"

# Re-import is idempotent: the gh-1 tag makes it skip.
count_before=$(git for-each-ref --format='%(refname)' refs/issues/ | wc -l | tr -d ' ')
out=$(git issue import owner/repo 2>&1 || true)
tap_assert "echo \"\$out\" | grep -q 'skip'" "re-import skips already-imported issue"
count_after=$(git for-each-ref --format='%(refname)' refs/issues/ | wc -l | tr -d ' ')
tap_assert "test \"\$count_before\" = \"\$count_after\"" "re-import does not duplicate"

rm -rf "$SHIM"
tap_done
