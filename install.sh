cd "$(dirname "$0")"

# Ghostty
echo "\n- Copy Ghostty Configuration"
mkdir -p ~/.config
cp -r $(pwd)/.config/ghostty ~/.config

# Rex
echo "\n- Copy Rex Configuration"
mkdir -p ~/.config
cp -r $(pwd)/.config/rex ~/.config

# Rex settings which can only be changed via the UI are stored in the
# com.superlogical.rex defaults domain. The custom themes, which are referenced
# by the darkThemeID and lightThemeID, are stored as JSON data. Restart Rex to
# apply the settings.
echo "\n- Write Rex Settings"
REX=com.superlogical.rex
defaults write $REX Workspace.customThemes -data "$(xxd -p $(pwd)/.config/rex/custom-themes.json | tr -d '\n')"
defaults write $REX Workspace.activePaneBorderColor -string "accent"
defaults write $REX Workspace.activityGrouping -string "session"
defaults write $REX Workspace.animationStyle -string "natural"
defaults write $REX Workspace.appearance -string "system"
defaults write $REX Workspace.balancesSplitsOnCreation -bool true
defaults write $REX Workspace.cursorShader -string "warp"
defaults write $REX Workspace.cursorShadersEnabled -bool true
defaults write $REX Workspace.darkThemeID -string "custom-2867883A-4D1E-4941-B18B-293E56F71E78"
defaults write $REX Workspace.experiments.usesNewQuickSwitcher -bool true
defaults write $REX Workspace.focusFollowsMouse -bool false
defaults write $REX Workspace.inactivePaneFadeMode -string "both"
defaults write $REX Workspace.interfaceStyle -string "useTheme"
defaults write $REX Workspace.lightThemeID -string "custom-B29CD67E-8C01-40D2-9604-A5370F4429DB"
defaults write $REX Workspace.paneDensity -string "comfortable"
defaults write $REX Workspace.showsActivePaneBorder -bool true
defaults write $REX Workspace.showsPaneHeaders -bool true
defaults write $REX Workspace.showsWindowOnLaunch -bool false
defaults write $REX Workspace.sidebarCollapsed -bool false
defaults write $REX Workspace.sidebarPosition -string "left"
defaults write $REX Workspace.sidebarShowsActivity -bool false
defaults write $REX Workspace.tabIconCount -int 0
defaults write $REX Workspace.tabIconTintMode -string "off"
defaults write $REX Workspace.tabStyle -string "horizontal"
defaults write $REX Workspace.tabsFillAvailableSpace -bool false
defaults write $REX Workspace.terminalCursorBlinkIntervalMilliseconds -int 0
defaults write $REX Workspace.terminalCursorBlinkUsesCustomInterval -bool false
defaults write $REX Workspace.terminalCustomSchemeLinks -string "ask"
defaults write $REX Workspace.terminalFontName -string "Cascadia Mono NF"
defaults write $REX Workspace.terminalFontPointSize -float 12
defaults write $REX Workspace.terminalImproveTextContrast -bool false
defaults write $REX Workspace.terminalOptionKeyBehavior -string "actsAsAlt"
defaults write $REX Workspace.terminalPaddingX -float 8
defaults write $REX Workspace.terminalPaddingY -float 8
defaults write $REX Workspace.terminalUseThemePalette -bool false
defaults write $REX Workspace.tintsPanesWithProgramBackground -bool true
defaults write $REX Workspace.usesStandardInactiveWindowPaneStyles -bool true
defaults write $REX rex.agents.names-sessions -bool false
defaults write $REX rex.client.remoteControl -bool true
defaults write $REX rex.developer-mode-enabled -bool true
defaults write $REX rex.server.automatic-restart-enabled -bool true
defaults write $REX rex.server.block-plugin-reload-enabled -bool false
defaults write $REX rex.server.run-mode -string "bundled"
defaults write $REX rex.server.tailnet-enabled -bool true
defaults write $REX rex.server.web-client-origin-patterns -array "https://rex.superlogical.com"
defaults write $REX SUAutomaticallyUpdate -bool true
defaults write $REX SUEnableAutomaticChecks -bool true

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

# Glamour
echo "\n- Copy Glamour Configuration"
cp $(pwd)/.config/glamour-catppuccin-macchiato.json ~/.config/glamour-catppuccin-macchiato.json

# AI
echo "\n- Copy Agents Configuration"
cp -r $(pwd)/.agents ~/

echo "\n- Copy Pi Configuration"
mkdir -p ~/.pi/agent
cp -r $(pwd)/.config/pi/agent/themes ~/.pi/agent
cp -r $(pwd)/.config/pi/agent/agents ~/.pi/agent
cp -r $(pwd)/.config/pi/agent/extensions ~/.pi/agent
(cd ~/.pi/agent/extensions/web-fetch && npm ci --ignore-scripts --no-audit --no-fund --silent)
cp $(pwd)/.config/pi/agent/mcp.json ~/.pi/agent/mcp.json
cp $(pwd)/.config/pi/agent/settings.json ~/.pi/agent/settings.json
cp $(pwd)/.config/pi/agent/AGENTS.md ~/.pi/agent/AGENTS.md
if [ -x ~/.pi/agent/bin/pi ] && [ ! -e ~/.local/bin/pi ] && [ ! -L ~/.local/bin/pi ]; then
  mkdir -p ~/.local/bin
  ln -s ../../.pi/agent/bin/pi ~/.local/bin/pi
fi

echo "\n- Copy Copilot Configuration"
mkdir -p ~/.copilot
cp $(pwd)/.config/copilot/settings.json ~/.copilot/settings.json
cp $(pwd)/.config/copilot/lsp-config.json ~/.copilot/lsp-config.json

# Binaries
echo "\n- Copy Binaries"
cp -r $(pwd)/.local/bin ~/.local

echo "\n- Copy fzftasks Configuration"
mkdir -p ~/.config
cp -r $(pwd)/.config/fzftasks ~/.config

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
echo "  - curl -fsSL https://pi.dev/install.sh | sh"
echo "  - curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --no-modify-path"
