# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

[ -e "$HOME/.antigen.zsh" ] || curl -L -s git.io/antigen > ~/.antigen.zsh
source ~/.antigen.zsh

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

export COLORTERM=truecolor

zstyle ':filter-select' hist-find-no-dups yes

# Keep command history across shell sessions.
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

export NODE_OPTIONS=--no-network-family-autoselection

# bun completions
[ -s "~/.bun/_bun" ] && source "~/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
# Added by dbt Fusion extension (ensure dbt binary dir on PATH)
if [[ ":$PATH:" != *":~/.local/bin:"* ]]; then
  export PATH=~/.local/bin:"$PATH"
fi
# Added by dbt Fusion extension
alias dbtf=~/.local/bin/dbt

# Copy stdin to the terminal clipboard using OSC 52.
osccp() {
  printf '\033]52;c;%s\a' "$(base64 | tr -d '\n')"
}

# _base_ref <repo-dir> <repo-name> [fallback]: use the remote default branch.
_base_ref() {
  emulate -L zsh
  local dir="$1" repo="$2" fallback="${3:-main}" base
  base="$(git -C "$dir" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)"
  echo "${base:-origin/$fallback}"
}

# pr: from any subdir of a `wt` worktree, commit+push every repo in it and open PRs.
#   - iterates each repo folder in the worktree root
#   - for each repo: git add -A, commit (msg always "commit"), push
#   - skips a repo with no changes (nothing ahead of its base branch)
#   - if a repo has no open PR yet: uses the args as the PR title (or prompts ONCE if no args),
#     and creates the PR(s) as drafts with `gh pr create --draft` (prints the URL, does not open a browser)
#   - if a PR already exists: just commits & pushes (no prompt)
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

    base="$(_base_ref "$dir" "$repo")"
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
    base="$(_base_ref "$dir" "${dir:t}")"
    if url="$(cd "$dir" && gh pr create --draft --base "${base#origin/}" --title "$title" --body "" 2>/dev/null)" && [[ "$url" == https://* ]]; then
      echo "pr: ${dir:t} — created $url"
    else
      echo "pr: ${dir:t} — gh pr create failed"
    fi
  done
}

# Set the terminal window/tab title. OSC 0 sets both window and icon/tab title
# (OSC 1 alone is ignored by many modern terminals, which fall back to showing the
# running command — hence "merge").
_wt_tab() { printf '\033]0;%s\007' "$1" }

# OSC 8 hyperlink: terminals that support it render $2 as a clickable link to
# $1; others just show the plain text. Trailing newline included.
_osc8() { printf '\033]8;;%s\033\\%s\033]8;;\033\\\n' "$1" "$2" }

