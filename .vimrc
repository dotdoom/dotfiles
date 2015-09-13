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

set copyindent      " Copy the structure of the existing lines indent when
                    " autoindenting a new line (no tab-space reconstruction).

set preserveindent  " When changing the indent of the current line, preserve as much
                    " of the indent structure as possible.

set noexpandtab     " Use the appropriate number of spaces to insert a <Tab>.
                    " Spaces are used in indents with the '>' and '<' commands
                    " and when 'autoindent' is on. To insert a real tab when
                    " 'expandtab' is on, use CTRL-V <Tab>.

set nowrap          " No text wrapping

set modeline

" Suggested config options
set cf              " Enable error files & error jumping
set clipboard+=unnamed " Yanks go to clipboard instead

set number          " Show line numbers.

set showmatch       " When a bracket is inserted, briefly jump to the matching
                    " one. The jump is only done if the match can be seen on the
                    " screen. The time to show the match can be set with
                    " 'matchtime'.

set hlsearch        " When there is a previous search pattern, highlight all
                    " its matches.

set smartcase       " Override the 'ignorecase' option if the search pattern
                    " contains upper case characters.

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

set background=dark " When set to "dark", Vim will try to use colors that look
                    " good on a dark background. When set to "light", Vim will
                    " try to use colors that look good on a light background.
                    " Any other value is illegal.

set list            " Display tabs and trailing spaces

if has("mouse")
	set mouse=a     " Enable the use of the mouse.
endif

if exists("+undofile")
    " Enable the persistent undo file(s)
	set undodir=~/.vim/undo
	set undofile
endif

if exists("+colorcolumn")
	set colorcolumn=80
endif

set switchbuf+=usetab " Switch to existing tab; open a new tab for the new buffer

set statusline=%<%f\ %h%m%r\ %{fugitive#statusline()}%=%-14.(%l,%c%V%)\ %P " Custom status line with Git Branch name

let mapleader=","

filetype off

runtime bundle/vim-pathogen/autoload/pathogen.vim
execute pathogen#infect()

let g:SuperTabDefaultCompletionType = "context"
let g:go_fmt_command = "goimports"

colorscheme mydark

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

call Amap("C-t", "tabnew")
call Amap("C-b", ":ls<CR>:b<Space>", 0)
call Amap("C-w", "close")

call Amap("F2", "update")
call Amap("F3", "NERDTreeToggle")
call Amap("F7", "TagbarToggle")
"setl noai nocin nosi inde= formatoptions-=c formatoptions-=r formatoptions-=o nonumber
call Amap("F8", "setl paste! number! list! <bar> NoShowMarks <bar> GitGutterToggle")

" Navigate by tabs with Shift+Left/Right
call Amap("S-Left", "tabprev")
call Amap("S-Right", "tabnext")

" Navigate by windows with Ctrl+direction
call Amap("C-Left", "wincmd h")
call Amap("C-Down", "wincmd j")
call Amap("C-Up", "wincmd k")
call Amap("C-Right", "wincmd l")

" Resize windows with Alt+direction
call Amap("M-Left", "vertical resize -1")
call Amap("M-Down", "resize +1")
call Amap("M-Up", "resize -1")
call Amap("M-Right", "vertical resize +1")

" Move windows with Ctrl+Shift+direction
call Amap("C-S-Left", "wincmd H")
call Amap("C-S-Down", "wincmd J")
call Amap("C-S-Up", "wincmd K")
call Amap("C-S-Right", "wincmd L")

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
au BufNewFile,BufRead *.pi setf python

cmap w!! %!sudo tee >/dev/null %<CR>

command WQ wq
command Wq wq
command W w
command Q q
command Qa qa
command QA qa
