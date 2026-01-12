################################################################################
### ENVIRONMENT VARIABLES
################################################################################

export HOMEBREW_NO_ANALYTICS=1
export DISABLE_AUTO_UPDATE=true
export EDITOR="nvim"
export KUBE_EDITOR="nvim"
export GOROOT=/opt/homebrew/opt/go/libexec
export GOPATH=$HOME/go
export GO111MODULE=on
export ANDROID_HOME=/Users/ricoberger/Library/Android/sdk
export ANDROID_NDK_HOME=/Users/ricoberger/Library/Android/sdk/ndk/27.0.12077973
export NODE_OPTIONS="--dns-result-order=ipv4first"
export MANPAGER="nvim +Man!"

path=(
  /opt/homebrew/opt/kubectl/bin
  $HOME/.docker/bin
  $GOROOT/bin
  $GOPATH/bin
  $HOME/.local/bin
  $HOME/.local/bin/nvim-nightly/bin
  $HOME/.krew/bin
  $HOME/flutter/bin
  $HOME/.pub-cache/bin
  /opt/homebrew/opt/openjdk/bin
  $HOME/.istioctl/bin
  $HOME/.cargo/bin
  /opt/homebrew/opt/python@3.10/libexec/bin
  $path
)



################################################################################
### ZSH CONFIGURATION
################################################################################

# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download Zinit, if it's not there yet
if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

# Add in zsh plugins
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# Load completions
autoload -Uz compinit && compinit

zinit cdreplay -q

# Keybindings
bindkey -v
bindkey "^[[A" history-beginning-search-backward
bindkey "^[[B" history-beginning-search-forward
bindkey "^[[1;3C" vi-forward-word
bindkey "^[[1;3D" vi-backward-word
bindkey "^[[1;3A" beginning-of-line
bindkey "^[[1;3B" end-of-line

# History
HISTSIZE=10000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Use Ctrl+x + Ctrl+e to edit the command line in $EDITOR
autoload -z edit-command-line
zle -N edit-command-line
bindkey "^X^E" edit-command-line

# Hidden files
setopt globdots

# Allow comments in interactive shells
setopt interactive_comments

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:*' fzf-flags --color=bg+:#363a4f,bg:#24273a,spinner:#f4dbd6,hl:#ed8796 --color=fg:#cad3f5,header:#ed8796,info:#c6a0f6,pointer:#f4dbd6 --color=marker:#f4dbd6,fg+:#cad3f5,prompt:#c6a0f6,hl+:#ed8796



################################################################################
### FZF
################################################################################

eval "$(fzf --zsh)"
export FZF_DEFAULT_COMMAND='fd --full-path --hidden --color never --type f --exclude .git'
export FZF_DEFAULT_OPTS='--color=bg+:#363a4f,bg:#24273a,spinner:#f4dbd6,hl:#ed8796 --color=fg:#cad3f5,header:#ed8796,info:#c6a0f6,pointer:#f4dbd6 --color=marker:#f4dbd6,fg+:#cad3f5,prompt:#c6a0f6,hl+:#ed8796'



################################################################################
### FZF
################################################################################

export BAT_THEME="Catppuccin Macchiato"



################################################################################
### ALIAS
################################################################################
# alias vim="nvim"
# alias vi="nvim"
alias ls='ls --color'
alias la='ls -la --color'
alias watch='watch '
alias k='kubectl'
alias chrome='/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --remote-debugging-port=9222'
alias gg1="git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(auto)%d%C(reset)' --all"
alias gg2="git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset)%C(auto)%d%C(reset)%n''          %C(white)%s%C(reset) %C(dim white)- %an%C(reset)' --all"
alias gg3="git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset) %C(bold cyan)(committed: %cD)%C(reset) %C(auto)%d%C(reset)%n''          %C(white)%s%C(reset)%n''          %C(dim white)- %an <%ae> %C(reset) %C(dim white)(committer: %cn <%ce>)%C(reset)' --all"
alias ghd='gh dash'
alias y='yazi'



################################################################################
### FUNCTIONS
################################################################################

killport() { lsof -i :$1 | awk '{print $2}' | tail -n 1 | xargs kill; }
listtargz() { tar -ztvf $1; }
trash() { mv $@ ~/.Trash }
ts() { tmux attach -t main || tmux new -s main; }
tsn() { tmux attach -t $1 || tmux new -s $1; }
tp() { tmux popup -E "tmux attach -t popup || tmux new -s popup"; }
tdm() { tmux display-message $1; }
targz() { tar -zcvf $1.tar.gz ${@:2}; rm -r ${@:2}; }
untargz() { tar -zxvf $1; rm -r $1; }
webshare() { if [[ $(python --version 2>&1) == *2\.* ]]; then python -m SimpleHTTPServer $@; else python -m http.server $@; fi; }
websearch() { open -a "Safari" "https://www.google.com/search?q=$(omz_urlencode -P $@)&udm=14"; }

cdp() {
  REPOS=`find $HOME/Documents/GitHub -type d -maxdepth 2 -mindepth 2`
  cd $(echo "/Users/ricoberger/Desktop\n/Users/ricoberger/Documents\n/Users/ricoberger/Downloads\n$REPOS" | fzf)
}

ksecret() {
  kubectl get secret $@ -o go-template='{{range $k,$v := .data}}{{printf "%s: " $k}}{{if not $v}}{{$v}}{{else}}{{$v | base64decode}}{{end}}{{"\n"}}{{end}}'
}

vaultedit() {
  TMPFILE=`mktemp /tmp/vaultsecret.XXXXXXXXX`
  vault kv get -format=json $@ | jq .data.data > ${TMPFILE};
  nvim -c 'set ft=json' ${TMPFILE} < /dev/tty > /dev/tty
  vault kv put $@ @${TMPFILE}
  rm ${TMPFILE}
}

vaultcreate() {
  TMPFILE=`mktemp /tmp/vaultsecret.XXXXXXXXX`
  nvim -c 'set ft=json' ${TMPFILE} < /dev/tty > /dev/tty
  vault kv put $@ @${TMPFILE}
  rm ${TMPFILE}
}

# See https://yazi-rs.github.io/docs/quick-start#shell-wrapper
yy() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}



################################################################################
### STARSHIP
################################################################################

type starship_zle-keymap-select >/dev/null || \
  {
    eval "$(starship init zsh)"
  }
