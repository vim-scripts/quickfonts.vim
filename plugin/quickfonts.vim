" Vim global plugin for quickly switching between a list of favorite fonts
" Last Change: $Date: 2003/01/24 19:15:42 $
" Maintainer: T Scott Urban <tsurban@attbi.com>
" Version: $Revision: 1.20 $
"
" For full user info, see quickfonts.txt
" Key user info:
"
" Overview:
"   This plugin manages a list of favorite fonts, and allows you to swich
"   quickly between those fonts
"
" Globals Config Variables:  read-only unless noted, only used on startup
"   g:quickFontsFile         - file to use to read and save font info
"   g:quickFontsNoXwininfo   - disable calling xininfo (for unix)
"   g:quickFontsAutoLoad     - auto load last used font on gui startup
"   g:quickFontsNoMappings   - disable default mappings
"   g:quickfonts_loaded      - used to avoid multiple loading (read-write)
"
" Commands:
"   :QuickFontInfo              - display info about font list
"   :QuickFontAdd [*|font_name] - add a font to the list
"   :QuickFontDel [num]         - delete a font from the list
"   :QuickFontBigger            - switch to next bigger font in list
"   :QuickFontSmaller           - switch to next smaller font in list
"   :QuickFontSet <num>         - switch to specified font in list
"   :QuickFontReload            - reload list fron list file
"
" Mappings: disable (and do your own) with g:quickFontsNoMappings
"   Alt>                        - QuickFontBigger
"   Alt<                        - QuickFontSmaller
"
" Other:
"   fonts are read from the font file at vim start
"   fonts are written to the font file at vim exit
"

" protect from multiple sourcing, but allow it for devel
if exists("quickfonts_loaded") && ! exists ("quickfonts_debug")
	finish
endif
let quickfonts_loaded = 1

""" global script variables
" s:auto         - whether to autoload last used font
" s:file         - file for storing fonts
" s:fna          - font name array, used s:fna{i}
" s:fnum         - number of fonts in list
" s:fsa          - font size array, used s:fsa{i}
" s:fwa          - font width array, used s:fwa{i}
" s:listchanged  - whether list has changed - if 1, list is saved on exit
" s:noxw         - whether we should not use `xwininfo` for geometry
" s:save_cpo     - to restore settings
" s:selfont      - selected font index
" s:var_{key}    - font file settings
" s:winsys       - type of system we'll be dealing with


""" save settings
let s:save_cpo = &cpo | set cpo&vim

""" determine system type
if has("unix")
	let s:winsys = "Xwindows"
elseif has ("gui_win32") || has ("gui_win32s")
	let s:winsys = "Windows"
else
	let s:winsys "Unknown"
endif

""" temporaries
let tfileWindows  = $HOME . "/_vimquickfonts"
let tfileXwindows = $HOME . "/.vimquickfonts"
let tfileUnknown  = $HOME . "/.vimquickfonts"

""" config from global variables
let s:file = (exists ("g:quickFontsFile") ? g:quickFontsFile : tfile{s:winsys})
let s:noxw = (exists ("g:quickFontsNoXwininfo") ? 1 : 0)
let s:auto = (exists ("g:quickFontsAutoLoad") ? 1 : 0)

unlet tfileWindows tfileXwindows tfileUnknown

""" autocommands
au VimLeave * call s:ScriptFinish ()
execute ("au BufWritePost " . s:file . " call s:LoadFonts (0)")

""" global commands
command! -n=0 QuickFontInfo :call s:QuickFontInfo()
command! -n=? QuickFontAdd :call s:QuickFontAdd(<f-args>)
command! -n=? QuickFontDel :call s:QuickFontDel(<f-args>)
command! -n=0 QuickFontBigger :call s:QuickFontBigger()
command! -n=0 QuickFontSmaller :call s:QuickFontSmaller()
command! -n=1 QuickFontSet :call s:QuickFontSet(<f-args>)
command! -n=0 QuickFontReload :call s:LoadFonts(0)

""" global mappings
if !exists ("g:quickFontsNoMappings")
	if exists ("quickfonts_debug") " so unique doesn't break
		nmap <A->> :QuickFontBigger<CR>
		nmap <A-<> :QuickFontSmaller<CR>
	else
		nmap <unique> <A->> :QuickFontBigger<CR>
		nmap <unique> <A-<> :QuickFontSmaller<CR>
	endif
endif


""" read or re-read font file
function! s:LoadFonts(setfont)
	let strbuf = s:LoadFile (s:file)

	" read header info
	while strbuf =~ '^#'
		let curlin = substitute (strbuf, "\n.*", "", "")
		let strbuf = substitute (strbuf, "[^\n]*\n", "", "")
		let colon = match (curlin, ":")
		let key = strpart (curlin, 1, colon -1)
		let val = strpart (curlin, colon + 1)
		let s:var_{key} = val
	endwhile

	" read fonts (backward compatible)
	call s:ReadFonts (strbuf)

	if a:setfont > 0
		let s:selfont = 0
	elseif s:selfont >= s:fnum
		let s:selfont = s:fnum - 1
	endif

endfunction

""" utility to load file into string
function! s:LoadFile(fname)
	let retstr = ""
	if filereadable (a:fname)
		let retstr = system ("cat " . a:fname)
	endif
	return retstr
