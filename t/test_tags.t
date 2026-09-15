#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

# Tags: empty default blob, `tag`/`untag`, `ls --tag`, and `show` display.
tap_start

path_add_project
REPO=$(with_repo)
cd "$REPO"
export EDITOR=true VISUAL=true

# --- new issue gets an empty tags blob ----------------------------------------
id=$(new_issue . "Tagged issue")
tap_assert "test \"\$(git -C '$REPO' cat-file -s 'refs/issues/$id:tags')\" = '0'" "new creates an empty tags blob"

# --- tag adds (and dedupes), preserving the rest of the tree -------------------
git issue tag "$id" bug >/dev/null
git issue tag "$id" urgent bug >/dev/null   # "bug" is a duplicate
tags=$(git -C "$REPO" show "refs/issues/$id:tags")
tap_assert "echo \"\$tags\" | grep -Fxq 'bug'" "tag adds a tag"
tap_assert "echo \"\$tags\" | grep -Fxq 'urgent'" "tag adds a second tag"
tap_assert "test \"\$(echo \"\$tags\" | wc -l | tr -d ' ')\" = '2'" "tag dedupes an existing tag"
tap_assert "test \"\$(blob_content '$REPO' 'refs/issues/$id:title')\" = 'Tagged issue'" "tag preserves the title"
tap_assert "test \"\$(blob_content '$REPO' 'refs/issues/$id:status')\" = 'open'" "tag preserves the status"
tap_assert "test \"\$(msgs_count '$REPO' '$id')\" = '1'" "tag preserves the messages"
tap_assert "echo \"\$(git issue ls --all)\" | grep -Fq '[bug, urgent]'" "ls displays tags"

# --- ls --tag filter ----------------------------------------------------------
untagged=$(new_issue . "Untagged issue")
tap_assert "echo \"\$(git issue ls --all --tag bug)\" | grep -q 'Tagged issue'" "ls --tag matches a tagged issue"
tap_assert "! echo \"\$(git issue ls --all --tag bug)\" | grep -q 'Untagged issue'" "ls --tag excludes an untagged issue"
tap_assert "test -z \"\$(git issue ls --all --tag nonexistent)\"" "ls --tag with no matches prints nothing"

# --- !tag negation ----------------------------------------------------------
out=$(git issue ls --all --tag '!bug')
tap_assert "echo \"\$out\" | grep -q 'Untagged issue'" "ls --tag '!bug' matches untagged issues"
tap_assert "! echo \"\$out\" | grep -q 'Tagged issue'" "ls --tag '!bug' excludes tagged issues"

# --- tag filter combines with status filter ------------------------------------
git issue close -f "$untagged" >/dev/null
tagged_closed=$(new_issue . "Tagged closed")
git issue tag "$tagged_closed" bug >/dev/null
git issue close -f "$tagged_closed" >/dev/null
out=$(git issue ls --all --tag bug --closed)
tap_assert "echo \"\$out\" | grep -q 'Tagged closed'" "combined --tag + --closed finds a closed tagged issue"
tap_assert "! echo \"\$out\" | grep -q 'Tagged issue'" "combined --tag + --closed hides the open tagged issue"

# --- untag removes, leaving the rest intact ------------------------------------
git issue untag "$id" bug >/dev/null
tags=$(git -C "$REPO" show "refs/issues/$id:tags")
tap_assert "! echo \"\$tags\" | grep -Fxq 'bug'" "untag removes the tag"
tap_assert "echo \"\$tags\" | grep -Fxq 'urgent'" "untag leaves other tags intact"
tap_assert "test \"\$(blob_content '$REPO' 'refs/issues/$id:title')\" = 'Tagged issue'" "untag preserves the title"

git issue untag "$id" urgent >/dev/null
tap_assert "test \"\$(git -C '$REPO' cat-file -s 'refs/issues/$id:tags')\" = '0'" "untag of the last tag empties the blob"

# --- show displays tags in the header ------------------------------------------
git issue tag "$id" alpha beta >/dev/null
show_out=$(git issue show "$id")
tap_assert "echo \"\$show_out\" | grep -Fq 'Tags: alpha, beta'" "show displays tags in the header"
tap_assert "echo \"\$show_out\" | head -1 | grep -E '^[0-9a-f]{7,} - Tagged issue'" "show header first line unchanged with tags"

tap_done
