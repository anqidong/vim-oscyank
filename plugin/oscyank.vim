" -------------------- INIT --------------------------------
if exists('g:loaded_oscyank')
  finish
endif
let g:loaded_oscyank = 1

" -------------------- VARIABLES ---------------------------
let s:commands = {
  \ 'operator': {'block': '`[\<C-v>`]y', 'char': '`[v`]y', 'line': "'[V']y"},
  \ 'visual': {'': 'gvy', 'V': 'gvy', 'v': 'gvy', '': 'gvy'}}
let s:options = {
  \ 'max_length': get(g:, 'oscyank_max_length', 0),
  \ 'silent': get(g:, 'oscyank_silent', 0),
  \ 'trim': get(g:, 'oscyank_trim', 0),
  \ 'osc52': get(g:, 'oscyank_osc52', "\e]52;c;%s\a")}
let s:b64_table = [
  \ 'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P',
  \ 'Q','R','S','T','U','V','W','X','Y','Z','a','b','c','d','e','f',
  \ 'g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v',
  \ 'w','x','y','z','0','1','2','3','4','5','6','7','8','9','+','/']

" -------------------- UTILS -------------------------------
function s:echo(text, hl = 'Normal')
  echohl a:hl
  echo printf('[oscyank] %s', a:text)
  echohl None
endfunction

function s:encode_b64(str, size = 0)
  let bytes = map(range(len(a:str)), 'char2nr(a:str[v:val])')
  let b64 = []

  for i in range(0, len(bytes) - 1, 3)
    let n = bytes[i] * 0x10000
          \ + get(bytes, i + 1, 0) * 0x100
          \ + get(bytes, i + 2, 0)
    call add(b64, s:b64_table[n / 0x40000])
    call add(b64, s:b64_table[n / 0x1000 % 0x40])
    call add(b64, s:b64_table[n / 0x40 % 0x40])
    call add(b64, s:b64_table[n % 0x40])
  endfor

  if len(bytes) % 3 == 1
    let b64[-1] = '='
    let b64[-2] = '='
  endif

  if len(bytes) % 3 == 2
    let b64[-1] = '='
  endif

  let b64 = join(b64, '')
  if a:size <= 0
    return b64
  endif

  let chunked = ''
  while strlen(b64) > 0
    let chunked .= strpart(b64, 0, a:size) . "\n"
    let b64 = strpart(b64, a:size)
  endwhile

  return chunked
endfunction

function s:get_text(mode, type)
  " Save user settings
  let l:clipboard = &clipboard
  let l:selection = &selection
  let l:register = getreginfo('"')
  let l:visual_marks = [getpos("'<"), getpos("'>")]

" Retrieve text
  set clipboard=
  set selection=inclusive
  silent execute printf('keepjumps normal! %s', s:commands[a:mode][a:type])
  let l:text = getreg('"')

  " Restore user settings
  let &clipboard = l:clipboard
  let &selection = l:selection
  call setreg('"', l:register)
  call setpos("'<", l:visual_marks[0])
  call setpos("'>", l:visual_marks[1])

  return l:text
endfunction

function s:trim_text(text)
  let l:text = a:text
  let l:indent = matchstrpos(l:text, '^\s\+')

  " Remove common indent from all lines
  if l:indent[1] >= 0
    let l:pattern = printf('\n%s', repeat('\s', l:indent[2] - l:indent[1]))
    let l:text = substitute(l:text, l:pattern, '\n', 'g')
  endif

  return trim(l:text)
endfunction

" -------------------- PUBLIC ------------------------------
function! OSCYank(text) abort
  let l:text = s:options.trim ? s:trim_text(a:text) : a:text

  if s:options.max_length > 0 && strlen(l:text) > s:options.max_length
    call s:echo(printf('Selection is too big: length is %d, limit is %d', strlen(l:text), s:options.max_length), 'WarningMsg')
    return
  endif

  let l:text_b64 = s:encode_b64(l:text)
  let l:osc52 = printf(s:options.osc52, l:text_b64)

  if filewritable('/dev/fd/2')
    let l:success = writefile([l:osc52], '/dev/fd/2', 'b') == 0
  else
    let l:success = chansend(v:stderr, l:osc52) > 0
  endif

  if !l:success
    call s:echo('Failed to copy selection', 'ErrorMsg')
  elseif !s:options.silent
    call s:echo(printf('%d characters copied', strlen(l:text)))
  endif
endfunction

function! OSCYankOperatorCallback(type) abort
  let l:text = s:get_text('operator', a:type)
  call OSCYank(l:text)
endfunction

function! OSCYankOperator() abort
  set operatorfunc=OSCYankOperatorCallback
  return 'g@'
endfunction

function! OSCYankVisual() abort
  let l:text = s:get_text('visual', visualmode())
  call OSCYank(l:text)
endfunction

function! OSCYankRegister(register) abort
  let l:text = getreg(a:register)
  call OSCYank(l:text)
endfunction

" -------------------- COMMANDS ----------------------------
command! -nargs=1 OSCYank call OSCYank('<args>')
command! OSCYankVisual call OSCYankVisual()
command! -register OSCYankRegister call OSCYankRegister('<reg>')
nnoremap <silent> <expr> <Plug>OSCYankOperator OSCYankOperator()
vnoremap <silent> <Plug>OSCYankVisual :<C-u>OSCYankVisual<CR>

" -------------------- DEPRECATION NOTICES -----------------
nnoremap <silent> <Plug>OSCYank
  \ :echohl WarningMsg<bar>echom "[oscyank] OSCYank is deprecated, use OSCYankOperator instead"<bar>echohl None<CR>
command! -range OSCYank execute
  \ ':echohl WarningMsg<bar>echom "[oscyank] OSCYank is deprecated, use OSCYankVisual instead"<bar>echohl None<CR>'
command! -nargs=1 OSCYankReg execute
  \ ':echohl WarningMsg<bar>echom "[oscyank] OSCYankReg is deprecated, use OSCYankRegister instead"<bar>echohl None<CR>'
