# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Environment
export GOROOT=/usr/local/opt/go/libexec
export GOPATH=$HOME/go
export GO111MODULE=on

export JAVA_HOME=$(/usr/libexec/java_home)
export ANDROID_HOME=/Users/ricoberger/Library/Android/sdk
export ANDROID_NDK_HOME=/Users/ricoberger/Library/Android/sdk/ndk/21.1.6352462

export VAULT_ADDR=http://127.0.0.1:8200

export RUST_SRC_PATH=/Users/ricoberger/.rustup/toolchains/stable-x86_64-apple-darwin/lib/rustlib/src/rust/src

# Path
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin:$HOME/.krew/bin

# Set Python3 as default
alias python=/usr/local/opt/python@3/bin/python3
alias pip=/usr/local/opt/python@3/bin/pip3

# Use Vim from brew
alias vim="/usr/local/bin/vim"
alias vi="/usr/local/bin/vim"

# Path to your oh-my-zsh installation.
export ZSH="/Users/ricoberger/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in ~/.oh-my-zsh/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS=true

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in ~/.oh-my-zsh/plugins/*
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git helm kube-ps1 kubectl minikube osx vscode zsh-autosuggestions)

source $ZSH/oh-my-zsh.sh

fpath+=($ZSH/plugins/docker)
autoload -U compinit && compinit

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# powerlevel10k configuration
zsh_custom_kube_ps1(){
  echo -n "$(_kube_ps1_symbol)$KUBE_PS1_SEPERATOR$KUBE_PS1_CONTEXT$KUBE_PS1_DIVIDER$KUBE_PS1_NAMESPACE"
}

POWERLEVEL9K_CUSTOM_KUBE_PS1='zsh_custom_kube_ps1'

POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(context dir vcs)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status history custom_kube_ps1 time)

POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR=$'\uE0B0'
POWERLEVEL9K_RIGHT_SEGMENT_SEPARATOR=$'\uE0B2'

POWERLEVEL9K_CONTEXT_BACKGROUND="black"
POWERLEVEL9K_CONTEXT_FOREGROUND="white"
POWERLEVEL9K_HISTORY_BACKGROUND="black"
POWERLEVEL9K_HISTORY_FOREGROUND="white"
POWERLEVEL9K_TIME_BACKGROUND="black"
POWERLEVEL9K_TIME_FOREGROUND="white"
POWERLEVEL9K_TIME_FORMAT="%D{%Y-%m-%d %H:%M:%S}"
POWERLEVEL9K_CUSTOM_KUBE_PS1_BACKGROUND="black"
POWERLEVEL9K_CUSTOM_KUBE_PS1_FOREGROUND="white"

# Key bindings
bindkey -v
bindkey "^[OA" up-line-or-beginning-search
bindkey "^[OB" down-line-or-beginning-search
bindkey "^[OC" forward-char
bindkey "^[OD" backward-char
bindkey "^[[A" up-line-or-beginning-search
bindkey "^[[B" down-line-or-beginning-search
bindkey "^R" history-incremental-search-backward
bindkey "^[[1;3C" forward-word
bindkey "^[[1;3D" backward-word
bindkey "^[[1;3A" beginning-of-line
bindkey "^[[1;3B" end-of-line
bindkey "^[[3~" delete-char
bindkey "^[^?" backward-kill-word

# Custom aliases and functions

alias chrome='/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --remote-debugging-port=9222'
alias gg1="git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(auto)%d%C(reset)' --all"
alias gg2="git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset)%C(auto)%d%C(reset)%n''          %C(white)%s%C(reset) %C(dim white)- %an%C(reset)' --all"
alias gg3="git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset) %C(bold cyan)(committed: %cD)%C(reset) %C(auto)%d%C(reset)%n''          %C(white)%s%C(reset)%n''          %C(dim white)- %an <%ae> %C(reset) %C(dim white)(committer: %cn <%ce>)%C(reset)' --all"

killport() { lsof -i :$1 | awk '{print $2}' | tail -n 1 | xargs kill; }
listtargz() { tar -ztvf $1; }
mkcd() { NAME=$1; mkdir -p "$NAME"; cd "$NAME"; }
numfiles() { N="$(ls $@ | wc -l)"; echo "$N files in ${@: -1}"; }
ts() { tmux attach -t main || tmux new -s main; }
targz() { tar -zcvf $1.tar.gz ${@:2}; rm -r ${@:2}; }
untargz() { tar -zxvf $1; rm -r $1; }
up() { DEEP=$1; for i in $(seq 1 ${DEEP:-"1"}); do cd ../; done; }
webshare() { if [[ $(python --version 2>&1) == *2\.* ]]; then python -m SimpleHTTPServer $@; else python -m http.server $@; fi; }

vaultedit() {
  TMPFILE=`mktemp /tmp/vaultsecret.XXXXXXXXX`
  vault kv get -format=json $@ | jq .data.data > ${TMPFILE};
  vim -c 'set ft=json' ${TMPFILE} < /dev/tty > /dev/tty
  vault kv put $@ @${TMPFILE}
  rm ${TMPFILE}
}

vaultcreate() {
  TMPFILE=`mktemp /tmp/vaultsecret.XXXXXXXXX`
  vim -c 'set ft=json' ${TMPFILE} < /dev/tty > /dev/tty
  vault kv put $@ @${TMPFILE}
  rm ${TMPFILE}
}
