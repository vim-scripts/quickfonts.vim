" Vim global plugin for quickly switching between a list of favorite fonts
" Last Change: $Date: 2002/02/08 00:01:58 $
" Maintainer: T Scott Urban <tsurban@attbi.com>
" Version: $Revision: 1.13 $

if exists("quickfonts_loaded") && ! exists ("quickfonts_debug")
	finish
endif
let quickfonts_loaded = 1

let s:save_cpo = &cpo
set cpo&vim

"" configuration options

" config file for reading and writing font list
if exists ("g:quickFontsFile")
	let s:fontfile = g:quickFontsFile
else
	let s:fontfile = $HOME . "/.vimquickfonts"
endif

" quickFontsNoXwininfo -  var to turn off calling of xwininfo (for X systems)
let s:no_xinwinfo = (exists ("g:quickFontsNoXwininfo") ? 1 : 0)

"" script variables

" s:fnum - number of fonts in list
" s:selfont - selected font index
" s:listchanged - whether list has changed - if 1, list is saved on exit
" s:fna - font name array
" s:fsa - font size array
" s:fwa - font width array

" s:winsys - operating system groups - for dealing with fonts
if has("unix")
	let s:winsys = "Xwindows"
elseif has ("gui_win32") || has ("gui_win32s")
	let s:winsys = "Windows"
else
	let s:winsys "Unknown"
endif

""" autocommands
au VimEnter * call s:ReadFonts ()
au VimLeave * call s:WriteFonts ()
execute ("au BufWritePost " . s:fontfile . " call s:ReadFonts ()")

""" global commands
command! -n=0 QuickFontInfo :call s:QuickFontInfo()
command! -n=? QuickFontAdd :call s:QuickFontAdd(<f-args>)
command! -n=? QuickFontDel :call s:QuickFontDel(<f-args>)
command! -n=0 QuickFontBigger :call s:QuickFontBigger()
command! -n=0 QuickFontSmaller :call s:QuickFontSmaller()
command! -n=0 QuickFontReload :call s:ReadFonts()

""" global mappings
if exists ("quickfonts_debug")
	nmap <A->> :QuickFontBigger<CR>
	nmap <A-<> :QuickFontSmaller<CR>
else
	nmap <unique> <A->> :QuickFontBigger<CR>
	nmap <unique> <A-<> :QuickFontSmaller<CR>
endif

""" private functions

"" s:ReadFonts - read fonts from config file
function! s:ReadFonts()
	let s:fnum = 0
	let s:selfont = 0
	let s:listchanged = 0
	if filereadable (s:fontfile)
		let fonts = system ("cat " . s:fontfile)
		let cnt = 0
		while strlen (fonts) > 0
			let curfont = substitute (fonts, "\n.*", "", "")
			let fonts = substitute (fonts, "[^\n]*\n", "" , "")
			if curfont != ""
				let wid_start = match (curfont, ":") + 1
				let name_start = match (curfont, ":", wid_start) + 1
				let s:fsa{cnt} = strpart (curfont, 0, wid_start - 1)
				let s:fwa{cnt} = strpart (curfont, wid_start, name_start - wid_start - 1)
				let s:fna{cnt} = strpart (curfont, name_start)
				let s:fnum = s:fnum + 1
			endif
			let cnt = cnt + 1
		endwhile
	endif
endfunction

"" s:WriteFonts - write fonts to config file
function! s:WriteFonts()
	if s:listchanged == 0
		return
	endif
	let fonts = ""
	let cnt = 0
	while cnt < s:fnum
		let fonts = fonts . s:fsa{cnt} . ":" . s:fwa{cnt} . ":" . s:fna{cnt} . "\n"
		let cnt = cnt + 1
	endwhile
	call system ("echo '" . escape (fonts, "\n") .  "' > " . s:fontfile)
endfunction

