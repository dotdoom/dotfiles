" .vimrc
" See: http://vimdoc.sourceforge.net/htmldoc/options.html for details

set nocompatible

" For multi-byte character support (CJK support, for example):
set fileencodings=utf-8,cp1251,latin1

set nowrap
set modeline

" Enable error files and error jumping.
set cf

" Show line numbers.
set number

" Highlight matching bracket.
set showmatch

" Search options.
set hlsearch
set ignorecase
set smartcase

" Display tabs and trailing spaces.
set list

if has("mouse")
	" Enable the use of the mouse.
	set mouse=a
endif

if exists("+undofile")
	" Enable the persistent undo file(s)
	set undodir=~/.vim/undo
	set undofile
endif

set switchbuf+=usetab " Switch to existing tab; open a new tab for the new buf

let mapleader=","

filetype off

runtime bundle/vim-pathogen/autoload/pathogen.vim
execute pathogen#infect()

set background=dark
colorscheme mydark

" Configure plugins.

" supertab: tab-complete based on preceding characters (::, ->, . etc).
let g:SuperTabDefaultCompletionType = "context"

" vim-go: not just format the code; insert imports, too.
let g:go_fmt_command = "goimports"

" dart-vim-plugin: highlight HTML in strings, enforce syntax, format on save
let dart_html_in_string = v:true
let dart_style_guide = 2
let dart_format_on_save = 1

" Tell vim to remember certain things when we exit
"  'N   :  marks will be remembered for up to N previously edited files
"  "N   :  will save up to N lines for each register
"  :N   :  up to N lines of command-line history will be remembered
"  %    :  saves and restores the buffer list
"  n... :  where to save the viminfo files
set viminfo='10,\"100,:100,n~/.viminfo

" Line width limit hint.
augroup EditorWidth
	" colorcolumn breaks copy from terminal, so we use this instead.
	au!
	au BufEnter * highlight OverLength ctermbg=darkred
	au BufEnter * match OverLength /\%81v./

	au BufEnter *.go match OverLength /\%101v./
	au BufEnter *.java match OverLength /\%101v./

	au BufEnter *.yml match OverLength /$$/
	au BufEnter *.data match OverLength /$$/
	au BufEnter .vimrc match OverLength /$$/
augroup END

" Custom filetypes.
au BufNewFile,BufRead *.pi setf python

filetype indent off

" Automatically insert the current comment leader after hitting <Enter> in Insert mode.
set formatoptions=r

" Indentation settings.

" Width of the TAB column displayed on the screen, in spaces. A value of 8
" means that it will be consistent with console, printer and others.
set tabstop=8

" Number of spaces inserted when pressing TAB, or removed when pressing
" BACKSPACE. If 0, TAB inserts <tabstop> spaces, and automatically converts
" them to TAB characters per <tabstop> and <expandtab>.
set softtabstop=0

" shiftwidth: number of spaces inserted when using indentation methods,
" like >>, <<, ==. If shiftwidth=tabstop, a TAB character is inserted instead
" of spaces. When shifting, spaces will be replaced by TAB characters as
" necessary.
set shiftwidth=8
" smarttab: typing TAB in front of the line behaves like >>, while in text,
" typing TAB will add <softtabstop> spaces and convert spaces to TAB
" characters per <tabstop> and <expandtab>.
set smarttab

" When a new line is added, keep indentation level of the previous line.
set autoindent
" When a new line is added, copy exactly indentation level of the previous
" line (i.e. do not try to replace <tabstop> spaces with tabs).
set copyindent
set preserveindent

" expandtab: ALWAYS insert <shiftwidth> spaces when typing TAB.
set noexpandtab

" Shortcuts.
nnoremap ` :ShowMarksOnce<cr>`
noremap <C-\> :let @/ = ""<CR>

" Window navigation map.
fu! Amap(key, cmd, ...)
	let l:cr="<CR>"
	let l:p=":"
	let l:key="<" . a:key . ">"
	if a:0 > 0
		if a:1 == 0
			let l:cr=""
			let l:p=""
		endif
		if a:1 > 0
			let l:key=a:key
		endif
	endif
	exe "nmap " . l:key . " " . l:p . a:cmd . l:cr
	exe "vmap " . l:key . " <ESC>" . l:key . "<ESC>gv"
	exe "imap " . l:key . " <c-o>" . l:key . ""
endf

call Amap("C-t", "tabnew")
call Amap("C-b", ":ls<CR>:b<Space>", 0)
call Amap("C-w", "close")

" Backspace navigates 'Back'
nmap <BS> <C-O>
nmap <S-BS> <C-I>

" Working with clipboard over SSH
" This doesn't paste; it prepares vim to do so. Use ^D when finished.
call Amap("zp", "r !cat", 1)
" This doesn't yank; it (un)prepares vim to do so.
call Amap("zy", "setl paste! number! list! <bar> NoShowMarks <bar> GitGutterToggle", 1)
" https://github.com/mobile-shell/mosh/issues/637 D'oh, really Mosh?!
" Well at least works with SecureShell + screen.
noremap <silent> <Leader>y :w !printf "
\$([[ "${TERM/-*/}" == screen ]] && printf "\eP")
\\e]52;c;$(base64 -w0)\a
\$([[ "${TERM/-*/}" == screen ]] && printf "\e\\")"<Return><Esc>

" Convenient write commands. w!! for sudo, others for holding Shift for too long.
cmap w!! %!sudo tee >/dev/null %<CR>
command WQ wq
command Wq wq
command W w
command Q q
command Qa qa
command QA qa

" Local machine overrides.
if filereadable(expand("~/.vimrc_local"))
	source ~/.vimrc_local
endif
