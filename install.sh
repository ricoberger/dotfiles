# Copy Alacritty configuration
cp $(pwd)/.alacritty.yml ~/.alacritty.yml

# Copy ZSH configuration
cp -r $(pwd)/.oh-my-zsh ~/
cp -r $(pwd)/powerlevel10k ~/.oh-my-zsh/themes/
cp $(pwd)/.zshrc ~/.zshrc

# Copy SSH configuration
mkdir -p ~/.ssh
cp -r $(pwd)/.ssh/config ~/.ssh/config

# Copy Vim configuration
cp -r $(pwd)/.vim ~/
cp $(pwd)/.vimrc ~/.vimrc

# Copy tmux configuration
cp -r $(pwd)/.tmux ~/
cp $(pwd)/.tmux.conf ~/.tmux.conf

# Copy Git configuration
cp $(pwd)/.gitconfig ~/.gitconfig
cp $(pwd)/.gitignore ~/.gitignore
cp $(pwd)/bin/diff-so-fancy /usr/local/bin/diff-so-fancy

# Copy Xcode configuration
mkdir -p ~/Library/Developer/Xcode/UserData/FontAndColorThemes/
cp $(pwd)/Xcode/Nord.xccolortheme ~/Library/Developer/Xcode/UserData/FontAndColorThemes/Nord.xccolortheme

# k9s
mkdir -p ~/.k9s
# cp $(pwd)/.k9s/config.yml ~/.k9s/config.yml
cp $(pwd)/.k9s/skin.yml ~/.k9s/skin.yml

# Copy additional binaries
cp $(pwd)/bin/kubectl-ssh /usr/local/bin/kubectl-ssh

# Install additional ZSH plugins
git -C ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions pull || git clone git@github.com:zsh-users/zsh-autosuggestions.git ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
