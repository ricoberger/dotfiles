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
set cc=0                                          " set an 80 column border for good coding style
set noshowmode                                    " disable status line
set list listchars=tab:▸\ ,trail:·,eol:¬,nbsp:_   " show "invisible" characters

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

" tagbar
map <silent> <C-t> :TagbarToggle<CR>