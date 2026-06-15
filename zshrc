# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

source /opt/homebrew/share/antigen/antigen.zsh
antigen theme romkatv/powerlevel10k
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle zsh-users/zaw
antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle zsh-users/zsh-history-substring-search
antigen apply
bindkey '^[[A' history-substring-search-up # or '\eOA'
bindkey '^[[B' history-substring-search-down # or '\eOB'
HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1
bindkey '^r' zaw-history
bindkey '^b' zaw-git-branches

export CLICOLOR=1

zstyle ':filter-select' hist-find-no-dups yes
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

export NODE_OPTIONS=--no-network-family-autoselection

# bun completions
[ -s "/Users/bgeorge/.bun/_bun" ] && source "/Users/bgeorge/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
# Added by dbt Fusion extension (ensure dbt binary dir on PATH)
if [[ ":$PATH:" != *":/Users/bgeorge/.local/bin:"* ]]; then
  export PATH=/Users/bgeorge/.local/bin:"$PATH"
fi
# Added by dbt Fusion extension
alias dbtf=/Users/bgeorge/.local/bin/dbt

# pr: from any subdir of a `wt` worktree, commit+push every repo in it and open PRs.
#   - iterates each repo folder in the worktree root (api/ship, or cxp, or whatever)
#   - for each repo: git add -A, commit (msg always "commit"), push
#   - skips a repo with no changes (nothing ahead of its base branch)
#   - if a repo has no open PR yet: uses the args as the PR title (or prompts ONCE if no args),
#     creates the PR(s) with `gh pr create`, and opens the new one(s) in browser
#   - if a PR already exists: just commits & pushes (no prompt, no browser)
pr() {
  emulate -L zsh
  command -v gh >/dev/null || { echo "pr: gh not installed (brew install gh)"; return 1; }

  local wt_root="$HOME/Desktop/repos/worktrees"
  if [[ "$PWD/" != "$wt_root/"* ]]; then
    echo "pr: run this inside a ~/Desktop/repos/worktrees/<name> worktree"; return 1
  fi
  local name="${PWD#$wt_root/}"; name="${name%%/*}"
  local root="$wt_root/$name"
  local commit_msg="commit"
  local title="$*"

  typeset -a need_pr
  local repo dir branch base ahead existing

  while IFS= read -r dir; do
    git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || continue
    repo="${dir:t}"
    branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD)"

    git -C "$dir" add -A
    git -C "$dir" diff --cached --quiet || git -C "$dir" commit -m "$commit_msg" >/dev/null

    base="$(git -C "$dir" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)"
    [[ -z "$base" ]] && { [[ "$repo" == api ]] && base="origin/develop" || base="origin/main"; }
    ahead="$(git -C "$dir" rev-list --count "${base}..HEAD" 2>/dev/null || echo 0)"
    if [[ "$ahead" == 0 ]]; then
      echo "pr: $repo — no changes, skipping"
      continue
    fi

    echo "pr: $repo — pushing $branch"
    git -C "$dir" push -u origin "$branch" >/dev/null 2>&1 || echo "pr: $repo — push failed"

    existing="$(cd "$dir" && gh pr list --head "$branch" --state open --json url -q '.[0].url' 2>/dev/null)"
    if [[ -n "$existing" ]]; then
      echo "pr: $repo — PR exists, committed & pushed only ($existing)"
    else
      need_pr+=("$dir")
    fi
  done < <(find "$root" -mindepth 1 -maxdepth 1 -type d | sort)

  (( ${#need_pr} )) || return 0

  [[ -z "$title" ]] && read -r "title?PR title: "
  if [[ -z "$title" ]]; then
    echo "pr: no title entered — branches pushed, PR not created"; return 1
  fi

  local url
  for dir in "${need_pr[@]}"; do
    if url="$(cd "$dir" && gh pr create --title "$title" --body "" 2>/dev/null)" && [[ "$url" == https://* ]]; then
      echo "pr: ${dir:t} — created $url"
      open "$url"
    else
      echo "pr: ${dir:t} — gh pr create failed"
    fi
  done
}

# merge: from inside a `wt` worktree, enable auto-merge on every repo's open PR,
#   wait for them all to merge, then run `wtd` to tear the worktree down.
#   - merge method defaults to squash; pass --merge / --rebase / --squash to override
merge() {
  emulate -L zsh
  command -v gh >/dev/null || { echo "merge: gh not installed (brew install gh)"; return 1; }

  local wt_root="$HOME/Desktop/repos/worktrees"
  if [[ "$PWD/" != "$wt_root/"* ]]; then
    echo "merge: run this inside a ~/Desktop/repos/worktrees/<name> worktree"; return 1
  fi
  local name="${PWD#$wt_root/}"; name="${name%%/*}"
  local root="$wt_root/$name"

  local method="--squash"
  case "$1" in
    --merge|--rebase|--squash) method="$1" ;;
  esac

  typeset -a prs
  local dir repo branch pr_num state

  while IFS= read -r dir; do
    git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || continue
    repo="${dir:t}"
    branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD)"

    pr_num="$(cd "$dir" && gh pr list --head "$branch" --state open --json number -q '.[0].number' 2>/dev/null)"
    if [[ -z "$pr_num" ]]; then
      echo "merge: $repo — no open PR for $branch, skipping"
      continue
    fi

    if (cd "$dir" && gh pr merge "$pr_num" --auto "$method" >/dev/null 2>&1); then
      echo "merge: $repo — auto-merge enabled on PR #$pr_num"
    else
      echo "merge: $repo — gh pr merge failed on PR #$pr_num"; return 1
    fi
    prs+=("$dir:$pr_num")
  done < <(find "$root" -mindepth 1 -maxdepth 1 -type d | sort)

  (( ${#prs} )) || { echo "merge: no PRs to wait on"; return 1; }

  # Set the terminal window/tab title. OSC 0 sets both window and icon/tab title
  # (OSC 1 alone is ignored by many modern terminals, which fall back to showing the
  # running command — hence "merge").
  _merge_tab() { printf '\033]0;%s\007' "$1" }

  echo "merge: waiting for ${#prs} PR(s) to merge…"
  local entry remaining=("${prs[@]}") mss rd c_failed c_pending label summary
  local -a info
  typeset -A rebased
  while (( ${#remaining} )); do
    typeset -a still parts
    still=(); parts=()
    for entry in "${remaining[@]}"; do
      dir="${entry%%:*}"; pr_num="${entry##*:}"; repo="${dir:t}"
      info=("${(@f)$(cd "$dir" && gh pr view "$pr_num" --json state,mergeStateStatus,reviewDecision,statusCheckRollup -q '
        .state,
        (.mergeStateStatus // ""),
        (.reviewDecision // ""),
        ([.statusCheckRollup[]? | select(.conclusion=="FAILURE" or .conclusion=="CANCELLED" or .conclusion=="TIMED_OUT" or .state=="FAILURE" or .state=="ERROR")] | length),
        ([.statusCheckRollup[]? | select(
            (.status != null and .status != "COMPLETED")
            or (.state == "PENDING" or .state == "EXPECTED")
         )] | length)
      ' 2>/dev/null)}")
      state="${info[1]}"; mss="${info[2]}"; rd="${info[3]}"; c_failed="${info[4]:-0}"; c_pending="${info[5]:-0}"

      case "$state" in
        MERGED) echo "merge: $repo — PR #$pr_num merged"; continue ;;
        CLOSED) echo "merge: $repo — PR #$pr_num closed without merging"; _merge_tab ""; return 1 ;;
      esac

      # Pick the single most actionable status to show.
      # UPPERCASE = user action required; lowercase = just waiting.
      if   (( c_failed > 0 ));               then label="CHECKS-FAILED"
      elif [[ "$mss" == DIRTY ]];            then label="CONFLICTS"
      elif [[ "$rd"  == CHANGES_REQUESTED ]];then label="REVIEW-CHANGES-REQUESTED"
      elif [[ "$rd"  == REVIEW_REQUIRED ]];  then label="REVIEW-REQUIRED"
      elif [[ "$mss" == BEHIND ]];           then label="rebasing"
      elif (( c_pending > 0 ));              then label="checks-pending"
      elif [[ "$mss" == BLOCKED ]];          then label="BLOCKED"
      elif [[ "$mss" == CLEAN || "$mss" == UNSTABLE || "$mss" == HAS_HOOKS ]]; then label="ready"
      else                                        label="${(L)mss:-unknown}"
      fi

      if [[ "$mss" == BEHIND && -z "${rebased[$entry]}" ]]; then
        echo "merge: $repo — PR #$pr_num behind base, rebasing"
        if (cd "$dir" && eval rebase >/dev/null 2>&1); then
          rebased[$entry]=1
        else
          echo "merge: $repo — rebase failed (manual rebase needed)"
        fi
      elif [[ "$mss" != BEHIND ]]; then
        unset "rebased[$entry]"
      fi

      parts+=("$repo:$label")
      still+=("$entry")
    done
    remaining=("${still[@]}")
    if (( ${#remaining} )); then
      summary="merge ${parts[*]}"
      _merge_tab "$summary"
      echo "merge: $summary"
      sleep 15
    fi
  done

  _merge_tab ""
  echo "merge: all PRs merged — running wtd"
  wtd "$name"
}

# _wt_add <src-repo> <worktree-dest> <branch> <fallback-base>
# Adds a worktree at <dest> on a new <branch>, based on a freshly-fetched origin
# default branch. fetch only updates remote-tracking refs -- the root repo's
# working copy is untouched.
_wt_add() {
  emulate -L zsh
  local src="$1" wt="$2" branch="$3" fallback="$4" base
  [[ -d "$src/.git" ]] || { echo "wt: $src is not a git repo"; return 1; }
  base="$(git -C "$src" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)"; base="${base:-origin/$fallback}"
  echo "wt: ${src:t} <- fetching $base ..."
  git -C "$src" fetch origin "${base#origin/}"          || { echo "wt: fetch failed (${src:t})";    return 1; }
  git -C "$src" worktree add -b "$branch" "$wt" "$base" || { echo "wt: worktree failed (${src:t})"; return 1; }
}

# wt: spin up a fresh worktree dev env in a detached tmux session.
#   - no args     -> api + ship: copies api/.env & ship apps/**/.env.local, rewrites
#                    localhost:3000 -> the api portless url, then each repo runs
#                    `bun install && <dev server>` in its own tab.
#   - wt <repo>   -> a single worktree of ~/Desktop/repos/<repo>:
#                       * cxp: `bun install && bun dev` in its frontend/ and api/
#                              subfolders, each in its own tab.
#                       * any other repo: no setup, just the session.
#   - always: new random-named folder (wt-*) under ~/Desktop/repos/worktrees, new branch
#     named after the folder (off a freshly-fetched origin default). The tmux session is
#     named after the folder and left running detached -- attach later with `wta`.
wt() {
  emulate -L zsh
  local repo_arg="$1"
  local ROOT="$HOME/Desktop/repos/worktrees"

  command -v tmux >/dev/null    || { echo "wt: tmux not installed (brew install tmux)"; return 1; }
  command -v openssl >/dev/null || { echo "wt: openssl not found"; return 1; }

  local NAME="wt-$(openssl rand -hex 3)"
  local DEST="$ROOT/$NAME"
  echo "wt: creating '$NAME' -> $DEST"
  mkdir -p "$DEST" || return 1

  if [[ -z "$repo_arg" ]]; then
    ###### default: api + ship ######
    local API_SRC="$HOME/Desktop/repos/api"  SHIP_SRC="$HOME/Desktop/repos/ship"
    local API_WT="$DEST/api"  SHIP_WT="$DEST/ship"
    local API_URL="https://$NAME.api.localhost"   # portless prepends the branch name in worktrees

    _wt_add "$API_SRC"  "$API_WT"  "$NAME" develop || return 1
    _wt_add "$SHIP_SRC" "$SHIP_WT" "$NAME" main    || return 1

    # Copy gitignored env files (they don't travel with the worktree).
    if [[ -f "$API_SRC/.env" ]]; then
      cp "$API_SRC/.env.local" "$API_WT/.env"
    else
      echo "wt: warning: $API_SRC/.env not found"
    fi

    local f rel
    while IFS= read -r f; do
      rel="${f#$SHIP_SRC/}"
      mkdir -p "$SHIP_WT/${rel:h}"
      cp "$f" "$SHIP_WT/$rel"
    done < <(find "$SHIP_SRC/apps" -name .env.local -type f)

    # Point ship's API url at the api worktree's portless url.
    while IFS= read -r f; do
      sed -i '' -E "s#https?://localhost:3000#$API_URL#g" "$f"
    done < <(find "$SHIP_WT/apps" -name .env.local -type f)

    # tmux: install + dev server in each tab; land in a shell tab at the folder.
    tmux new-session -d -s "$NAME" -n shell -c "$DEST"
    tmux new-window     -t "$NAME" -n api   -c "$API_WT"
    tmux send-keys      -t "${NAME}:api"  'bun install && bun migration:run && bun run start:dev-fastest:portless' C-m
    tmux new-window     -t "$NAME" -n ship  -c "$SHIP_WT"
    tmux send-keys      -t "${NAME}:ship" 'bun install && bun run dev:all:portless' C-m
    tmux select-window  -t "${NAME}:shell"
    echo "wt: api -> $API_URL"
  else
    ###### single repo ######
    local SRC="$HOME/Desktop/repos/$repo_arg"
    local WT="$DEST/$repo_arg"
    _wt_add "$SRC" "$WT" "$NAME" main || return 1

    if [[ "$repo_arg" == cxp ]]; then
      # cxp's gitignored env files live in subfolders -- copy them into the worktree.
      [[ -f "$SRC/api/.env" ]]            && cp "$SRC/api/.env"             "$WT/api/.env"
      [[ -f "$SRC/frontend/.env.local" ]] && cp "$SRC/frontend/.env.local"  "$WT/frontend/.env.local"
    fi

    tmux new-session -d -s "$NAME" -n shell -c "$WT"
    if [[ "$repo_arg" == cxp ]]; then
      # cxp is one workspace -- `bun install` from any subfolder installs the whole
      # repo. So install ONCE (in the first existing subfolder's tab) and have the
      # other tab wait for it to finish, then both run `bun dev`. The flag lives
      # outside the worktree so `pr`'s `git add -A` never picks it up.
      local subs=(frontend api) sub installer="" flag="$DEST/.cxp-installed"
      for sub in $subs; do [[ -d "$WT/$sub" ]] && { installer="$sub"; break; }; done
      for sub in $subs; do
        if [[ ! -d "$WT/$sub" ]]; then
          echo "wt: warning: $repo_arg/$sub not found, skipping its tab"
          continue
        fi
        tmux new-window -t "$NAME" -n "$sub" -c "$WT/$sub"
        if [[ "$sub" == "$installer" ]]; then
          tmux send-keys -t "${NAME}:${sub}" "bun install && touch '$flag' && bun dev" C-m
        else
          tmux send-keys -t "${NAME}:${sub}" "echo 'waiting for bun install...'; until [ -f '$flag' ]; do sleep 1; done; bun dev" C-m
        fi
      done
    fi
    tmux select-window -t "${NAME}:shell"
  fi

  # Leave the session running detached in the background; attach later with `wta $NAME`.
  echo "wt: session '$NAME' running in the background -- attach with: wta $NAME"
  cd "$DEST"
}

# wta <name>: attach to a wt-* worktree's (detached) tmux session.
#   - wta            -> derive the name from the worktree dir you're standing in
#   - wta wt-abc123  -> attach to that session by name
wta() {
  emulate -L zsh
  local wt_root="$HOME/Desktop/repos/worktrees"
  local name="$1"
  if [[ -z "$name" ]]; then
    if [[ "$PWD/" == "$wt_root/"* ]]; then
      name="${PWD#$wt_root/}"; name="${name%%/*}"
    else
      echo "wta: usage: wta <wt-name>  (or run from inside a worktree)"; return 1
    fi
  fi
  command -v tmux >/dev/null || { echo "wta: tmux not installed"; return 1; }
  tmux has-session -t "$name" 2>/dev/null || { echo "wta: no tmux session '$name'"; return 1; }
  if [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "$name"
  else
    tmux attach -t "$name"
  fi
}

# wtd <name>: kill a wt-* worktree's tmux session and delete its directory.
#   - wtd            -> derive the name from the worktree dir you're standing in
#   - wtd wt-abc123  -> tear down that worktree by name
wtd() {
  emulate -L zsh
  local wt_root="$HOME/Desktop/repos/worktrees"
  local name="$1"
  if [[ -z "$name" ]]; then
    if [[ "$PWD/" == "$wt_root/"* ]]; then
      name="${PWD#$wt_root/}"; name="${name%%/*}"
    else
      echo "wtd: usage: wtd <wt-name>  (or run from inside a worktree)"; return 1
    fi
  fi
  local dest="$wt_root/$name"

  if command -v tmux >/dev/null && tmux has-session -t "$name" 2>/dev/null; then
    tmux kill-session -t "$name" && echo "wtd: killed tmux session '$name'"
  fi

  if [[ -d "$dest" ]]; then
    # Don't delete the directory out from under the current shell.
    [[ "$PWD/" == "$dest/"* ]] && cd "$wt_root"
    # Deregister each repo's worktree so the source repo stays clean. This deletes the
    # tree inline, so it can take ~30s on ship/api (node_modules = lots of tiny files).
    local sub
    for sub in "$dest"/*(/N); do
      git -C "$sub" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
        && git -C "$sub" worktree remove --force "$sub" 2>/dev/null
    done
    rm -rf "$dest" && echo "wtd: removed $dest"
    exit
  else
    echo "wtd: $dest not found"
  fi
}

# Open a ship app's portless URL for the worktree you're currently in.
# In a `wt` worktree the url is https://<branch>.<app>.localhost, where the
# branch == the worktree folder name; outside one it falls back to https://<app>.localhost.
portless-open() {
  emulate -L zsh
  local app="$1"
  local wt_root="$HOME/Desktop/repos/worktrees"
  local prefix="" url
  if [[ "$PWD/" == "$wt_root/"* ]]; then
    prefix="${PWD#$wt_root/}"   # e.g. wt-2f1bb1/ship/apps/...
    prefix="${prefix%%/*}"      # -> wt-2f1bb1
  fi
  if [[ -n "$prefix" ]]; then
    url="https://${prefix}.${app}.localhost"
  else
    url="https://${app}.localhost"
  fi
  echo "opening $url"
  open "$url"
}
backoffice() { portless-open support-portal }
portal()     { portless-open customer-portal }
checkout()   { portless-open customer-checkout }

alias rebase="git fetch && git rebase origin/HEAD && git push --force-with-lease"
alias gdiff="git diff origin/HEAD"
alias c="claude --dangerously-skip-permissions"
alias cc="claude --dangerously-skip-permissions --continue"
alias v=nvim
