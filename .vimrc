" Vundle
set nocompatible
filetype off
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

Plugin 'VundleVim/Vundle.vim'

Plugin 'arcticicestudio/nord-vim'
Plugin 'vim-airline/vim-airline'
Plugin 'tpope/vim-fugitive'
Plugin 'scrooloose/nerdtree'
Plugin 'preservim/nerdcommenter'
Plugin 'majutsushi/tagbar'
Plugin 'editorconfig/editorconfig-vim'
Plugin 'jiangmiao/auto-pairs'
Plugin 'fatih/vim-go'
Plugin 'peitalin/vim-jsx-typescript'
Plugin 'leafgarland/typescript-vim'
Plugin 'airblade/vim-gitgutter'
Plugin 'ctrlpvim/ctrlp.vim'
Plugin 'mileszs/ack.vim'
Plugin 'terryma/vim-multiple-cursors'
Plugin 'mattn/webapi-vim'
Plugin 'rust-lang/rust.vim'
Plugin 'racer-rust/vim-racer'

call vundle#end()
filetype plugin indent on

" Basics
set showmatch                                     " show matching brackets.
set ignorecase                                    " do case insensitive matching
set hlsearch                                      " highlight search results
set tabstop=2                                     " number of columns occupied by a tab character
set softtabstop=2                                 " see multiple spaces as tabstops so <BS> does the right thing
set expandtab                                     " converts tabs to white space
set shiftwidth=2                                  " width for autoindents
set autoindent                                    " indent a new line the same amount as the line just typed
set number                                        " add line numbers
set wildmode=longest,list                         " get bash-like tab completions
set cc=120                                        " set an 120 column border for good coding style
set noshowmode                                    " disable status line
set list listchars=tab:▸\ ,trail:·,eol:¬,nbsp:_   " show "invisible" characters
set updatetime=1000                               " reducing update time to 1s
set clipboard=unnamed                             " clipboard sharing
set cursorline                                    " highlight the line containing the cursor
set backspace=2                                   " make backspace work like most other programs

let showmarks_include = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
let g:showmarks_enable = 1

" Nord Theme
let g:nord_cursor_line_number_background = 1
let g:nord_bold_vertical_split_line = 1

syntax on
colorscheme nord
set background=dark

" Airline
let g:airline_powerline_fonts = 1
let g:airline_skip_empty_sections = 1
let g:airline#extensions#tabline#enabled = 1

if !exists('g:airline_symbols')
    let g:airline_symbols = {}
endif

let g:airline_left_sep = '»'
let g:airline_left_sep = '▶'
let g:airline_right_sep = '«'
let g:airline_right_sep = '◀'
let g:airline_symbols.linenr = '␊'
let g:airline_symbols.linenr = '␤'
let g:airline_symbols.linenr = '¶'
let g:airline_symbols.branch = '⎇'
let g:airline_symbols.paste = 'ρ'
let g:airline_symbols.paste = 'Þ'
let g:airline_symbols.paste = '∥'
let g:airline_symbols.whitespace = 'Ξ'

let g:airline_left_sep = ''
let g:airline_left_alt_sep = ''
let g:airline_right_sep = ''
let g:airline_right_alt_sep = ''
let g:airline_symbols.branch = ''
let g:airline_symbols.readonly = ''
let g:airline_symbols.linenr = ''

" NERDTree
" - Mapping
" - Show hidden files
" - Open NERDTree automatically when vim starts up and no file were specified
" - Make sure vim does not open files and other buffers on NerdTree window
map <silent> <C-n> :NERDTreeToggle<CR>

let NERDTreeShowHidden=1

autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif

autocmd BufEnter * if bufname('#') =~# "^NERD_tree_" && winnr('$') > 1 | b# | endif

" NERDCommenter
let g:NERDSpaceDelims = 1

" Tagbar
map <silent> <C-m> :TagbarToggle<CR>

" ctrlp.vim
let g:ctrlp_map = '<c-p>'
let g:ctrlp_cmd = 'CtrlP'
let g:ctrlp_custom_ignore = '\v[\/]\.(git|hg|svn|node_modules)$'

" ack.vim
if executable('ag')
  let g:ackprg = 'ag --vimgrep'
endif

" vim-multiple-cursors
let g:multi_cursor_use_default_mapping = 0
let g:multi_cursor_start_word_key      = '<C-g>'
let g:multi_cursor_next_key            = '<C-g>'
let g:multi_cursor_quit_key            = '<Esc>'

" rust.vim
let g:rustfmt_autosave = 1

if has('unix')
  if has('mac')
    let g:rust_clip_command = 'pbcopy'
  else
    let g:rust_clip_command = 'xclip -selection clipboard'
  endif
endif

" Vim Racer Plugin
let g:racer_experimental_completer = 1

" Autocompletion
" https://vim.fandom.com/wiki/Omni_completion
" https://vim.fandom.com/wiki/Smart_mapping_for_tab_completion

filetype plugin on
set omnifunc=syntaxcomplete#Complete

function! Smart_TabComplete()
  let line = getline('.')

  let substr = strpart(line, -1, col('.')+1)
  let substr = matchstr(substr, "[^ \t]*$")
  if (strlen(substr)==0)
    return "\<tab>"
  endif
  let has_period = match(substr, '\.') != -1
  let has_slash = match(substr, '\/') != -1
  let has_colon = match(substr, ':') != -1
  if (!has_period && !has_slash && !has_colon)
    return "\<C-X>\<C-P>"
  elseif ( has_slash )
    return "\<C-X>\<C-F>"
  else
    return "\<C-X>\<C-O>"
  endif
endfunction

inoremap <tab> <c-r>=Smart_TabComplete()<CR>