endfunction

"" parse fonts from a string (header info already stripped)
function! s:ReadFonts(str)
	let fonts = a:str
	let s:fnum = 0
	let s:listchanged = 0
	while strlen (fonts) > 0
		let curfont = substitute (fonts, "\n.*", "", "")
		let fonts = substitute (fonts, "[^\n]*\n", "" , "")
		if curfont != ""
			let wid_start = match (curfont, ":") + 1
			let name_start = match (curfont, ":", wid_start) + 1
			let s:fsa{s:fnum} = strpart (curfont, 0, wid_start - 1)
			let s:fwa{s:fnum} = strpart (curfont, wid_start, name_start - wid_start - 1)
			let s:fna{s:fnum} = strpart (curfont, name_start)
			let s:fnum = s:fnum + 1
		endif
	endwhile
endfunction

"" write fonts to config file
function! s:ScriptFinish()
	if s:listchanged == 0 && s:auto == 0
		return
	endif
	let fonts = ""
	let cnt = 0
	while cnt < s:fnum
		let fonts = fonts . s:fsa{cnt} . ":" . s:fwa{cnt} . ":" . s:fna{cnt} . "\n"
		let cnt = cnt + 1
	endwhile
	let fonts = "#VERSION:2\n#LASTFONT:" . s:selfont . "\n" . fonts
	if &shell =~ 'csh$'
		call system ("echo '" . escape (fonts, "\n") .  "' > " . s:file)
	else
		call system ("echo '" . fonts .  "' > " . s:file)
	endif
endfunction

"" list fonts info and selected font
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

"" add current font, argument font,  or font selector if arg is '*'
function! s:QuickFontAdd(...)
	if a:0 > 0
		let prevfont = &guifont
		if a:1 == '*'
			set guifont=*
			if prevfont == &guifont
				echo "QuickFontAdd: new font not selected"
				return
			endif
		else
			execute "set guifont=" . a:1
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

		"echo "cnt " . cnt . " area " . area . " fsa{cnt} " . s:fsa{cnt}
		if (area + 0) <= (s:fsa{cnt} + 0)
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

"" remove passed in font num or current selected font
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

"" switch to bigger font
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

"" switch to smaller font
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

"" switch to specific font - usefule after QuickFontInfo
function! s:QuickFontSet(fn)
	if a:fn < 0 || a:fn >= s:fnum
		echo "QuickFont: invalid font number - see :QuickFontInfo"
		return
	endif

	let s:selfont = a:fn

	let newfont = s:fna{s:selfont}
  execute "set guifont=" . escape (newfont, " ")
	redraw
	echo "QuickFontSet: " . newfont
endfunction
	
"" get X windows font geometry (unix only)
function! s:GetGeomXwindows(newfont)
	if s:noxw == 0
		let save_ts = &titlestring
		let save_t = &title
		let temp_title = tempname()
		set title
		exec "set titlestring=" . temp_title
		let geom = system ('xwininfo -name ' . temp_title)
		" make sure no errors from xwininfo
		if match (geom, "error") < 0  && match (geom, "Command not found") < 0
			let geom_w = substitute (geom, '.*Width: ', "", "")
			let geom_w = substitute (geom_w, '[^0-9].*', "", "")
			let geom_h = substitute (geom, '.*Height: ', "", "")
			let geom_h = substitute (geom_h, '[^0-9].*', "", "")
			let width = (geom_w/&columns)
			let area = ((geom_h/&lines)*width)
			let &titlestring = save_ts
			let &title = save_t
			return (area . ":" . width)
		else
			" drop through to next method
			let &titlestring = save_ts
			let &title = save_t
		endif
	endif

	let width = substitute (a:newfont, '^\(-[^-]*\)\{6\}-', "", "")
	let width = substitute (width, '-.*', "", "")

	if width == '*'
		let width = substitute (a:newfont, '^\(-[^-]*\)\{7\}-', "", "")
		let width = substitute (width, '-.*', "", "")
		let width = width / 10
	endif
	let area = 0
	return (area . ":" . width)

endfunction

"" get MS Windows font geometry (not implemented)
function! s:GetGeomWindows(newfont)
	return '0:0'
endfunction

""  get font geometry fall back
function! s:GetGeomUnknown(newfont)
	return '0:0'
endfunction

" first time load
call s:LoadFonts (1)
if s:auto == 1 && exists("s:var_LASTFONT")
	if s:var_LASTFONT >= 0 && s:var_LASTFONT < s:fnum
		let s:selfont = s:var_LASTFONT
		execute "set guifont=" . escape (s:fna{s:selfont}, " ")
	endif
endif

let &cpo = s:save_cpo " restore vim settings
