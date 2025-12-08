# git-issue

A small set of Git scripts that manage issues directly in Git’s object store, modeling each issue as a ref (`refs/issues/*`) with trees/commits — no external server required. It also includes a React web page that reads those refs via the GitHub API and displays issues and messages.

## Concept

- Each issue is a ref: `refs/issues/ISS-<ID>` pointing to a commit whose tree contains:
  - `title`: blob with the issue title
  - `status`: blob with the issue state (e.g., `open`)
  - `msgs/`: directory with blobs, each representing a message/reply (`ISS-<id>-<id_msg>`)
- Operations (`new`/`reply`/`edit`) assemble trees with `git mktree` and create commits with `git commit-tree`, then update the ref via `git update-ref`.

## Requirements

- Git installed and configured (`user.name` and `user.email`).
- `$EDITOR` (or `$VISUAL`) set; if not, scripts fall back to `vi`.

## Available scripts

- `./git-issue new "Issue title"`
  - Creates a new issue. Opens the editor for the first message.
  - Updates `refs/issues/ISS-<ID>` with a root commit (no parent) containing `title`, `status`, and `msgs/<msg_id>`.
- `./git-issue show ISS-<ID>`
  - Shows the title and lists all messages (`msgs/*`), indicating the author of the commit that includes each message.
- `./git-issue reply ISS-<ID>`
  - Adds a message to the issue. Opens the editor for the content.
  - Creates a commit with a parent pointing to the current tip of `refs/issues/ISS-<ID>` and updates the ref.
- `./git-issue edit-title ISS-<ID>`
  - Edits the issue title, creating a new commit (with parent) and updating the ref.
- `./git-issue edit-msg <MSG_ID>`
  - Edits the content of a specific message, preserving its id and creating a new commit.
- `./git-issue ls`
  - Lists all issues (`refs/issues/*`) with their titles.
- `./git-issue pull` / `./git-issue push` / `./git-issue sync`
  - Synchronize issue refs with the remote: fetch/push `refs/issues/*`.

## Recommended workflow

1. Before replying/editing in a fresh clone, fetch issue refs:
   - `git fetch origin 'refs/issues/*:refs/issues/*'` or `./git-issue pull`
2. Create replies/edits (`reply`, `edit-*`).
3. Push:
   - `git push origin 'refs/issues/*:refs/issues/*'` or `./git-issue push`

If push is rejected (non-fast-forward), fetch updates (`pull`) and re-apply your change on the current tip (scripts already use the local tip as parent). Avoid creating replies when the ref doesn’t exist locally, as that produces root commits.

## Web (GitHub Pages)

There’s an app under `web/` (React + Vite) that consumes the GitHub API to:
- List issues via `matching-refs` under `refs/issues/*`.
- Display an issue (title and messages). For each message, it shows the author of the first commit that added that file.

Link (GitHub Pages):
- https://FCO.github.io/git-issue/

### Run locally

- `cd web`
- `npm install`
- `npm run dev`

### Publish to GitHub Pages

The repository is set up to publish from the `docs/` folder or via a `gh-pages` branch.

- Deploy via `docs/` (main branch):
  - `cd web && npm run deploy`
  - Builds and copies `web/dist` → `docs/`. Commit/push the `docs/` folder.
  - In Settings → Pages, select Source: Deploy from a branch, Branch: `main`, Folder: `/docs`.

- Deploy via `gh-pages`:
  - Create the `gh-pages` branch if it doesn’t exist: `git branch gh-pages && git push -u origin gh-pages`
  - `cd web && npm run deploy:ghpages`
  - In Settings → Pages, select Branch: `gh-pages`, Folder: `/root`.

### API limits / Cache

- Unauthenticated requests: ~60/hour per IP; with token: ~5,000/hour.
- The app uses `ETag` and `If-None-Match` (localStorage) to reduce calls and respect rate limits.
- To raise limits, set a token and add `Authorization: Bearer <TOKEN>` (can be parameterized via `.env` in the app).

## Tips and troubleshooting

- “Failed to fetch” / rate limit: authenticate and/or wait for `X-RateLimit-Reset`; check headers: `X-RateLimit-*`.
- “non-fast-forward” on push: run `./git-issue pull` and re-apply your reply/edit; verify commit parent:
  - `git log --pretty='%H %P' -n 1 $(git rev-parse refs/issues/ISS-<ID>)`
- Empty editor: set `$EDITOR` or `$VISUAL`; default is `vi`.

## License

This project is experimental and uses Git as the backend for issues. Use with care and back up your refs/objects as needed.
