#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

tap_start

path_add_project
REPO=$(with_repo)
cd "$REPO"
export EDITOR=true; export VISUAL=true

id1=$(new_issue . "Web Test")
reply_id=$(git issue reply "$id1" | tail -1)

id2=$(new_issue . "Closed Thing")
git issue close -f "$id2" > /dev/null

git issue priority "$id1" 50 > /dev/null
git issue tag "$id1" bug web > /dev/null

# Run the generator from inside the temp repo so it writes to $REPO/docs
# instead of clobbering the project's tracked docs/ directory.
cp "$PROJECT_DIR/git-issue-generate-page" "$REPO/git-issue-generate-page"
"$REPO/git-issue-generate-page" > /dev/null

abb=$(git -C "$REPO" log --pretty=format:%h "$id1" | tail -1)

tap_assert "test -f \"$REPO/docs/index.html\"" "index.html exists in docs"
tap_assert "test -f \"$REPO/docs/issues/$abb.html\"" "issue page exists"

index_page="$REPO/docs/index.html"
issue_page="$REPO/docs/issues/$abb.html"
closed_page="$REPO/docs/closed.html"

tap_assert "grep -F 'Issues' \"$index_page\"" "index has title"
tap_assert "grep -F 'Opened by' \"$issue_page\"" "issue page shows opener"
tap_assert "grep -F 'Messages' \"$issue_page\"" "issue page shows messages section"

# Regression: interpolated values must not be wrapped in doubled quotes.
tap_assert "grep -F '<h1>Web Test</h1>' \"$issue_page\"" "h1 title has no surrounding quotes"
tap_assert "grep -F '<span class=\"status\">open</span>' \"$issue_page\"" "status has no surrounding quotes"
tap_assert "grep -F '<strong>tester</strong>' \"$issue_page\"" "opener has no surrounding quotes"
tap_assert "! grep -F '\"\"' \"$issue_page\"" "no doubled quotes in issue page"
tap_assert "! grep -F '\"\"' \"$index_page\"" "no doubled quotes in index page"

# Two separate list pages: open (index.html) and closed (closed.html).
tap_assert "test -f \"$closed_page\"" "closed.html exists in docs"

tap_assert "grep -F 'Web Test' \"$index_page\"" "index lists the open issue"
tap_assert "! grep -F 'Closed Thing' \"$index_page\"" "index omits the closed issue"
tap_assert "grep -F 'href=\"closed.html\"' \"$index_page\"" "index links to closed page"

tap_assert "grep -F 'Closed Thing' \"$closed_page\"" "closed page lists the closed issue"
tap_assert "! grep -F 'Web Test' \"$closed_page\"" "closed page omits the open issue"
tap_assert "grep -F 'href=\"index.html\"' \"$closed_page\"" "closed page links to index"

# Priority and tags are shown on the issue page; per-tag pages + tags index.
tap_assert "grep -F 'Priority: <strong>50</strong>' \"$issue_page\"" "issue page shows priority"
tap_assert "grep -F '../tags/bug.html' \"$issue_page\"" "issue page links its tag"
tap_assert "test -f \"$REPO/docs/tags.html\"" "tags index exists"
tap_assert "grep -F 'href=\"tags/bug.html\"' \"$REPO/docs/tags.html\"" "tags index links a tag page"
tap_assert "test -f \"$REPO/docs/tags/bug.html\"" "tag page exists"
tap_assert "grep -F 'Web Test' \"$REPO/docs/tags/bug.html\"" "tag page lists the issue"
tap_assert "grep -F 'href=\"tags.html\"' \"$index_page\"" "index links to tags index"

tap_done
