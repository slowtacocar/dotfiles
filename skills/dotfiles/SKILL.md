---
name: dotfiles
description: Use this dotfiles repository's zsh worktree, tmux, and GitHub helpers for repositories under ~/Desktop/repos.
---

# Dotfiles workflow

Resolve `~/.zshrc` to find the active checkout and read the relevant function
when its behavior needs clarification. Read the target repo's `AGENTS.md`
before editing. Helpers are zsh functions; invoke them with `zsh -ic`.

`wt <repo>` fetches the remote default branch and creates a worktree at
`~/Desktop/repos/worktrees/wt-<random>/<repo>`, with a detached tmux shell.
`wta [name]` attaches; `wtr [name]` recreates a missing session for an existing
worktree. Both infer the name inside a worktree. Set later tool calls' working
directory explicitly because a helper's `cd` only changes its own shell.

`pr "Title"` stages and commits every repo in the wrapper directory, pushes,
and creates draft PRs. Inspect all diffs before using it. `merge` marks PRs
ready, enables auto-merge, waits, and runs `wtd` afterward. These actions need
the user's instruction; implementing a change alone does not authorize a PR
or merge. `wtd` removes worktrees and stops their tmux session, so first confirm
all intended work is committed and pushed. Inspect the actual implementation
before calling a destructive helper.

Use existing dev servers where available. Inspect `tmux list-windows` and
`tmux capture-pane` without attaching. Do not restart servers without task
authorization. Read server output or `portless list` to find the actual URL.
Stop only processes belonging to the task, never a broad name or pattern.

`portless-open <app>` opens an app's URL and prints a clickable terminal link
over SSH. With `PORTLESS_TAILSCALE=1`, it resolves the shared URL from
`portless list` and fails if no matching app is present.
