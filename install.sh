# Copy ZSH configuration
cp -r $(pwd)/.oh-my-zsh ~/
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

# Copy Xcode configuration
mkdir -p ~/Library/Developer/Xcode/UserData/FontAndColorThemes/
cp $(pwd)/Xcode/Nord.xccolortheme ~/Library/Developer/Xcode/UserData/FontAndColorThemes/Nord.xccolortheme
