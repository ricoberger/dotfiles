cd "$(dirname "$0")"

# Neovim.app: an AppleScript application that lets Finder open files in Neovim
# (via the "ghostty-tab" binary). Compiled from source so it is reproducible and
# tracked in this repository. The generated bundle declares an "on open" handler,
# so it shows up under Finder's "Open With" for every file type.
echo "\n- Build Neovim.app (Finder integration)"
rm -rf /Applications/Neovim.app
osacompile -o /Applications/Neovim.app $(pwd)/Neovim.applescript
cp $(pwd)/Neovim.icns /Applications/Neovim.app/Contents/Resources/droplet.icns
/usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" /Applications/Neovim.app/Contents/Info.plist 2>/dev/null
# A stable bundle identifier is required to register Neovim.app as the default
# handler for the file types below (osacompile does not set one).
/usr/libexec/PlistBuddy -c "Delete :CFBundleIdentifier" /Applications/Neovim.app/Contents/Info.plist 2>/dev/null
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string de.ricoberger.Neovim" /Applications/Neovim.app/Contents/Info.plist
# Replace the generated wildcard document type with explicit type declarations
# so Neovim.app is a registered handler for the types we set as default below,
# and defines UTIs for extensions macOS does not otherwise recognise.
plutil -remove CFBundleDocumentTypes /Applications/Neovim.app/Contents/Info.plist 2>/dev/null
/usr/libexec/PlistBuddy -c "Merge $(pwd)/filetypes.plist" /Applications/Neovim.app/Contents/Info.plist
codesign --force --sign - /Applications/Neovim.app
touch /Applications/Neovim.app
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Neovim.app

# Register Neovim.app as the default application for text/code files (requires
# the "duti" brew). Defaults are set by UTI (not extension) because that is the
# only reliable way on modern macOS. The ".ts" extension is intentionally
# omitted: macOS treats it as an MPEG-2 video type. Keep this list in sync with
# apps/Neovim/filetypes.plist.
echo "\n- Register Neovim.app as default handler for text/code files"
for uti in \
  public.plain-text \
  public.shell-script \
  public.zsh-script \
  public.bash-script \
  public.python-script \
  com.netscape.javascript-source \
  com.microsoft.typescript \
  public.c-source \
  public.c-header \
  public.c-plus-plus-source \
  public.json \
  public.yaml \
  public.toml \
  com.microsoft.ini \
  net.daringfireball.markdown \
  com.apple.log \
  de.ricoberger.lua-source \
  de.ricoberger.vim-source \
  de.ricoberger.go-source \
  de.ricoberger.rust-source \
  de.ricoberger.jsx-source \
  de.ricoberger.conf \
  de.ricoberger.env \
  de.ricoberger.gitconfig; do
  duti -s de.ricoberger.Neovim "$uti" all
done
