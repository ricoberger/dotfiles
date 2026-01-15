" ------------------------------------------------------------------------------
" GLOBALS
" ------------------------------------------------------------------------------

" Set the leader to " " (space).
let mapleader = " "
let maplocalleader = " "

" Disable some built-in plugins, so that they are not loaded.
let g:loaded_gzip = 1
let g:loaded_tar = 1
let g:loaded_tarPlugin = 1
let g:loaded_zip = 1
let g:loaded_zipPlugin = 1
let g:loaded_getscript = 1
let g:loaded_getscriptPlugin = 1
let g:loaded_vimball = 1
let g:loaded_vimballPlugin = 1
let g:loaded_matchit = 1
let g:loaded_matchparen = 1
let g:loaded_2html_plugin = 1
let g:loaded_logiPat = 1
let g:loaded_rrhelper = 1
let g:loaded_netrw = 1
let g:loaded_netrwPlugin = 1
let g:loaded_netrwSettings = 1
let g:loaded_netrwFileHandlers = 1
let g:loaded_netrw_gitignore = 1

" We are using "Cascadia Code" as font in our terminal, so that we can enable
" nerd font support in Neovim.
let g:have_nerd_font = 1

" ------------------------------------------------------------------------------
" OPTIONS
" ------------------------------------------------------------------------------

set colorcolumn=80,120
set clipboard=unnamed,unnamedplus
set completeopt=menuone,noselect
set cursorline
set expandtab
set exrc
set formatoptions=jcroqlnt
set hlsearch
set ignorecase
set laststatus=2
set statusline=%F%m%r%h%w%=[%{&ff}]%y[%p%%][%l,%v]
set list
set listchars=tab:\│\ ,leadmultispace:\│\ ,
set mouse=a
set number
set relativenumber
set scrolloff=4
set shiftround
set shiftwidth=2
set shortmess=I
set showtabline=0
set sidescrolloff=8
set signcolumn=yes
set smartcase
set smartindent
set nospell
set spelllang=en_us
set splitbelow
set splitright
set noswapfile
set tabstop=2
set termguicolors
set notimeout
set timeoutlen=300
set undofile
set undolevels=10000
set updatetime=200
set nowrap
set wildignore+=.DS_Store

" Folding
set foldcolumn=0
set foldenable
set foldlevel=99
set foldlevelstart=99
set foldmethod=indent

" Cursor shape
let &t_SI.="\e[6 q" "SI = INSERT
let &t_SR.="\e[4 q" "SR = REPLACE
let &t_EI.="\e[2 q" "EI = NORMAL

" Enable strikethrough.
let &t_Ts = "\e[9m"
let &t_Te = "\e[29m"

" Enable undercurls.
let &t_Cs = "\e[4:3m"
let &t_Ce = "\e[4:0m"

" ------------------------------------------------------------------------------
" AUTO COMMANDS
" ------------------------------------------------------------------------------

" Resize splits if window got resized.
augroup resize_splits
  autocmd!
  autocmd VimResized * let current_tab = tabpagenr() | tabdo wincmd = | execute 'tabnext '.current_tab
augroup END

" ------------------------------------------------------------------------------
" KEYMAPS
" ------------------------------------------------------------------------------

" Better up / down navigation for "j" / "down" and "k" / "up".
nnoremap <expr> j v:count == 0 ? 'gj' : 'j'
xnoremap <expr> j v:count == 0 ? 'gj' : 'j'
nnoremap <expr> <down> v:count == 0 ? 'gj' : 'j'
xnoremap <expr> <down> v:count == 0 ? 'gj' : 'j'
nnoremap <expr> k v:count == 0 ? 'gk' : 'k'
xnoremap <expr> k v:count == 0 ? 'gk' : 'k'
nnoremap <expr> <up> v:count == 0 ? 'gk' : 'k'
xnoremap <expr> <up> v:count == 0 ? 'gk' : 'k'

" Move to window using the "Ctrl" and arrow keys.
nnoremap <c-left> <c-w>h
nnoremap <c-down> <c-w>j
nnoremap <c-up> <c-w>k
nnoremap <c-right> <c-w>l

