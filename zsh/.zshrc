export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:$PATH"

typeset -i HISTSIZE=16384
typeset -i SAVEHIST=16384
typeset HISTFILE="$HOME/suk/.zsh_history"
mkdir -p $(dirname "$HISTFILE")

setopt HIST_FCNTL_LOCK
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY

unsetopt APPEND_HISTORY
unsetopt EXTENDED_HISTORY
unsetopt HIST_EXPIRE_DUPS_FIRST
unsetopt HIST_FIND_NO_DUPS
unsetopt HIST_IGNORE_ALL_DUPS
unsetopt HIST_SAVE_NO_DUPS

# Install zinit
typeset ZINIT_HOME="$HOME/.local/share/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "$ZINIT_HOME/zinit.zsh"

zinit light zsh-users/zsh-completions
zinit light Aloxaf/fzf-tab
zinit light zdharma-continuum/fast-syntax-highlighting

autoload -Uz compinit
compinit
zinit cdreplay -q

alias vi=nvim
alias vim=nvim
alias view=nvim --

alias ls='lsd'
alias la='ls -A'
alias ll='ls -l'
alias lla='ls -lA'
alias llt='ls -l --tree'
alias lt='ls --tree'

alias zj=zellij
function zj-rt { zj ac rename-tab "$@" }

function skull { printf '\u2620' }

function yy() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXX")"
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(<"$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

(( $+commands[fzf] )) && source <(fzf --zsh)

PROMPT='%B%F{12}%~%f%b %B%F{#FFEA00}%f%b '