"" s:QuickFontInfo - list quick fonts info
function! s:QuickFontInfo()
	echo "num area wid  name"
	let cnt = 0
	while cnt < s:fnum
		let sel_str = (s:selfont == cnt ? "*" : " ")
		exec "let cnt_str = substitute (\"  \", ' \\{" . strlen (cnt) . "}$', " . cnt . ", \"\")"
		exec "let fsa_str = substitute (\"    \", ' \\{" . strlen (s:fsa{cnt}) . "}$', " . s:fsa{cnt} . ", \"\")"
		exec "let fwa_str = substitute (\"   \", ' \\{" . strlen (s:fwa{cnt}) . "}$', " . s:fwa{cnt} . ", \"\")"
		echo sel_str . cnt_str . " " . fsa_str . " " . fwa_str . " " s:fna{cnt}
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
	if newfont == "" || newfont == "*"
		echo "no font in 'guifont' - use '*' or set with :set guifont=*"
		return
	endif

	redraw
	let geom = s:GetGeom{s:winsys} (newfont)
	let colpos = match (geom, ":")
	if colpos < 0 | return | endif
	let area = strpart (geom, 0, colpos)
	let width = strpart (geom, colpos + 1)

	let cnt = 0
	while cnt < s:fnum
		" see if we already have this font
		if s:fna{cnt} == newfont
			echo "QuickFontAdd: new font matches font number " cnt
			return
		endif

		if area <= s:fsa{cnt}
			break
		endif
		let cnt = cnt + 1
	endwhile

	echo "QuickFontAdd: " . newfont

	let cnt2 = s:fnum - 1
	while cnt2 >= cnt
		let s:fsa{cnt2 + 1} = s:fsa{cnt2}
		let s:fwa{cnt2 + 1} = s:fwa{cnt2}
		let s:fna{cnt2 + 1} = s:fna{cnt2}
		let cnt2 = cnt2 - 1
	endwhile

	let s:selfont = cnt
	let s:fsa{cnt} = area
	let s:fwa{cnt} = width
	let s:fna{cnt} = newfont
	let s:fnum = s:fnum + 1
	let s:listchanged = 1
		
endfunction

"" s:QuickFontDel - remove passed in font num or current selected font
function! s:QuickFontDel(...)
	if a:0 > 0
		let condemned = a:1
	else
		let condemned = s:selfont
	endif

	if condemned >= s:fnum || condemned < 0
		echo "font " . condemned . " out of range"
		return
	endif

	let cnt = condemned
	while cnt < s:fnum - 1
		let s:fsa{cnt} = s:fsa{cnt + 1}
		let s:fwa{cnt} = s:fwa{cnt + 1}
		let s:fna{cnt} = s:fna{cnt + 1}
		let cnt = cnt + 1
	endwhile
	let s:fnum = s:fnum - 1
	exec "unlet s:fsa" . cnt
	exec "unlet s:fwa" . cnt
	exec "unlet s:fna" . cnt
	if condemned == s:selfont && s:fnum > 1
		let s:selfont = s:selfont - 1
		call <SID>QuickFontBigger ()
	endif

	let s:listchanged = 1
endfunction

"" s:QuickFontBigger - switch to bigger font
function! s:QuickFontBigger()
  let s:selfont = s:selfont + 1
  if s:fnum == 0 || s:selfont >= s:fnum
    let s:selfont = s:fnum - 1
		echo "QuickFont: no more fonts - end of list"
		return
  endif
	let newfont = s:fna{s:selfont}
  execute "set guifont=" . escape (newfont, " ")
	redraw
	echo "QuickFontBigger: " . newfont
endfunction

"" s:QuickFontSmaller - switch to smaller font
function! s:QuickFontSmaller()
  let s:selfont = s:selfont - 1
  if s:fnum == 0 || s:selfont < 0
		echo "QuickFont: no more fonts - start of list"
    let s:selfont = 0
		return
  endif
	let newfont = s:fna{s:selfont}
  execute "set guifont=" . escape (newfont, " ")
	redraw
	echo "QuickFontBigger: " . newfont
endfunction

"" s:GetGeomXwindows - get X windows font geometry
function! s:GetGeomXwindows(newfont)
	if s:no_xinwinfo == 1
		let width = substitute (a:newfont, '^\(-[^-]*\)\{6\}-', "", "")
		let width = substitute (width, '-.*', "", "")

		if width == '*'
			let width = substitute (a:newfont, '^\(-[^-]*\)\{7\}-', "", "")
			let width = substitute (width, '-.*', "", "")
			let width = width / 10
		endif
		let area = 0
	else
		let save_ts = &titlestring
		let save_t = &title
		let temp_title = tempname()
		set title
		exec "set titlestring=" . temp_title
		let geom = system ('xwininfo -name ' . temp_title)
		let geom_w = substitute (geom, '.*Width: ', "", "")
		let geom_w = substitute (geom_w, '[^0-9].*', "", "")
		let geom_h = substitute (geom, '.*Height: ', "", "")
		let geom_h = substitute (geom_h, '[^0-9].*', "", "")
		let width = (geom_w/&columns)
		let area = ((geom_h/&lines)*width)
		let &titlestring = save_ts
		let &title = save_t
	endif
	return (area . ":" . width)
endfunction

function! s:GetGeomWindows(newfont)
	return '0:0'
endfunction

function! s:GetGeomUnknown(newfont)
	return '0:0'
endfunction


let &cpo = s:save_cpo

