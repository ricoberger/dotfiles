cd "$(dirname "$0")"

# Ghostty
echo "\n- Copy Ghostty Configuration"
mkdir -p ~/.config
cp -r $(pwd)/.config/ghostty ~/.config

# Zsh
echo "\n- Copy Zsh Configuration"
cp $(pwd)/.zshenv ~/.zshenv
cp $(pwd)/.zprofile ~/.zprofile
cp $(pwd)/.zshrc ~/.zshrc
cp $(pwd)/.zshsecrets ~/.zshsecrets

# Starship
echo "\n- Copy Starship Configuration"
cp $(pwd)/.config/starship.toml ~/.config/starship.toml

# SSH
echo "\n- Copy SSH Configuration"
mkdir -p ~/.ssh
cp -r $(pwd)/.ssh/config ~/.ssh/config

# tmux
echo "\n- Copy tmux Configuration"
mkdir -p ~/.tmux/plugins
git -C ~/.tmux/plugins/tpm pull || git clone https://github.com/tmux-plugins/tpm.git ~/.tmux/plugins/tpm
cp $(pwd)/.tmux.conf ~/.tmux.conf

# Git
echo "\n- Copy Git Configuration"
cp $(pwd)/.gitconfig ~/.gitconfig
cp $(pwd)/.gitconfig-staffbase ~/.gitconfig-staffbase
cp $(pwd)/.gitignore ~/.gitignore

# Vim
echo "\n- Copy Vim Configuration"
cp $(pwd)/.vimrc ~/.vimrc

# Neovim
if [ ! -d "$HOME/.local/bin/nvim-nightly" ]; then
  echo "\n- Install Neovim Nightly"
  mkdir -p $HOME/.local/bin/nvim-nightly
  curl -o $HOME/.local/bin/nvim-nightly.tar.gz -LO https://github.com/neovim/neovim/releases/download/nightly/nvim-macos-arm64.tar.gz
  tar xzf $HOME/.local/bin/nvim-nightly.tar.gz -C $HOME/.local/bin/nvim-nightly --strip-components=1
fi

echo "\n- Copy Neovim Configuration"
mkdir -p ~/.config/nvim
cp -r $(pwd)/.config/nvim ~/.config

# Neovim.app: build the Finder integration and register it as the default
# handler for text/code files (see apps/Neovim/install.sh for details).
sh $(pwd)/apps/Neovim/install.sh

# btop
echo "\n- Copy btop Configuration"
cp -r $(pwd)/.config/btop ~/.config

# radar
echo "\n- Copy radar Configuration"
cp -r $(pwd)/.config/radar ~/.config

# Glamour
echo "\n- Copy Glamour Configuration"
cp $(pwd)/.config/glamour-catppuccin-macchiato.json ~/.config/glamour-catppuccin-macchiato.json

# AI
echo "\n- Copy Agents Configuration"
cp -r $(pwd)/.agents ~/

echo "\n- Copy Copilot Configuration"
mkdir -p ~/.copilot
cp $(pwd)/.config/copilot/settings.json ~/.copilot/settings.json
cp $(pwd)/.config/copilot/lsp-config.json ~/.copilot/lsp-config.json
cp -r $(pwd)/.config/copilot/agents ~/.copilot

# Binaries
echo "\n- Copy Binaries"
cp -r $(pwd)/.local/bin ~/.local

# Add symlink for iCloud in the home directory
echo "\n- Add Symlink for iCloud"
ln -sfn ~/Library/Mobile\ Documents/com\~apple\~CloudDocs ~/iCloud

# Language Servers and Linters
echo "\n- Run the Following Commands to Install Language Servers, Linters and Formatters:"
echo "  - npm install -g prettier"
echo "  - npm install -g vscode-langservers-extracted@4.8.0"
echo "  - npm install -g dockerfile-language-server-nodejs"
echo "  - npm install -g @microsoft/compose-language-service"
echo "  - go install github.com/nametake/golangci-lint-langserver@latest"
echo "  - go install golang.org/x/tools/gopls@latest"
echo "  - npm install -g typescript-language-server typescript"
echo "  - npm install -g @typescript/native-preview"
echo "  - npm install -g yaml-language-server"
echo "  - npm install -g @github/copilot-language-server"
echo "  - npm install -g @github/copilot"
echo "  - npm install -g pyright"
echo "  - npm install -g bash-language-server"
echo "  - curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --no-modify-path"
