---
name: dotfiles
description: Navigate local repos and use this dotfiles repository's zsh development workflow, including worktrees, draft PRs, merging, develop-to-main cutovers, and the adl dbt shortcut. Use when working in ~/Desktop/repos or with these shell helpers.
---

# Working with these dotfiles

The shell helpers expect repos in `~/Desktop/repos`, relative to the current
user's home directory. The dotfiles checkout is commonly `~/dotfiles`, but can
live elsewhere: `setup.sh` links `~/.zshrc` to that checkout's `zshrc`, the source
of truth for the helpers below. Resolve the link on the current machine rather
than assuming a username, checkout path, or installed tools. Read the relevant
function if its behavior needs clarification;
some comments lag the implementation. Read the target repo's `AGENTS.md` and
any applicable nested guidance before editing.

## Repo map

| Repo | What lives here |
| --- | --- |
| `api` | Fragile's core business backend; TypeScript API, entities, migrations, and business services. |
| `ship` | Frontend monorepo using Bun workspaces and Turborepo; apps in `apps/`, shared code in `libs/`. **“Back office” means `ship/apps/support-portal`.** Also contains customer portal, checkout, and Whim apps. |
| `cxp` | Separate application with `frontend/` (React/Vite), `api/` (Hono, MikroORM/PostgreSQL, OpenWorkflow), and `shared/` types. |
| `adl` | Analytical Data Layer: Python/Dagster pipelines and Snowflake/dbt models. dbt project lives at `adl/adl/dbt` relative to the repos directory. |

`api`, `ship`, and `cxp` branch from and PR into **`develop`**, even though
`origin/HEAD` may point to `main`. Other repos use `origin/HEAD`, falling back
to `main`. The `rebase` and `gdiff` aliases use `origin/HEAD`; use an explicit
`origin/develop` for these three repos instead.

## Calling shell helpers

These are zsh functions, not executables. Use an interactive zsh to load them:

```sh
zsh -ic 'wt'
zsh -ic 'cd "$HOME/Desktop/repos/worktrees/wt-abc123/api" && pr "Fix billing dates"'
```

Use the real generated worktree name. A helper's `cd` only changes that shell;
set subsequent tool calls' working directory explicitly. `wt` starts detached
tmux sessions, so returning successfully does not mean dependency installation
or dev-server startup has finished. Inspect logs without attaching:
`tmux list-windows -t wt-abc123` and
`tmux capture-pane -p -t wt-abc123:api -S -100`.

## Create and use worktrees

- `wt` creates **both api and ship** with environment setup and dev servers.
- `wt cxp` creates CXP, copies its API/frontend env files and local auth keys,
  installs Bun dependencies once, and runs `bun dev` in each workspace.
- `wt rms` installs Bun dependencies and runs `bun run dev` under Portless in
  its own tmux window, at `https://<worktree-name>.rms.localhost`.
- `wt adl` copies `adl/dbt/.env`, creates a venv, and runs
  `uv pip sync constraints-dev.txt` in a temporary tmux session. That session
  exits after a successful install; there is no persistent dev server.
- `wt <repo>` supports other repos, but only creates a worktree and shell.
  In particular, `wt api` or `wt ship` does **not** do the paired env/server setup.

Each invocation creates `~/Desktop/repos/worktrees/wt-<random>/<repo>` and
branches named `wt-<random>` from freshly fetched base refs. It leaves the base
checkouts untouched. Reuse an existing task worktree when appropriate.

For paired api/ship worktrees, `wt` copies base `api/.env.local` to worktree
`api/.env`, copies Ship apps' `.env.local` files, and rewrites their
`localhost:3000` API URLs to `https://<worktree-name>.api.localhost`.
The tmux API window installs dependencies, runs migrations, and starts the
portless dev server; Ship installs dependencies and starts its portless apps.

`wta [name]` attaches to a session. `wtr [name]` recreates a missing session for
an existing worktree without recreating Git branches or copying env files.
Both infer the name when run inside a worktree.

Inside a worktree, `bo`, `portal`, and `checkout` open the corresponding
`https://<worktree-name>.<app>.localhost` URL. `bo` maps to `support-portal`.
Outside a worktree they omit the worktree prefix. `rms` opens
`https://<worktree-name>.rms.localhost`, or `https://rms.localhost` outside a
worktree. With `PORTLESS_TAILSCALE=1`, these shortcuts look up the matching
app's shared Tailscale URL in `portless list` and fail if none is available.
They try `open` locally and fall back to an OSC 8 hyperlink if it fails or is
unavailable. Over SSH they print the hyperlink directly: Cmd-click it in
Ghostty to open it on the client Mac.

## Dev servers and process management

In an existing worktree, use the dev servers already running in its named tmux
session instead of starting another server. Use `tmux ls` and
`tmux list-windows -t <worktree-name>` to find the right window, then read its
output with `tmux capture-pane -p -t <worktree-name>:<window> -S -200`.
Attach with `wta` when interactive access is needed. If the server genuinely
is not running, report that and ask before starting or restarting it, unless
the user has already authorized that action. This includes using `wtr` to
restart servers; `wt`'s normal startup is part of creating a requested dev environment.

