" My Dark GUI Theme
set background=dark
highlight clear
if version > 580
	hi clear
	if exists("syntax_on")
		syntax reset
	endif
endif
let g:colors_name = "mydark"

hi Normal guifg=grey  guibg=#000010 gui=none ctermfg=grey  ctermbg=none    cterm=none
hi Cursor             guibg=#FF00FF gui=none               ctermbg=magenta
hi Visual guifg=white guibg=#101099 gui=none ctermfg=white ctermbg=blue    cterm=none

hi Comment guifg=#12AA12 gui=none ctermfg=darkgreen cterm=none

hi Constant  guifg=red     gui=none ctermfg=red        cterm=none
hi String    guifg=red     gui=none ctermfg=red        cterm=none
hi Character guifg=red     gui=none ctermfg=red        cterm=none
hi Number    guifg=yellow  gui=none ctermfg=yellow     cterm=none
hi Boolean   guifg=#FF8000 gui=none ctermfg=darkyellow cterm=none
hi Float     guifg=yellow  gui=none ctermfg=yellow     cterm=none

hi Identifier guifg=grey gui=none ctermfg=grey cterm=none
hi Function   guifg=grey gui=none ctermfg=grey cterm=none

hi Statement   guifg=#FF8000 gui=none ctermfg=darkyellow cterm=none
hi Conditional guifg=#FF8000 gui=none ctermfg=darkyellow cterm=none
hi Repeat      guifg=#FF8000 gui=none ctermfg=darkyellow cterm=none
hi Label       guifg=#FF8000 gui=none ctermfg=darkyellow cterm=none
hi Operator    guifg=#00FFFF gui=none ctermfg=cyan       cterm=none
hi Keyword     guifg=#FF8000 gui=none ctermfg=darkyellow cterm=none
hi Exception   guifg=#FF8000 gui=none ctermfg=darkyellow cterm=none

hi PreProc   guifg=#008080 gui=none ctermfg=darkcyan cterm=none
hi Include   guifg=#008080 gui=none ctermfg=darkcyan cterm=none
hi Define    guifg=#008080 gui=none ctermfg=darkcyan cterm=none
hi Macro     guifg=#008080 gui=none ctermfg=darkcyan cterm=none
hi PreCondit guifg=#008080 gui=none ctermfg=darkcyan cterm=none

hi Type         guifg=white   gui=none ctermfg=white      cterm=none
hi StorageClass guifg=#FF8000 gui=none ctermfg=darkyellow cterm=none
hi Structure    guifg=#FF8000 gui=none ctermfg=darkyellow cterm=none
hi Typedef      guifg=#FF8000 gui=none ctermfg=darkyellow cterm=none

hi Pmenu      ctermfg=cyan    ctermbg=blue cterm=none guifg=cyan   guibg=darkblue
hi PmenuSel   ctermfg=white   ctermbg=blue cterm=none guifg=white  guibg=darkblue gui=none
hi PmenuSbar                  ctermbg=cyan            guibg=cyan
hi PmenuThumb ctermfg=white                           guifg=white

hi DiffAdd    cterm=none ctermbg=darkgreen   ctermfg=black
hi DiffChange cterm=none ctermbg=darkmagenta ctermfg=black
hi DiffText   cterm=none ctermbg=cyan        ctermfg=black
hi DiffDelete cterm=none ctermbg=darkred     ctermfg=black

hi NearColLimit    gui=none guibg=yellow guifg=darkblue cterm=none ctermbg=yellow ctermfg=darkblue cterm=none cterm=none cterm=none cterm=none
hi OverColLimit    gui=none guibg=red    guifg=darkblue cterm=none ctermbg=red    ctermfg=darkblue
hi ExtraWhitespace          guibg=red                              ctermbg=red

hi ColorColumn ctermbg=darkyellow
