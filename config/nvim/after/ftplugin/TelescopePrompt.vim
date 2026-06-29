let b:prev_ac = &ac
set noac
augroup TelescopeWinLeave
  au!
  au WinLeave * if &ft ==# 'TelescopePrompt' | let &ac = b:prev_ac | endif
augroup END
