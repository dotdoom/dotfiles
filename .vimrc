" .vimrc
" See: http://vimdoc.sourceforge.net/htmldoc/options.html for details

set nocompatible

" For multi-byte character support (CJK support, for example):
set fileencodings=utf-8,cp1251,latin1

" Indentation settings. Dragons ahead!
set tabstop=4       " The width of the TAB character, plain and simple.

set shiftwidth=4    " Auto indentation, >>, <<, ==

set softtabstop=0   " Number of spaces that a <Tab> counts for while performing editing
                    " operations, like inserting a <Tab> or using <BS>.

set autoindent      " Copy indent from current line when starting a new line
                    " (typing <CR> in Insert mode or when using the "o" or "O"
                    " command).

set copyindent      " Copy the structure of the existing lines indent when
                    " autoindenting a new line (no tab-space reconstruction).

set preserveindent  " When changing the indent of the current line, preserve as much
                    " of the indent structure as possible.

set noexpandtab     " Use the appropriate number of spaces to insert a <Tab>.
                    " Spaces are used in indents with the '>' and '<' commands
                    " and when 'autoindent' is on. To insert a real tab when
                    " 'expandtab' is on, use CTRL-V <Tab>.

set smarttab        " When on, a <Tab> in front of a line inserts blanks
                    " according to 'shiftwidth'. 'tabstop' is used in other
                    " places. A <BS> will delete a 'shiftwidth' worth of space
                    " at the start of the line.

autocmd FileType ruby       setlocal expandtab shiftwidth=2 tabstop=2
autocmd FileType javascript setlocal expandtab shiftwidth=4 softtabstop=4

set nowrap          " No text wrapping

set modeline

" Suggested config options
set cf              " Enable error files & error jumping
set clipboard+=unnamed " Yanks go to clipboard instead
set timeoutlen=250  " Time to wait after ESC (default causes an annoying delay)
set lcs=trail:~

set showcmd         " Show (partial) command in status line.

set number          " Show line numbers.

set showmatch       " When a bracket is inserted, briefly jump to the matching
                    " one. The jump is only done if the match can be seen on the
                    " screen. The time to show the match can be set with
                    " 'matchtime'.

set hlsearch        " When there is a previous search pattern, highlight all
                    " its matches.

set incsearch       " While typing a search command, show immediately where the
                    " so far typed pattern matches.

set ignorecase      " Ignore case in search patterns.

set smartcase       " Override the 'ignorecase' option if the search pattern
                    " contains upper case characters.

set backspace=2     " Influences the working of <BS>, <Del>, CTRL-W
                    " and CTRL-U in Insert mode. This is a list of items,
                    " separated by commas. Each item allows a way to backspace
                    " over something.

set formatoptions=c,q,r " This is a sequence of letters which describes how
                    " automatic formatting is to be done.
                    "
                    " letter    meaning when present in 'formatoptions'
                    " ------    ---------------------------------------
                    " c         Auto-wrap comments using textwidth, inserting
                    "           the current comment leader automatically.
                    " q         Allow formatting of comments with "gq".
                    " r         Automatically insert the current comment leader
                    "           after hitting <Enter> in Insert mode. 
                    " t         Auto-wrap text using textwidth (does not apply
                    "           to comments)

set ruler           " Show the line and column number of the cursor position,
                    " separated by a comma.

set background=dark " When set to "dark", Vim will try to use colors that look
                    " good on a dark background. When set to "light", Vim will
                    " try to use colors that look good on a light background.
                    " Any other value is illegal.

if has("mouse")
	set mouse=a     " Enable the use of the mouse.
endif

if exists("+undofile")
    " Enable the persistent undo file(s)
	set undodir=~/.vim/undo
	set undofile
endif

set switchbuf+=usetab " Switch to existing tab; open a new tab for the new buffer

set laststatus=2    " Always show the status line

set statusline=%<%f\ %h%m%r\ %{fugitive#statusline()}%=%-14.(%l,%c%V%)\ %P " Custom status line with Git Branch name

let mapleader=","

" Vundle Area
filetype off
set rtp+=~/.vim/bundle/vundle/
call vundle#rc()

Bundle 'gmarik/vundle'

Bundle 'mileszs/ack.vim'

Bundle 'wincent/Command-T'
execute 'silent !(
			\ cd ~/.vim/bundle/Command-T/ruby/command-t &&
			\ sleep 2 &&
			\ ruby extconf.rb &&
			\ make) >/dev/null 2>>~/.vimerr &'

Bundle 'vim-scripts/mru.vim'
Bundle 'scrooloose/nerdcommenter'
Bundle 'scrooloose/nerdtree'

Bundle 'ervandew/supertab'
let g:SuperTabDefaultCompletionType = "context"

Bundle 'tpope/vim-fugitive'
Bundle 'jacquesbh/vim-showmarks'
Bundle 'kchmck/vim-coffee-script'
Bundle 'vim-scripts/nginx.vim'

