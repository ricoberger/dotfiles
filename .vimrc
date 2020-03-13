" basics
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

" nord theme
syntax on
colorscheme nord
set background=dark

" airline settings
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

" nerdtree settings
map <silent> <C-n> :NERDTreeToggle<CR>

let NERDTreeShowHidden=1

" tagbar settings
map <silent> <C-t> :TagbarToggle<CR>

" ctrlp.vim settings
let g:ctrlp_map = '<c-p>'
let g:ctrlp_cmd = 'CtrlP'
let g:ctrlp_custom_ignore = '\v[\/]\.(git|hg|svn|node_modules)$'

" ack.vim settings
if executable('ag')
  let g:ackprg = 'ag --vimgrep'
endif

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
  if (!has_period && !has_slash)
    return "\<C-X>\<C-P>"
  elseif ( has_slash )
    return "\<C-X>\<C-F>"
  else
    return "\<C-X>\<C-O>"
  endif
endfunction

inoremap <tab> <c-r>=Smart_TabComplete()<CR>
