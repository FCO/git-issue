# git-issue

A small set of Git scripts that manage issues directly in Git’s object store, modeling each issue as a ref (`refs/issues/*`) with trees/commits — no external server required. It also includes a static HTML generator (`git-issue-generate-page`) that renders an index and one page per issue directly from `refs/issues/*`, with timestamps, authors, and permalinks — no JavaScript or API required.

## Concept

- Each issue is a ref: `refs/issues/<ISSUE_ID>` (where `<ISSUE_ID>` is a Git commit hash) pointing to a commit whose tree contains:
  - `title`: blob with the issue title
  - `status`: blob with the issue state (e.g., `open`)
  - `msgs/`: directory with blobs, each representing a message/reply.
  - Each message (the first via `new`, later ones via `reply`) is named with a generated id (`<gen_id>`), e.g. `178942881881004-4603`.
- Operations (`new`/`reply`/`edit`) assemble trees with `git mktree` and create commits with `git commit-tree`, then update the ref via `git update-ref`.

## Requirements

- Git installed and configured (`user.name` and `user.email`).
- `$EDITOR` (or `$VISUAL`) set; if not, scripts fall back to `vi`.
- Optional: `fzf` for interactive selection and preview, `bat` for nicer message previews (if installed, scripts will use them automatically).

## Installation

Ensure the git-issue scripts are available on your `PATH` so Git can discover the `git issue` subcommand:

- Add this repository (or the folder containing `git-issue*` files) to your `PATH`.
- Git will automatically run `git-issue` when you type `git issue ...` if an executable named `git-issue` is on `PATH`.
- Example (bash/zsh):
  - `export PATH="$PATH:/path/to/git-issue-repo"`
  - Or symlink: `ln -s /path/to/git-issue-repo/git-issue /usr/local/bin/git-issue`

## Available scripts

### Examples

- `git issue new [-m|--message <msg>] "Issue title"`
  - Creates a new issue. Opens the editor for the first message, unless `-m`/`--message` is given.
  - Updates `refs/issues/<ISSUE_ID>` with a root commit (no parent) containing `title`, `status`, and `msgs/<msg_id>`.
  - Prints the short issue id (an unambiguous hash prefix); the full hash is the ref name.
  - Example: `ISSUE_ID=$(git issue new "Login fails on Safari" | tail -1)`
  - Example: `git issue new -m "It crashes on launch" "Login fails on Safari"`
- `git issue show [--all|--open|--closed] [<ISSUE_ID>]`
  - If omitted, lists issues and prompts for an id. By default only `open` issues are listed; `--all` lists every status, `--open`/`--closed` restrict to that status.
  - Shows the title and lists all messages (`msgs/*`), indicating the author of the commit that includes each message.
  - Example: `git issue show "$ISSUE_ID"`
  - Example: `git issue show --closed`
- `git issue reply [<ISSUE_ID>]`
  - If omitted, lists issues and prompts for an id.
  - Adds a message to the issue. Opens the editor for the content.
  - Creates a commit with a parent pointing to the current tip of `refs/issues/<ISSUE_ID>` and updates the ref.
  - Example: `git issue reply "$ISSUE_ID"`
- `git issue edit-title [<ISSUE_ID>]`
  - If omitted, lists issues and prompts for an id.
  - Edits the issue title, creating a new commit (with parent) and updating the ref.
  - Example: `git issue edit-title "$ISSUE_ID"`
- `git issue edit-msg [<ISSUE_ID>] [<MSG_NUMBER>]`
  - Edits a specific message by its numeric position shown in `git issue show` (1-based). Preserves the message id and creates a new commit.
  - If `<ISSUE_ID>` is omitted, lists and prompts for an id; if `<MSG_NUMBER>` is omitted, shows messages and prompts for a number.
  - Message files live under `msgs/` and are named with a generated id (e.g., `<gen_id>`); message ids are preserved across edits.
  - Example: `git issue edit-msg "$ISSUE_ID" 2` (edit the second message)
- `git issue ls [<status>|--all|--open|--closed] [--porcelain] [--sort date|priority] [--priority-gt N] [--priority-lt N] [--priority N]`
  - Lists issues (`refs/issues/*`) filtered by status; default shows open issues. Displays short hash and title.
  - `--all` shows every status; `--open`/`--closed` filter to those values; any other positional `<status>` string filters to that exact value.
  - `--porcelain` emits machine-readable `<full-hash>|<status>|<title>` lines.
  - `--sort date` (default) orders by creation date; `--sort priority` orders by priority (numeric, highest first). The `sort` config key (`git issue config sort priority`) sets the default sort when `--sort` is not passed.
  - `--priority-gt N` / `--priority-lt N` / `--priority N` filter by numeric priority (greater than / less than / exact). Filters combine with the status filter.
  - Examples:
    - `git issue ls` (open)
    - `git issue ls closed`
    - `git issue ls --all`
    - `git issue ls --sort priority`
    - `git issue ls --priority-gt 50`
