# Ghostty
cp -r $(pwd)/.config/ghostty ~/.config

# zsh
cp $(pwd)/.zshrc ~/.zshrc

# Starship
cp $(pwd)/.config/starship.toml ~/.config/starship.toml

# SSH
mkdir -p ~/.ssh
cp -r $(pwd)/.ssh/config ~/.ssh/config

# tmux
mkdir -p ~/.tmux/plugins
git -C ~/.tmux/plugins/tpm pull || git clone git@github.com:tmux-plugins/tpm.git ~/.tmux/plugins/tpm
cp $(pwd)/.tmux.conf ~/.tmux.conf

# Git
cp $(pwd)/.gitconfig ~/.gitconfig
cp $(pwd)/.gitconfig-staffbase ~/.gitconfig-staffbase
cp $(pwd)/.gitignore ~/.gitignore

# GitHub
if command -v gh &> /dev/null; then
  gh extension install dlvhdr/gh-dash
fi
cp $(pwd)/.config/gh-dash/config.yml ~/.config/gh-dash/config.yml

# Neovim
mkdir -p ~/.config/nvim
cp $(pwd)/.config/nvim/init.lua ~/.config/nvim/init.lua
cp -r $(pwd)/.config/nvim/lua ~/.config/nvim/

# btop
cp -r $(pwd)/.config/btop ~/.config

# yazi
cp -r $(pwd)/.config/yazi ~/.config

# Binaries
cp -r $(pwd)/.bin ~/