Do not guess a default port or hostname. Read the URL actually printed by the
server or inspect `bunx portless list` before requests, smoke tests, or browser
navigation. Portless commonly uses
`https://<worktree-name>.<service>.localhost`, where the service may be a repo
such as `api` or an app such as `support-portal`. If the output and proxy list
do not establish the URL, ask instead of guessing.

For other long-running commands, use the agent harness's managed execution and
session/task controls to read output and stop the command. In Codex, retain the
session ID returned by `exec_command` and use `write_stdin`; in Claude Code,
use `run_in_background: true` and the available task tools. Do not manually
detach processes with `nohup`, a trailing `&`, `disown`, `setsid`, or
`screen -dm`. The existing `wt`/tmux workflow is the managed dev-server path.

Never kill processes broadly by name or pattern (for example `pkill -f node`,
`killall node`, or `pkill -f bun`): other worktrees use the same runtimes.
Stop only the exact task you started through its harness controls, or use
`kill <PID>` after identifying and verifying the specific process. Port lookup
with `lsof` can help, but confirm ownership before killing. If the correct
process cannot be identified, ask. For authorized whole-worktree cleanup, use
the existing `wtd` helper, which scopes cleanup to that worktree's path.

## Make a PR

Creating PRs, merging PRs, and cutting over to main are the user's responsibility
by default. Only perform one of these actions when the user actually instructs
the agent to do it. A request to implement or fix something does not authorize
these actions, and permission to create a PR does not also authorize merging
or cutover. Otherwise, finish the requested work and validation, then hand it
back to the user without running `pr`, `merge`, `cutover`, or equivalent GitHub
commands. Instructions already given in the conversation remain valid; do not
ask for confirmation again for an action the user has authorized.

Run `pr "Descriptive title"` from anywhere inside the task worktree.
It processes **every repo in that worktree**, stages all changes (`git add -A`),
commits with message `commit`, pushes, and creates draft PRs against each repo's
base. Repos with no commits ahead of the base are skipped. Existing open PRs
are updated by pushing; their title/body are not changed. Pass a title to avoid
an interactive prompt. Inspect each repo's diff first because all files are staged.

The helper creates empty PR bodies. Add a concise description of the change and
validation with `gh pr edit <number> --body-file <file>` from the relevant repo.
Check the returned URLs and remote state: the helper can print push/create
failures without returning an overall failure status.

## Merge and clean up

Run `merge` inside the worktree only when the user has instructed the agent
to merge. It marks all open PRs for its repo branches ready, enables squash
auto-merge (override with `--merge` or `--rebase`), and waits for every PR.
It can rebase behind branches onto their actual PR base and push with
`--force-with-lease`. Inspect and resolve checks, conflicts, or requested
changes if it stalls; its polling loop has no timeout.

After merging, it runs `wtd`, which stops worktree processes, kills tmux,
**force-removes all repo worktrees**, and deletes the wrapper directory.
Before calling `merge`, make sure all intended work in every repo is committed
and pushed, including repos without an open PR. `merge` itself does not commit.
`wtd [name]` also works standalone; `--keep-shell` prevents its normal shell exit.

For PRs into `develop`, `merge` cleans up with `--keep-shell` and prints the
needed `cutover` command. Landing on `develop` is not the production cutover.

## Cut over develop to main

Run `cutover api`, `cutover ship`, `cutover cxp`, or multiple names such as
`cutover api ship` only when the user has instructed the agent to cut over.
It works from any directory using
the base checkouts. It creates or reuses each `develop` → `main` PR, defaults
to a merge commit to preserve branch history, enables auto-merge (or merges
directly if needed), waits, and exits the shell on success.

Cutover promotes **everything currently on develop**, not just this task.
The helper has an author guard; inspect the current `cutover` implementation
for the accepted GitHub author rather than assuming it matches the signed-in
user. If the guard rejects the commit authors, it leaves a reviewable PR
and does not merge that repo. Inspect that diff before considering
`cutover -f <repo>`; `-f` bypasses this author check and should only be used when
the broader promotion is authorized. A multi-repo cutover can merge some repos
while leaving others blocked. Verify each PR's outcome.

## The adl shortcut

Call `adl <dbt-selector> [more selectors/options]` from the **ADL repo root**
(base checkout or worktree), for example `adl fct_subscriptions__daily`.
Have `dbt` on PATH and the repo's Snowflake dev environment loaded; the helper
does not activate `.venv` or load `.env` itself. Follow ADL's README for setup.

It changes into `adl/dbt`, runs:

```sh
SNOWFLAKE_SCHEMA=adl_dagster_prod dbt parse --target-path target/prod-state
dbt run --select <arguments> --defer --state target/prod-state
```

Then it returns to the repo root. The schema override applies only to the parse:
the selected models run using the current dev environment, with unselected
dependencies eligible to resolve through the production-state manifest.
Keep the run pointed at a dev schema; production builds belong to deployed
Dagster. This shortcut runs models, not tests. Inspect both commands' output:
the function does not stop on parse failure, and its final `cd` can mask errors.