- `git issue close [-f|--force] [<ISSUE_ID>]`
  - Sets `status` to `closed` and updates the ref. If omitted, prompts to select an open issue. Prompts for confirmation unless `-f`/`--force` is given.
  - Example: `git issue close "$ISSUE_ID"`
- `git issue reopen [-f|--force] [<ISSUE_ID>]`
  - Sets `status` to `open` and updates the ref. If omitted, prompts to select a closed issue. Prompts for confirmation unless `-f`/`--force` is given.
  - Example: `git issue reopen "$ISSUE_ID"`
- `git issue status <ISSUE_ID> <status>`
  - Sets the issue's status to an arbitrary string (e.g. `open`, `closed`, `in-progress`, `blocked`). Generalizes `close`/`reopen`.
  - Example: `git issue status "$ISSUE_ID" in-progress`
- `git issue priority <ISSUE_ID> <number>`
  - Sets the issue's numeric `priority` blob (default `0`). Used by `ls --sort priority` and the `--priority-*` filters. The number must be numeric.
  - Example: `git issue priority "$ISSUE_ID" 50`
- `git issue config [<KEY> [<VALUE>]]`
  - Manages repository-level configuration, stored in the `refs/issue-config` ref (one blob per key). With no arguments, lists all keys as `key = value` (sorted). With `<KEY>` only, prints that key's value (nothing if unset). With `<KEY> <VALUE>`, sets/updates the key. Use `config --unset <KEY>` to remove a key.
  - Examples:
    - `git issue config` (list all keys)
    - `git issue config sort` (get the `sort` value)
    - `git issue config sort priority` (set `sort` to `priority`)
    - `git issue config --unset sort` (remove `sort`)
- `git issue pull` / `git issue push` / `git issue sync`
  - Synchronize issue refs with the remote: fetch/push `refs/issues/*`.
  - Examples:
    - `git issue pull`
    - `git issue push`
    - `git issue sync`
- `git issue help`
  - Prints usage for all commands. Also shown by `git issue` with no arguments, `-h`, or `--help`.
- `git issue show-messages <ISSUE_ID>`
  - Internal helper that prints an issue's messages; used by the `fzf` interactive preview. Prefer `show` for direct use.

## Shell completion

Completion scripts for bash and zsh are in `completions/`:

- bash: `source completions/git-issue.bash`
- zsh: `source completions/git-issue.zsh`

They complete the `git issue` subcommands (and issue ids where applicable).

## Recommended workflow

1. Before replying/editing in a fresh clone, fetch issue refs:
   - `git fetch origin 'refs/issues/*:refs/issues/*'` or `./git-issue pull`
2. Create replies/edits (`reply`, `edit-*`).
3. Push:
   - `git push origin 'refs/issues/*:refs/issues/*'` or `./git-issue push`

If push is rejected (non-fast-forward), fetch updates (`pull`) and re-apply your change on the current tip (scripts already use the local tip as parent). Avoid creating replies when the ref doesn’t exist locally, as that produces root commits.

## Web (GitHub Pages)

Static site is generated by `./git-issue-generate-page` into `docs/`:
- `index.html` lists **open** issues (sorted by earliest message timestamp), with a link to the closed-issues page.
- `closed.html` lists **closed** issues, with a link back to the open-issues page.
- Each issue page shows title, status, opener, timestamps, and all messages with authors.
- Permalinks to each message via anchors.

Link (GitHub Pages):
- https://fco.github.io/git-issue/

### Generate locally

- `./git-issue pull` (or `git fetch origin 'refs/issues/*:refs/issues/*'`)
- `./git-issue-generate-page`
- Open `docs/index.html`

### Publish to GitHub Pages (CI)

This repository includes `.github/workflows/gh-pages.yml` which:
- Checks out with full history (`fetch-depth: 0`).
- Fetches `refs/issues/*`.
- Runs the generator and uploads `docs/` as the Pages artifact.
- Deploys to GitHub Pages.

It regenerates automatically every 30 minutes via a `schedule` (cron), on every push to `main`, and on manual `workflow_dispatch`. Note: GitHub Actions does not trigger `push` events for the custom `refs/issues/*` refs, so issue changes are picked up by the scheduled run (not instantly).

No React/Vite is required for the static site.

## Tips and troubleshooting

- “Failed to fetch” / rate limit: authenticate and/or wait for `X-RateLimit-Reset`; check headers: `X-RateLimit-*`.
- “non-fast-forward” on push: run `./git-issue pull` and re-apply your reply/edit; verify commit parent:
  - `git log --pretty='%H %P' -n 1 $(git rev-parse refs/issues/<ISSUE_ID>)`
- Empty editor: set `$EDITOR` or `$VISUAL`; default is `vi`.

## License

This project is experimental and uses Git as the backend for issues. Use with care and back up your refs/objects as needed.
