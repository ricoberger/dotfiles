# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Go
export GOROOT=/usr/local/opt/go/libexec
export GOPATH=$HOME/go
export GO111MODULE=on

# Java
export JAVA_HOME=$(/usr/libexec/java_home)
export ANDROID_HOME=/Users/ricoberger/Library/Android/sdk

# Path
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin:$HOME/Library/Trigger\ Toolkit/

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
plugins=(git helm kube-ps1 kubectl minikube osx vscode)

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

# Custom aliases and functions

# Open chrome with remote debugging port enabled
alias chrome='/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --remote-debugging-port=9222'

# Kill a process running on port xxxx
# Usage: killport 8080
killport() { lsof -i :$1 | awk '{print $2}' | tail -n 1 | xargs kill; }

# List content of .tar.gz archive
# Usage: listtargz archive.tar.gz
listtargz() { tar -ztvf $1; }

# Make a new folder and cd into it
# Usage: mkcd test
mkcd() { NAME=$1; mkdir -p "$NAME"; cd "$NAME"; }

# Display process complete message (for long running processes)
notify() {
  cmd=$@ # Somehow interpolate $@ directly doesn't work.
  $@ && say 'Process Completed!' && osascript -e "display notification \"$cmd\" with title \"Process Completed!\""
}

# Get number of files in a directory
# Usage: numfiles folder
numfiles() { N="$(ls $@ | wc -l)"; echo "$N files in ${@: -1}"; }

# Attach to / create tmux session
ts() { tmux attach -t main || tmux new -s main; }

# Create .tar.gz file
# Usage: targz archive file*
# Usage: targz archive file1 file2 file3
targz() { tar -zcvf $1.tar.gz ${@:2}; rm -r ${@:2}; }

# Extract .tar.gz file
# Usage: untargz archive.tar.gz
untargz() { tar -zxvf $1; rm -r $1; }

# Preserve your fingers from cd ..; cd ..; cd..; cd..;
# Usage: up 3
up() { DEEP=$1; for i in $(seq 1 ${DEEP:-"1"}); do cd ../; done; }

webshare() {
  if [[ $(python --version 2>&1) == *2\.* ]]; then
    python -m SimpleHTTPServer $@
  else
    python -m http.server $@
  fi
}