" Resize windows using "Shift" and arrow keys.
nnoremap <s-up> :resize +2<cr>
nnoremap <s-down> :resize -2<cr>
nnoremap <s-left> :vertical resize -2<cr>
nnoremap <s-right> :vertical resize +2<cr>

" Move lines up and down using "Alt" + "j" / "k" in normal, insert and visual
" modes.
nnoremap <m-j> :m .+1<cr>==
nnoremap <m-k> :m .-2<cr>==
inoremap <m-j> <esc>:m .+1<cr>==gi
inoremap <m-k> <esc>:m .-2<cr>==gi
vnoremap <m-j> :m '>+1<cr>gv=gv
vnoremap <m-k> :m '<-2<cr>gv=gv

" Better indenting in visual mode using "<" and ">".
vnoremap < <gv
vnoremap > >gv

" Surround the visual selection with parentheses, brackets, braces or quotes.
vnoremap gs( <esc>`>a)<esc>`<i(<esc>
vnoremap gs) <esc>`>a)<esc>`<i(<esc>
vnoremap gs{ <esc>`>a}<esc>`<i{<esc>
vnoremap gs} <esc>`>a}<esc>`<i{<esc>
vnoremap gs[ <esc>`>a]<esc>`<i[<esc>
vnoremap gs] <esc>`>a]<esc>`<i[<esc>
vnoremap gs< <esc>`>a><esc>`<i<<esc>
vnoremap gs> <esc>`>a><esc>`<i<<esc>
vnoremap gs" <esc>`>a"<esc>`<i"<esc>
vnoremap gs' <esc>`>a'<esc>`<i'<esc>
vnoremap gs` <esc>`>a`<esc>`<i`<esc>

" ------------------------------------------------------------------------------
" FIND FILES
" ------------------------------------------------------------------------------

" Use "fd" if available to find all files with the provided filename and show
" the results in the quickfix list. If the "fd" command is not available use
" the "find" command.
function s:Find(filename)
  if executable('fd')
    let errorfile = tempname()
    execute '!fd --full-path --hidden --color never --type f --exclude .git --exclude node_modules --exclude dist --exclude .DS_Store "'.a:filename.'" | sed "s/$/:1:/" > '.errorfile
    set errorformat=%f:%l:
    exe "cfile ". errorfile
    copen
    call delete(errorfile)
  else
    let errorfile = tempname()
    execute '!find . -name "'.a:filename.'" | sed "s/$/:1:/" > '.errorfile
    set errorformat=%f:%l:
    exe "cfile ". errorfile
    copen
    call delete(errorfile)
  endif
endfunction

command! -nargs=1 Find call s:Find(<f-args>)

" Add keymaps for all find related operations. This includes finding files via
" the "Find" command (workspace or directory of the current file) and finding
" buffers.
nnoremap <leader>ff :silent Find<space>
nnoremap <leader>fb :buffer<space>

" ------------------------------------------------------------------------------
" SEARCH THROUGH FILES
" ------------------------------------------------------------------------------

" If "rg" (ripgrep) is installed we use it to search though files with the
" "grep" command.
if executable('rg')
  set grepprg=rg\ --vimgrep\ --smart-case\ --hidden\ --color=never\ --glob='!.git'\ --glob='!node_modules'\ --glob='!dist'\ --glob='!.DS_Store'
  set grepformat=%f:%l:%c:%m
endif

" Set keymaps for search operations. This includes searching through files in
" the workspace or directory of the current file, searching for the word under
" the cursor or visual selection and searching for todo comments.
nnoremap <leader>ss :silent grep!<space>
nnoremap <expr> <leader>s/ ":silent grep! --glob='" . expand("%:.") . "' "
nnoremap <leader>sw :silent grep!<space><c-r><c-w>
vnoremap <leader>sw y:silent grep!<space><c-r>"
nnoremap <leader>st :silent grep! -e='todo:' -e='warn:' -e='info:' -e='xxx:' -e='bug:' -e='fixme:' -e='fixit:' -e='bug:' -e='issue:'<cr>

" ------------------------------------------------------------------------------
" REPLACE
" ------------------------------------------------------------------------------

" Replace in the current buffer or in all items in the quickfix list. Replace
" in the current buffer also works for a visual selection.
nnoremap <leader>rr :%s///gcI<left><left><left><left><left>
vnoremap <leader>rr :s///gcI<left><left><left><left><left>
nnoremap <leader>rw :%s/\<<c-r><c-w>\>//gcI<left><left><left><left>
vnoremap <leader>rw y:%s/\V<c-r>"//gcI<left><left><left><left>
nnoremap <leader>rR :cfdo %s///gcI | update<left><left><left><left><left><left><left><left><left><left><left><left><left><left>
nnoremap <leader>rW :cfdo %s/\<<c-r><c-w>\>//gcI | update<left><left><left><left><left><left><left><left><left><left><left><left><left>
vnoremap <leader>rW y:cfdo %s/\V<c-r>"//gcI | update<left><left><left><left><left><left><left><left><left><left><left><left><left><left>

" ------------------------------------------------------------------------------
" QUICKFIX LIST
" ------------------------------------------------------------------------------

" When using `dd` in the quickfix list, remove the item from the quickfix list.
function! RemoveQFItem()
  let curqfidx = line('.') - 1
  let qfall = getqflist()
  call remove(qfall, curqfidx)
  call setqflist(qfall, 'r')
  execute curqfidx + 1 . "cfirst"
  :copen
endfunction
:command! RemoveQFItem :call RemoveQFItem()
" Use map <buffer> to only map dd in the quickfix window. Requires +localmap
autocmd FileType qf map <buffer> dd :RemoveQFItem<cr>

" Automatically open the quickfix window if there are any entries in the
" quickfix list, e.g. after running ":grep".
augroup auto_open_quickfix
  autocmd!
  autocmd QuickFixCmdPost [^l]* cwindow
augroup END

" Add keymaps for easier acccess to the Quickfix list.
nnoremap ]q :cnext<cr>
nnoremap [q :cprevious<cr>

" ------------------------------------------------------------------------------
" MACROS
" ------------------------------------------------------------------------------

" Select a pattern and press "Q" + "Q" to record a macro into register "q",
" starting from the selected pattern. Once the macro is recorded, press "q" to
" stop the recording. The macro can then be replayed using "<c-q>". If
" nothing is selected the macro is replayed for the whole file, otherwise it is
" only replayed for the selected lines.
vnoremap Q "wyqq
nnoremap Q V/\%V\V<c-r>w<cr><esc>
nnoremap <c-q> :g/\V<c-r>w/normal! @q<cr>
vnoremap <c-q> :g/\V<c-r>w/normal! @q<cr>

" ------------------------------------------------------------------------------
" COLORSCHEMA
" ------------------------------------------------------------------------------

" Use Catppuccin as color schema. The following lines were copied from
" https://github.com/catppuccin/vim.

set background=dark
hi clear

syntax on
set termguicolors
set t_Co=256

let s:rosewater = "#F4DBD6"
let s:flamingo = "#F0C6C6"
let s:pink = "#F5BDE6"
let s:mauve = "#C6A0F6"
let s:red = "#ED8796"
let s:maroon = "#EE99A0"
let s:peach = "#F5A97F"
let s:yellow = "#EED49F"
let s:green = "#A6DA95"
let s:teal = "#8BD5CA"
let s:sky = "#91D7E3"
let s:sapphire = "#7DC4E4"
let s:blue = "#8AADF4"
let s:lavender = "#B7BDF8"

let s:text = "#CAD3F5"
let s:subtext1 = "#B8C0E0"
let s:subtext0 = "#A5ADCB"
let s:overlay2 = "#939AB7"
let s:overlay1 = "#8087A2"
let s:overlay0 = "#6E738D"
let s:surface2 = "#5B6078"
let s:surface1 = "#494D64"
let s:surface0 = "#363A4F"

let s:base = "#24273A"
let s:mantle = "#1E2030"
let s:crust = "#181926"

function! s:hi(group, guisp, guifg, guibg, gui, cterm)
  let cmd = ""
  if a:guisp != ""
    let cmd = cmd . " guisp=" . a:guisp
  endif
  if a:guifg != ""
    let cmd = cmd . " guifg=" . a:guifg
  endif
  if a:guibg != ""
    let cmd = cmd . " guibg=" . a:guibg
  endif
  if a:gui != ""
    let cmd = cmd . " gui=" . a:gui
  endif
  if a:cterm != ""
    let cmd = cmd . " cterm=" . a:cterm
  endif
  if cmd != ""
    exec "hi " . a:group . cmd
  endif
endfunction

call s:hi("Normal", "NONE", s:text, s:base, "NONE", "NONE")
call s:hi("Visual", "NONE", "NONE", s:surface1,"bold", "bold")
call s:hi("Conceal", "NONE", s:overlay1, "NONE", "NONE", "NONE")
call s:hi("ColorColumn", "NONE", "NONE", s:surface0, "NONE", "NONE")
call s:hi("Cursor", "NONE", s:base, s:rosewater, "NONE", "NONE")
call s:hi("lCursor", "NONE", s:base, s:rosewater, "NONE", "NONE")
call s:hi("CursorIM", "NONE", s:base, s:rosewater, "NONE", "NONE")
call s:hi("CursorColumn", "NONE", "NONE", s:mantle, "NONE", "NONE")
call s:hi("CursorLine", "NONE", "NONE", s:surface0, "NONE", "NONE")
call s:hi("Directory", "NONE", s:blue, "NONE", "NONE", "NONE")
call s:hi("DiffAdd", "NONE", s:base, s:green, "NONE", "NONE")
call s:hi("DiffChange", "NONE", s:base, s:yellow, "NONE", "NONE")
call s:hi("DiffDelete", "NONE", s:base, s:red, "NONE", "NONE")
call s:hi("DiffText", "NONE", s:base, s:blue, "NONE", "NONE")
call s:hi("EndOfBuffer", "NONE", "NONE", "NONE", "NONE", "NONE")
call s:hi("ErrorMsg", "NONE", s:red, "NONE", "bolditalic"    , "bold,italic")
call s:hi("VertSplit", "NONE", s:crust, "NONE", "NONE", "NONE")
call s:hi("Folded", "NONE", s:blue, s:surface1, "NONE", "NONE")
call s:hi("FoldColumn", "NONE", s:overlay0, s:base, "NONE", "NONE")
call s:hi("SignColumn", "NONE", s:surface1, s:base, "NONE", "NONE")
call s:hi("IncSearch", "NONE", s:surface1, s:pink, "NONE", "NONE")
call s:hi("CursorLineNR", "NONE", s:lavender, "NONE", "NONE", "NONE")
call s:hi("LineNr", "NONE", s:surface1, "NONE", "NONE", "NONE")
call s:hi("MatchParen", "NONE", s:peach, "NONE", "bold", "bold")
call s:hi("ModeMsg", "NONE", s:text, "NONE", "bold", "bold")
call s:hi("MoreMsg", "NONE", s:blue, "NONE", "NONE", "NONE")
call s:hi("NonText", "NONE", s:overlay0, "NONE", "NONE", "NONE")
call s:hi("Pmenu", "NONE", s:overlay2, s:surface0, "NONE", "NONE")
call s:hi("PmenuSel", "NONE", s:text, s:surface1, "bold", "bold")
call s:hi("PmenuSbar", "NONE", "NONE", s:surface1, "NONE", "NONE")
call s:hi("PmenuThumb", "NONE", "NONE", s:overlay0, "NONE", "NONE")
call s:hi("Question", "NONE", s:blue, "NONE", "NONE", "NONE")
call s:hi("QuickFixLine", "NONE", "NONE", s:surface1, "bold", "bold")
call s:hi("Search", "NONE", s:pink, s:surface1, "bold", "bold")
call s:hi("SpecialKey", "NONE", s:subtext0, "NONE", "NONE", "NONE")
call s:hi("SpellBad", "NONE", s:base, s:red, "NONE", "NONE")
call s:hi("SpellCap", "NONE", s:base, s:yellow, "NONE", "NONE")
call s:hi("SpellLocal", "NONE", s:base, s:blue, "NONE", "NONE")
call s:hi("SpellRare", "NONE", s:base, s:green, "NONE", "NONE")
call s:hi("StatusLine", "NONE", s:text, s:mantle, "NONE", "NONE")
call s:hi("StatusLineNC", "NONE", s:surface1, s:mantle, "NONE", "NONE")
call s:hi("StatusLineTerm", "NONE", s:text, s:mantle, "NONE", "NONE")
call s:hi("StatusLineTermNC", "NONE", s:surface1, s:mantle, "NONE", "NONE")
call s:hi("TabLine", "NONE", s:surface1, s:mantle, "NONE", "NONE")
call s:hi("TabLineFill", "NONE", "NONE", s:mantle, "NONE", "NONE")
call s:hi("TabLineSel", "NONE", s:green, s:surface1, "NONE", "NONE")
call s:hi("Title", "NONE", s:blue, "NONE", "bold", "bold")
call s:hi("VisualNOS", "NONE", "NONE", s:surface1, "bold", "bold")
call s:hi("WarningMsg", "NONE", s:yellow, "NONE", "NONE", "NONE")
call s:hi("WildMenu", "NONE", "NONE", s:overlay0, "NONE", "NONE")
call s:hi("Comment", "NONE", s:overlay0, "NONE", "NONE", "NONE")
call s:hi("Constant", "NONE", s:peach, "NONE", "NONE", "NONE")
call s:hi("Identifier", "NONE", s:flamingo, "NONE", "NONE", "NONE")
call s:hi("Statement", "NONE", s:mauve, "NONE", "NONE", "NONE")
call s:hi("PreProc", "NONE", s:pink, "NONE", "NONE", "NONE")
call s:hi("Type", "NONE", s:blue, "NONE", "NONE", "NONE")
call s:hi("Special", "NONE", s:pink, "NONE", "NONE", "NONE")
call s:hi("Underlined", "NONE", s:text, s:base, "underline", "underline")
call s:hi("Error", "NONE", s:red, "NONE", "NONE", "NONE")
call s:hi("Todo", "NONE", s:base, s:flamingo, "bold", "bold")

call s:hi("String", "NONE", s:green, "NONE", "NONE", "NONE")
call s:hi("Character", "NONE", s:teal, "NONE", "NONE", "NONE")
call s:hi("Number", "NONE", s:peach, "NONE", "NONE", "NONE")
call s:hi("Boolean", "NONE", s:peach, "NONE", "NONE", "NONE")
call s:hi("Float", "NONE", s:peach, "NONE", "NONE", "NONE")
call s:hi("Function", "NONE", s:blue, "NONE", "NONE", "NONE")
call s:hi("Conditional", "NONE", s:red, "NONE", "NONE", "NONE")
call s:hi("Repeat", "NONE", s:red, "NONE", "NONE", "NONE")
call s:hi("Label", "NONE", s:peach, "NONE", "NONE", "NONE")
call s:hi("Operator", "NONE", s:sky, "NONE", "NONE", "NONE")
call s:hi("Keyword", "NONE", s:pink, "NONE", "NONE", "NONE")
call s:hi("Include", "NONE", s:pink, "NONE", "NONE", "NONE")
call s:hi("StorageClass", "NONE", s:yellow, "NONE", "NONE", "NONE")
call s:hi("Structure", "NONE", s:yellow, "NONE", "NONE", "NONE")
call s:hi("Typedef", "NONE", s:yellow, "NONE", "NONE", "NONE")
call s:hi("debugPC", "NONE", "NONE", s:crust, "NONE", "NONE")
call s:hi("debugBreakpoint", "NONE", s:overlay0, s:base, "NONE", "NONE")

hi link Define PreProc
hi link Macro PreProc
hi link PreCondit PreProc
hi link SpecialChar Special
hi link Tag Special
hi link Delimiter Special
hi link SpecialComment Special
hi link Debug Special
hi link Exception Error
hi link StatusLineTerm StatusLine
hi link StatusLineTermNC StatusLineNC
hi link Terminal Normal
hi link Ignore Comment

let g:terminal_ansi_colors = [
  \ s:surface1, s:red, s:green, s:yellow, s:blue, s:pink, s:teal, s:subtext1,
  \ s:surface2, s:red, s:green, s:yellow, s:blue, s:pink, s:teal, s:subtext0
\ ]
