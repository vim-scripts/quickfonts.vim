" Vim global plugin for quickly switching between a list of favorite fonts
" Last Change: Mon Feb  4 12:54:33 PST 2002
" Maintainer: T Scott Urban <tsurban@attbi.com>
" Version: $Revision: 1.6 $

if exists("loaded_quickfonts")
	finish
endif
let loaded_quickfonts = 1

let s:save_cpo = &cpo
set cpo&vim

let s:selfont = 0

" config file for reading and writing font list
if exists ("g:quickFontsFile")
	let s:fontfile = g:quickFontsFile
else
	let s:fontfile = $HOME . "/.vimquickfonts"
endif

""" autocommands
au VimEnter * call s:ReadFonts ()
au VimLeave * call WriteFonts ()

""" global mappings
nmap <unique> <A->> :call <SID>QuickfontBigger()<CR>
nmap <unique> <A-<> :call <SID>QuickfontSmaller()<CR>

""" global commands
command! -n=0 QuickFontInfo :call s:QuickFontInfo()
command! -n=? QuickFontAdd :call s:QuickFontAdd(<f-args>)
command! -n=? QuickFontDel :call s:QuickFontDel(<f-args>)

""" private functions

"" s:ReadFonts - read fonts from config file
function! s:ReadFonts()
	let s:numfonts = 0
	if filereadable (s:fontfile)
		let fonts = system ("cat " . s:fontfile)
		let cnt = 0
		while strlen (fonts) > 0
			let curfont = substitute (fonts, "\n.*", "", "")
			let fonts = substitute (fonts, "[^\n]*\n", "" , "")
			if curfont != ""
				let s:fontarray{cnt} = curfont
				let s:numfonts = s:numfonts + 1
			endif
			let cnt = cnt + 1
		endwhile
	endif
endfunction

"" s:WriteFonts - write fonts to config file
function! WriteFonts()
	let fonts = ""
	let cnt = 0
	while cnt < s:numfonts
		let fonts = fonts . s:fontarray{cnt} . "\n"
		let cnt = cnt + 1
	endwhile
	call system ("echo '" . escape (fonts, "\n") .  "' > " . s:fontfile)
endfunction

"" s:QuickFontInfo - list quick fonts info
function! s:QuickFontInfo()
	echo "number fonts: " . s:numfonts . ", selected font: " . s:selfont
	let cnt = 0
	while cnt < s:numfonts
		echo cnt . ": " . s:fontarray{cnt}
		let cnt = cnt + 1
	endwhile
endfunction

"" s:QuickFontAdd - add current font or font selector if arg is '*'
function! s:QuickFontAdd(...)
	if a:0 > 0 && a:1 == '*'
		let prevfont = &guifont
		set guifont=*
		if prevfont == &guifont
			echo "QuickFontAdd: new font not selected"
			return
		endif
	endif
	let newfont = &guifont
	if newfont == ""
		echo "no font in 'guifont' - use '*' or set with :set guifont *"
		return
	endif
	echo "QuickFontAdd: adding newfont: " . newfont

	let nfs = s:GetXFontSize (newfont)

	let cnt = 0
	while cnt < s:numfonts
		if s:fontarray{cnt} == newfont
			echo "QuickFontAdd: new font matches font number " cnt
			return
		endif

		if nfs <= s:GetXFontSize (s:fontarray{cnt})
			break
		endif
		let cnt = cnt + 1
	endwhile

	let cnt2 = s:numfonts - 1
	while cnt2 >= cnt
		let s:fontarray{cnt2 + 1} = s:fontarray{cnt2}
		let cnt2 = cnt2 - 1
	endwhile

	let s:selfont = cnt
	let s:fontarray{cnt} = newfont
	let s:numfonts = s:numfonts + 1
		
endfunction

"" s:QuickFontDel - remove passed in font num or current selected font
function! s:QuickFontDel(...)
	if a:0 > 0
		let condemned = a:1
	else
		let condemned = s:selfont
	endif

	if condemned >= s:numfonts || condemned < 0
		echo "font " . condemned . " out of range"
		return
	endif

	let cnt = condemned
	while cnt < s:numfonts -1
		let s:fontarray{cnt} = s:fontarray{cnt + 1}
		let cnt = cnt + 1
	endwhile
	let s:numfonts = s:numfonts - 1
	"unlet s:fontarray{s:numfonts} - bug, leak
	if condemned == s:selfont && s:numfonts > 1
		let s:selfont = s:selfont - 1
		call <SID>QuickfontBigger ()
	endif
endfunction

"" s:QuickfontBigger - switch to bigger font
function s:QuickfontBigger()
  let s:selfont = s:selfont + 1
  if s:numfonts == 0 || s:selfont >= s:numfonts
    let s:selfont = s:numfonts - 1
		return
  endif
  execute "set guifont=" . s:fontarray{s:selfont}
endfunction

"" s:QuickfontSmaller - switch to smaller font
function s:QuickfontSmaller()
  let s:selfont = s:selfont - 1
  if s:numfonts == 0 || s:selfont < 0
    let s:selfont = 0
		return
  endif
  execute "set guifont=" . s:fontarray{s:selfont}
endfunction

"" s:GetXFontSize - get size of X font
function! s:GetXFontSize(font)
	let fs = substitute (a:font, '^\(-[^-]*\)\{6\}-', "", "")
	let fs = substitute (fs, '-.*', "", "")

	if fs == '*'
		let fs = substitute (a:font, '^\(-[^-]*\)\{7\}-', "", "")
		let fs = substitute (fs, '-.*', "", "")
		let fs = fs / 10
	endif
	return fs
endfunction



let &cpo = s:save_cpo

