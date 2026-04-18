" vim-trustdir: per-directory trust for modelines.
"
" Behavior:
"   - Parses each loaded buffer's modeline via modeline().
"   - If the modeline sets only options in the allowlist, it is applied
"     silently.
"   - Otherwise the plugin looks up the buffer's directory in a trust store
"     (~/.vim/trust.json, with parent-directory inheritance).
"       - If trusted:  apply all options.
"       - If not:  prompt the user to trust the directory permanently, for
"         the current session only, or not at all.  When not trusted, only
"         the allowlisted options are applied.
"
" Trust store format (~/.vim/trust.json):
"   [
"     {"path": "/abs/path", "modeline": true},
"     {"path": "/another/path", "modeline": true, "exrc": true}
"   ]

if exists('g:loaded_trustdir')
  finish
endif
let g:loaded_trustdir = 1

if !exists('*modeline')
  finish
endif

let g:trustdir_file = get(g:, 'trustdir_file', expand('~/.vim/trust.json'))

let s:allowed = {
      \ 'autoindent':     1,
      \ 'cindent':        1,
      \ 'commentstring':  1,
      \ 'expandtab':      1,
      \ 'filetype':       1,
      \ 'foldcolumn':     1,
      \ 'foldenable':     1,
      \ 'foldmethod':     1,
      \ 'modifiable':     1,
      \ 'readonly':       1,
      \ 'rightleft':      1,
      \ 'shiftwidth':     1,
      \ 'smartindent':    1,
      \ 'softtabstop':    1,
      \ 'spell':          1,
      \ 'spelllang':      1,
      \ 'tabstop':        1,
      \ 'textwidth':      1,
      \ 'varsofttabstop': 1,
      \ 'vartabstop':     1,
      \ }

set nomodeline

" Session-only trusted directories: { '/abs/path': 1 }
let s:session_trust = {}

function! s:Load() abort
  if !filereadable(g:trustdir_file)
    return []
  endif
  try
    let data = json_decode(join(readfile(g:trustdir_file), "\n"))
  catch
    return []
  endtry
  return type(data) == v:t_list ? data : []
endfunction

function! s:Save(list) abort
  let dir = fnamemodify(g:trustdir_file, ':h')
  if !isdirectory(dir)
    call mkdir(dir, 'p')
  endif
  call writefile([json_encode(a:list)], g:trustdir_file)
endfunction

" True if "path" equals "base" or lives under it.
function! s:IsUnderOrEq(path, base) abort
  return a:path ==# a:base
        \ || strpart(a:path, 0, len(a:base) + 1) ==# a:base . '/'
endfunction

" Find the most specific trust entry whose path covers "path".
function! s:FindEntry(list, path) abort
  let best = {}
  let best_len = -1
  for e in a:list
    let p = get(e, 'path', '')
    if !empty(p) && s:IsUnderOrEq(a:path, p) && len(p) > best_len
      let best = e
      let best_len = len(p)
    endif
  endfor
  return best
endfunction

function! s:IsTrusted(path) abort
  for p in keys(s:session_trust)
    if s:IsUnderOrEq(a:path, p)
      return 1
    endif
  endfor
  let e = s:FindEntry(s:Load(), a:path)
  return get(e, 'modeline', 0) ? 1 : 0
endfunction

function! s:SavePermanent(path) abort
  let list = s:Load()
  for e in list
    if get(e, 'path', '') ==# a:path
      let e.modeline = v:true
      call s:Save(list)
      return
    endif
  endfor
  call add(list, {'path': a:path, 'modeline': v:true})
  call s:Save(list)
endfunction

function! s:ApplyOption(name, value) abort
  if type(a:value) == v:t_bool
    execute 'setlocal' (a:value ? '' : 'no') . a:name
  elseif type(a:value) == v:t_number
    execute 'setlocal' a:name . '=' . a:value
  else
    execute 'setlocal' a:name . '=' . escape(a:value, ' \|"')
  endif
endfunction

function! s:ApplyOpts(opts, safe_only) abort
  for [name, value] in items(a:opts)
    if a:safe_only && !has_key(s:allowed, name)
      continue
    endif
    call s:ApplyOption(name, value)
  endfor
endfunction

function! s:HandleModeline() abort
  let opts = modeline()
  if empty(opts)
    return
  endif
  let unsafe = sort(filter(keys(opts), '!has_key(s:allowed, v:val)'))
  if empty(unsafe)
    call s:ApplyOpts(opts, 0)
    return
  endif

  let fname = expand('%:p')
  let dir = empty(fname) ? '' : fnamemodify(fname, ':h')
  if !empty(dir) && s:IsTrusted(dir)
    call s:ApplyOpts(opts, 0)
    return
  endif

  let msg = printf("Modeline in %s sets: %s\nTrust this directory?",
        \ empty(fname) ? '[No Name]' : fnamemodify(fname, ':~'),
        \ join(unsafe, ', '))
  let choice = confirm(msg, "&Yes, always\n&Session only\n&No", 3, 'Q')
  if choice == 1 && !empty(dir)
    let s:session_trust[dir] = 1
    call s:SavePermanent(dir)
    call s:ApplyOpts(opts, 0)
  elseif choice == 2 && !empty(dir)
    let s:session_trust[dir] = 1
    call s:ApplyOpts(opts, 0)
  else
    call s:ApplyOpts(opts, 1)
  endif
endfunction

" :TrustdirList                list saved trust entries
" :TrustdirAdd  {path}         mark {path} as trusted permanently
" :TrustdirRemove {path}       remove trust for {path}
command! -nargs=0 TrustdirList
      \ echo s:Load()
command! -nargs=1 -complete=dir TrustdirAdd
      \ call s:SavePermanent(fnamemodify(<q-args>, ':p:h'))
command! -nargs=1 -complete=dir TrustdirRemove
      \ call s:Remove(fnamemodify(<q-args>, ':p:h'))

function! s:Remove(path) abort
  let list = s:Load()
  let i = 0
  while i < len(list)
    if get(list[i], 'path', '') ==# a:path
      call remove(list, i)
    else
      let i += 1
    endif
  endwhile
  call s:Save(list)
endfunction

augroup vim_trustdir
  autocmd!
  autocmd BufReadPost * call s:HandleModeline()
augroup END