Bundle 'majutsushi/tagbar'
let g:tagbar_type_go = {
	\ 'ctagstype' : 'go',
	\ 'kinds'     : [
		\ 'p:package',
		\ 'i:imports:1',
		\ 'c:constants',
		\ 'v:variables',
		\ 't:types',
		\ 'n:interfaces',
		\ 'w:fields',
		\ 'e:embedded',
		\ 'm:methods',
		\ 'r:constructor',
		\ 'f:functions'
	\ ],
	\ 'sro' : '.',
    \ 'kind2scope' : {
		\ 't' : 'ctype',
		\ 'n' : 'ntype'
	\ },
	\ 'scope2kind' : {
		\ 'ctype' : 't',
		\ 'ntype' : 'n'
	\ },
	\ 'ctagsbin'  : 'gotags',
	\ 'ctagsargs' : '-sort -silent'
\ }

colorscheme mydark

filetype plugin indent on
syntax on

nnoremap ` :ShowMarksOnce<cr>`
"command DiffOrig vert new | set bt=nofile | r # | 0d_ | diffthis | wincmd p | diffthis | wincmd p

" saving cursor pos and such
" Tell vim to remember certain things when we exit
"  '10  :  marks will be remembered for up to 10 previously edited files
"  "100 :  will save up to 100 lines for each register
"  :20  :  up to 20 lines of command-line history will be remembered
"  %    :  saves and restores the buffer list
"  n... :  where to save the viminfo files
set viminfo='10,\"100,:20,n~/.viminfo
function! ResCur()
	if line("'\"") <= line("$")
		normal! g`"
		return 1
	endif
endfunction

augroup resCur
	autocmd!
	autocmd BufWinEnter * call ResCur()
augroup END

" Window navigation map
noremap <C-\> :let @/ = ""<CR>

fu! Amap(key, cmd, ...)
	let l:cr="<CR>"
	let l:p=":"
	if (a:0 > 0) && (a:1 == 0)
		let l:cr=""
		let l:p=""
	endif
	exe "nmap <" . a:key . "> " . l:p . a:cmd . l:cr
	exe "vmap <" . a:key . "> <ESC><" . a:key . ">gv"
	exe "imap <" . a:key . "> <c-o><" . a:key . ">"
endf

call Amap("C-t", "CommandT")
call Amap("C-n", "tabnew")
call Amap("C-b", ":ls<CR>:b<Space>", 0)

call Amap("F2", "update")
call Amap("F3", "NERDTreeToggle")
call Amap("F4", "close")
call Amap("F5", "!ruby -c %")
call Amap("F6", "make -s clean all")
call Amap("F7", "TagbarToggle")
"setl noai nocin nosi inde= formatoptions-=c formatoptions-=r formatoptions-=o nonumber
call Amap("F8", "setl paste! number! <bar> NoShowMarks")
call Amap("F9", "!traider")

" Navigate by tabs with Shift+Left/Right
call Amap("S-Left", "tabprev")
call Amap("S-Right", "tabnext")

" Override vim-Rails plugin default binding
"let g:rails_mappings=0
"nmap gf <Plug>RailsTabFind

" Navigate by windows with Ctrl+direction
call Amap("C-Left", "<C-W>h", 0)
call Amap("C-Down", "<C-W>j", 0)
call Amap("C-Up", "<C-W>k", 0)
call Amap("C-Right", "<C-W>l", 0)

" Resize windows with Alt+direction
call Amap("M-Left", "vertical resize -1")
call Amap("M-Down", "resize +1")
call Amap("M-Up", "resize -1")
call Amap("M-Right", "vertical resize +1")

" Move windows with Ctrl+Shift+direction
call Amap("C-S-Left", "<C-W>H", 0)
call Amap("C-S-Down", "<C-W>J", 0)
call Amap("C-S-Up", "<C-W>K", 0)
call Amap("C-S-Right", "<C-W>L", 0)

" Split windows with Ctrl+Alt+Down/Right
call Amap("C-M-Down", "split")
call Amap("C-M-Right", "vsplit")

" Backspace navigates 'Back'
nmap <BS> <C-O>
nmap <S-BS> <C-I>
"call Amap("C-p", "cp")
"call Amap("C-n", "cn")

" Working with system clipboard
vmap zy "+y
vmap zp "+p
vmap zP "+P
vmap zx "+x

nmap zy "+y
nmap zp "+p
nmap zP "+P
nmap zx "+x

" custom filetypes
au BufNewFile,BufRead *.fasm setf fasm

cmap w!! %!sudo tee >/dev/null %<CR>

command WQ wq
command Wq wq
command W w
command Q q
command Qa qa
command QA qa

autocmd FileType go autocmd BufWritePre <buffer> Fmt

"match NearColLimit /\%<121v.\%>117v/
"match OverColLimit /.\%>120v/
"match ExtraWhitespace /\s\+\%#\@<!$/