# merge: from inside a `wt` worktree, mark every repo's open PR ready (undraft),
#   enable auto-merge on each, wait for them all to merge, then run `wtd` to tear the worktree down.
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

    (cd "$dir" && gh pr ready "$pr_num" >/dev/null 2>&1) || true

    if (cd "$dir" && gh pr merge "$pr_num" --auto "$method" >/dev/null 2>&1); then
      echo "merge: $repo — auto-merge enabled on PR #$pr_num"
    else
      echo "merge: $repo — gh pr merge failed on PR #$pr_num"; return 1
    fi
    prs+=("$dir:$pr_num")
  done < <(find "$root" -mindepth 1 -maxdepth 1 -type d | sort)

  (( ${#prs} )) || { echo "merge: no PRs to wait on"; return 1; }

  echo "merge: waiting for ${#prs} PR(s) to merge…"
  local entry remaining=("${prs[@]}") mss rd c_failed c_pending label summary base head behind url
  local -a info
  typeset -A rebased
  while (( ${#remaining} )); do
    typeset -a still parts
    still=(); parts=()
    for entry in "${remaining[@]}"; do
      dir="${entry%%:*}"; pr_num="${entry##*:}"; repo="${dir:t}"
      info=("${(@f)$(cd "$dir" && gh pr view "$pr_num" --json state,mergeStateStatus,reviewDecision,statusCheckRollup,baseRefName,headRefName,url -q '
        .state,
        (.mergeStateStatus // ""),
        (.reviewDecision // ""),
        ([.statusCheckRollup[]? | select(.conclusion=="FAILURE" or .conclusion=="CANCELLED" or .conclusion=="TIMED_OUT" or .state=="FAILURE" or .state=="ERROR")] | length),
        ([.statusCheckRollup[]? | select(
            (.status != null and .status != "COMPLETED")
            or (.state == "PENDING" or .state == "EXPECTED")
         )] | length),
        .baseRefName,
        .headRefName,
        .url
      ' 2>/dev/null)}")
      state="${info[1]}"; mss="${info[2]}"; rd="${info[3]}"; c_failed="${info[4]:-0}"; c_pending="${info[5]:-0}"
      base="${info[6]}"; head="${info[7]}"; url="${info[8]}"

      # Is the branch actually out of date? GitHub's mergeStateStatus only ever
      # reports ONE status, and BLOCKED/UNSTABLE (pending required checks, etc.)
      # outrank BEHIND — so a PR can be behind its base while mss never says so.
      # Check the real commit delta instead.
      behind=0
      if [[ -n "$base" && -n "$head" ]]; then
        behind="$(cd "$dir" && gh api "repos/{owner}/{repo}/compare/${base}...${head}" --jq '.behind_by' 2>/dev/null)"
        behind="${behind:-0}"
      fi

      case "$state" in
        MERGED) _osc8 "$url" "merge: $repo — PR #$pr_num merged"; continue ;;
        CLOSED) echo "merge: $repo — PR #$pr_num closed without merging"; _wt_tab ""; return 1 ;;
      esac

      # Pick the single most actionable status to show.
      # UPPERCASE = user action required; lowercase = just waiting.
      if   (( c_failed > 0 ));               then label="CHECKS-FAILED"
      elif [[ "$mss" == DIRTY ]];            then label="CONFLICTS"
      elif [[ "$rd"  == CHANGES_REQUESTED ]];then label="REVIEW-CHANGES-REQUESTED"
      elif [[ "$rd"  == REVIEW_REQUIRED ]];  then label="REVIEW-REQUIRED"
      elif (( behind > 0 ));                 then label="rebasing"
      elif (( c_pending > 0 ));              then label="checks-pending"
      elif [[ "$mss" == BLOCKED ]];          then label="BLOCKED"
      elif [[ "$mss" == CLEAN || "$mss" == UNSTABLE || "$mss" == HAS_HOOKS ]]; then label="ready"
      else                                        label="${(L)mss:-unknown}"
      fi

      # Rebase whenever the branch is behind its base — but not on real merge
      # conflicts (DIRTY), where `git rebase` would stop half-done. The `rebased`
      # flag debounces so we don't re-rebase every poll while GitHub catches up.
      if (( behind > 0 )) && [[ "$mss" != DIRTY && -z "${rebased[$entry]}" ]]; then
        echo "merge: $repo — PR #$pr_num behind base by $behind, rebasing onto $base"
        # Rebase onto the PR's real base, not the `rebase` alias's origin/HEAD —
        # they differ wherever origin/HEAD lags the branch we actually PR into.
        if (cd "$dir" && git fetch origin "$base" >/dev/null 2>&1 \
              && git rebase "origin/$base" >/dev/null 2>&1 \
              && git push --force-with-lease >/dev/null 2>&1); then
          rebased[$entry]=1
        else
          echo "merge: $repo — rebase failed (manual rebase needed)"
        fi
      elif (( behind == 0 )); then
        unset "rebased[$entry]"
      fi

      parts+=("$repo:$label")
      still+=("$entry")
    done
    remaining=("${still[@]}")
    if (( ${#remaining} )); then
      summary="merge ${parts[*]}"
      _wt_tab "$summary"
      echo "merge: $summary"
      sleep 15
    fi
  done

  _wt_tab ""
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
  base="$(_base_ref "$src" "${src:t}" "$fallback")"
  echo "wt: ${src:t} <- fetching $base ..."
  # Only this one branch: an explicit refspec skips every other remote branch, and
  # --no-tags stops git pulling in tags that happen to point into its history.
  git -C "$src" fetch --no-tags origin "+refs/heads/${base#origin/}:refs/remotes/$base" \
                                                        || { echo "wt: fetch failed (${src:t})";    return 1; }
  git -C "$src" worktree add -b "$branch" "$wt" "$base" || { echo "wt: worktree failed (${src:t})"; return 1; }
}

# _wt_session <name> <dest>: open a shell for an existing worktree.
_wt_session() {
  emulate -L zsh
  local name="$1" dest="$2" wt
  wt="$(find "$dest" -mindepth 1 -maxdepth 1 -type d ! -name '.*' | head -1)"
  tmux new-session -d -s "$name" -n shell -c "${wt:-$dest}"
}

# wt <repo>: create a worktree and detached tmux shell from the remote default.
wt() {
  emulate -L zsh
  local repo_arg="$1"
  [[ -n "$repo_arg" && "$repo_arg" != */* && "$repo_arg" != . && "$repo_arg" != .. ]] \
    || { echo "wt: usage: wt <repo>"; return 1; }
  command -v tmux >/dev/null || { echo "wt: tmux not installed (brew install tmux)"; return 1; }
  command -v openssl >/dev/null || { echo "wt: openssl not found"; return 1; }
  local src="$HOME/Desktop/repos/$repo_arg"
  [[ -d "$src/.git" ]] || { echo "wt: $src is not a git repo"; return 1; }
  local name="wt-$(openssl rand -hex 3)"
  local dest="$HOME/Desktop/repos/worktrees/$name"
  mkdir -p "$dest" || return 1
  _wt_add "$src" "$dest/$repo_arg" "$name" main || return 1
  _wt_session "$name" "$dest" || return 1
  echo "wt: session '$name' running in the background -- attach with: wta $name"
  cd "$dest/$repo_arg"
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

# wtr <name>: (re)start the detached tmux dev session for an EXISTING worktree.
#   For after a reboot / `tmux kill-server`, or when you killed just the session
#   but kept the worktree. Rebuilds the same tabs `wt` would, inferring the
#   layout from the worktree dir; does NOT touch git or env files.
#   - wtr            -> derive the name from the worktree dir you're standing in
#   - wtr wt-abc123  -> restart that worktree's session by name
wtr() {
  emulate -L zsh
  local wt_root="$HOME/Desktop/repos/worktrees"
  local name="$1"
  if [[ -z "$name" ]]; then
    if [[ "$PWD/" == "$wt_root/"* ]]; then
      name="${PWD#$wt_root/}"; name="${name%%/*}"
    else
      echo "wtr: usage: wtr <wt-name>  (or run from inside a worktree)"; return 1
    fi
  fi
  command -v tmux >/dev/null || { echo "wtr: tmux not installed"; return 1; }

  local dest="$wt_root/$name"
  [[ -d "$dest" ]] || { echo "wtr: no worktree dir '$dest'"; return 1; }
  if tmux has-session -t "$name" 2>/dev/null; then
    echo "wtr: session '$name' already running -- attach with: wta $name"; return 1
  fi

  _wt_session "$name" "$dest"
  echo "wtr: session '$name' running in the background -- attach with: wta $name"
}

# wtd <name>: kill a wt-* worktree's tmux session and delete its directory.
#   - wtd               -> derive the name from the worktree dir you're standing in
#   - wtd wt-abc123     -> tear down that worktree by name
#   - wtd --keep-shell  -> don't `exit` afterwards (used by `merge` when a cutover is owed)
wtd() {
  emulate -L zsh
  local wt_root="$HOME/Desktop/repos/worktrees"
  local name="" keep_shell=0 arg
  for arg in "$@"; do
    case "$arg" in
      --keep-shell) keep_shell=1 ;;
      *) name="$arg" ;;
    esac
  done
  if [[ -z "$name" ]]; then
    if [[ "$PWD/" == "$wt_root/"* ]]; then
      name="${PWD#$wt_root/}"; name="${name%%/*}"
    else
      echo "wtd: usage: wtd <wt-name>  (or run from inside a worktree)"; return 1
    fi
  fi
  local dest="$wt_root/$name"

  # Stop dev servers before killing the session. tmux kill-session only sends SIGHUP,
  # which nodemon treats as "restart" rather than "quit", so the dev server would
  # survive as an orphan holding its port. SIGTERM makes nodemon kill its child and exit.
  # Redirect output instead of using -q, which is not portable across pgrep versions.
  if pgrep -f "$dest/" >/dev/null; then
    pkill -TERM -f "$dest/"
    local i
    for i in {1..20}; do pgrep -f "$dest/" >/dev/null || break; sleep 0.25; done
    pgrep -f "$dest/" >/dev/null && pkill -KILL -f "$dest/"
    echo "wtd: stopped processes under $dest"
  fi

  if command -v tmux >/dev/null && tmux has-session -t "$name" 2>/dev/null; then
    tmux kill-session -t "$name" && echo "wtd: killed tmux session '$name'"
  fi

  if [[ -d "$dest" ]]; then
    # Don't delete the directory out from under the current shell.
    [[ "$PWD/" == "$dest/"* ]] && cd "$wt_root"
    # Deregister each repo's worktree so the source repo stays clean. This deletes the
    # tree inline, so it can take ~30s on large repos (node_modules = lots of tiny files).
    local sub
    for sub in "$dest"/*(/N); do
      git -C "$sub" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
        && git -C "$sub" worktree remove --force "$sub" 2>/dev/null
    done
    rm -rf "$dest" && echo "wtd: removed $dest"
    (( keep_shell )) || exit 0
  else
    echo "wtd: $dest not found"
  fi
}

# Open an app's portless URL for the worktree you're currently in.
# In a `wt` worktree the url is https://<branch>.<app>.localhost, where the
# branch == the worktree folder name; outside one it falls back to https://<app>.localhost.
# With PORTLESS_TAILSCALE=1, open the matching route's shared URL instead.
# Try the local opener; over SSH or on failure, print a clickable OSC 8 link.
portless-open() {
  emulate -L zsh
  local app="$1"
  local wt_root="$HOME/Desktop/repos/worktrees"
  local prefix="" url
  if [[ "$PWD/" == "$wt_root/"* ]]; then
    prefix="${PWD#$wt_root/}"   # e.g. wt-2f1bb1/project/src/...
    prefix="${prefix%%/*}"      # -> wt-2f1bb1
  fi
  if [[ -n "$prefix" ]]; then
    url="https://${prefix}.${app}.localhost"
  else
    url="https://${app}.localhost"
  fi
  if [[ "${PORTLESS_TAILSCALE:-}" == 1 ]]; then
    local routes hostname="${url#https://}"
    if (( $+commands[portless] )); then
      routes=$(NO_COLOR=1 FORCE_COLOR=0 portless list) || return
    else
      routes=$(NO_COLOR=1 FORCE_COLOR=0 bunx portless list) || return
    fi
    url=$(print -r -- "$routes" | awk -v hostname="$hostname" '
      $2 == "->" {
        host = $1
        sub(/^https?:\/\//, "", host)
        sub(/:[0-9]+$/, "", host)
        matched = (host == hostname)
      }
      matched && ($1 == "tailscale:" || $1 == "funnel:") {
        print $2
        exit
      }
    ')
    if [[ -z "$url" ]]; then
      print -u2 "portless-open: no Tailscale URL for $hostname; start the app with PORTLESS_TAILSCALE=1"
      return 1
    fi
  fi
  if [[ -z "${SSH_CONNECTION:-}${SSH_CLIENT:-}${SSH_TTY:-}" ]] && open "$url" 2>/dev/null; then
    return 0
  fi
  _osc8 "$url" "Cmd-click to open: $url"
}
alias rebase="git fetch && git rebase origin/HEAD && git push --force-with-lease"
alias gdiff="git diff origin/HEAD"
alias c="codex --dangerously-bypass-approvals-and-sandbox"
alias cc="codex resume --dangerously-bypass-approvals-and-sandbox"
alias v=nvim
alias cdr="cd ~/Desktop/repos && cd"

# Machine-local settings and secrets (e.g. NODE_AUTH_TOKEN) -- not tracked.
[[ -r ~/.zshrc.local ]] && source ~/.zshrc.local


export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# add Pulumi to the PATH
export PATH=$PATH:$HOME/.pulumi/bin

alias cme="kinit bgeorge@INT.BOBBYGEORGE.DEV && ssh -t cme-devserver01.int.bobbygeorge.dev tmux -u new -As tabs"

alias k="kubectl"
alias watchk="watch kubectl"
kexec() {
        kubectl exec -ti "$1" -- bash
}

compctl -K _kexec_pods kexec
_kexec_pods() {
  reply=($(kubectl get pods --no-headers -o custom-columns=":metadata.name" 2>/dev/null))
}

function zaw-src-kubectl-context() {
    candidates=($(kubectl config get-contexts -o name))
    actions=(kubectl-context)
}

function kubectl-context(){
    BUFFER="kubectl config use-context $1"
    zle accept-line
}

zaw-register-src -n kubectl-context zaw-src-kubectl-context
bindkey '^k' zaw-kubectl-context

function zaw-src-kubectl-namespace() {
    candidates=($(kubectl get namespace --no-headers -o custom-columns=":metadata.name"))
    actions=(kubectl-namespace)
}

function kubectl-namespace(){
    BUFFER="kubectl config set-context --current --namespace=$1"
    zle accept-line
}

zaw-register-src -n kubectl-namespace zaw-src-kubectl-namespace
bindkey '^l' zaw-kubectl-namespace
