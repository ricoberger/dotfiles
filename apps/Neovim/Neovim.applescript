-- Neovim.app - Open files from Finder in Neovim.
--
-- Compiled into an application bundle via "osacompile" (see install.sh). Because
-- it declares an "on open" handler, Finder lists it under "Open With" for every
-- file type and passes the selected files as an Apple Event (not argv), so
-- multi-file selections are handled correctly.
--
-- The actual terminal is opened by the reusable "ghostty-tab" helper, which
-- creates a new tab in the front Ghostty window (or a new window if none exist),
-- sets the working directory, and types the command into the tab's login shell
-- so the full shell environment is loaded before Neovim starts.

-- Absolute path to the ghostty-tab helper. Automator/Finder launch the app with
-- a minimal PATH that excludes ~/.local/bin, so it has to be resolved via $HOME.
on ghosttyTab()
	return (system attribute "HOME") & "/.local/bin/ghostty-tab"
end ghosttyTab

-- Launched by double-clicking the app itself (no files): open a plain Neovim in
-- the home directory. Uses "window" placement so it opens on the current Space.
on run
	do shell script quoted form of ghosttyTab() & " " & ¬
		quoted form of (system attribute "HOME") & " " & quoted form of "nvim" & " window"
end run

-- Launched by opening one or more files from Finder: open them all as buffers in
-- a single Neovim, with the working directory set to the first file's folder.
-- Uses "window" placement so Neovim opens in a new window on the current Space
-- rather than switching to the Space of an existing Ghostty window.
on open theFiles
	set firstPath to POSIX path of (item 1 of theFiles)
	set cwd to do shell script "dirname " & quoted form of firstPath

	set cmd to "nvim --"
	repeat with f in theFiles
		set cmd to cmd & " " & quoted form of (POSIX path of f)
	end repeat

	do shell script quoted form of ghosttyTab() & " " & ¬
		quoted form of cwd & " " & quoted form of cmd & " window"
end open
