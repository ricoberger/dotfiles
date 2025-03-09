# dotfiles

![Screenshot](./assets/screenshot.png)

## Usage

- Install the `Cascadia Code` font:
  [https://github.com/microsoft/cascadia-code](https://github.com/microsoft/cascadia-code)
- Install [Homebrew](https://brew.sh) and the Brewfile
  ```sh
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  brew bundle install --file=Brewfile
  ```
- Set zsh as default shell
  ```sh
  sudo sh -c "echo $(which zsh) >> /etc/shells"
  chsh -s $(which zsh)
  ```
- Clone and install the dotfiles
  ```sh
  git clone git@github.com:ricoberger/dotfiles.git
  cd dotfiles
  ./install.sh && source ~/.zshrc
  ```
