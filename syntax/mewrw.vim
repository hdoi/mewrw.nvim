if exists("b:current_syntax")
  finish
endif

" Syntax matching rules
" Header lines starting with "
syntax match MewrwHeader /^".*/

" Size in detailed view: e.g. "  1.2 MB"
syntax match MewrwSize /^\s*\d\+\(\.\d\+\)\?\s\+[BKMGT]B\?/
" Time match: YYYY-MM-DD HH:MM
syntax match MewrwTime /\d\{4}-\d\{2}-\d\{2}\s\+\d\{2}:\d\{2}/

" Directories (including tree mode symbols ▼/▶)
" Case 1: Standard list mode (ends with /)
syntax match Directory /[^\t ]\+\/$/
" Case 2: Tree mode (starts with ▼ or ▶)
syntax match Directory /[▼▶] [^\t ]\+\/$/
" Case 3: Indented tree mode
syntax match Directory /^\s*[▼▶] [^\t ]\+\/$/

" Extensions / File types
syntax match MewrwCode /\.\(lua\|py\|go\|c\|cpp\|rs\|js\|ts\|php\)$/
syntax match MewrwExe /\.\(exe\|bat\|sh\|bin\|out\)$/
syntax match MewrwDoc /\.\(md\|txt\|pdf\|doc\|docx\)$/

" Mark indicator (if any, though renderer uses underlines)
" (Keep current highlight links)

" Default highlight links
highlight default link MewrwHeader Comment
highlight default link MewrwSize Constant
highlight default link MewrwTime Identifier
highlight default link MewrwCode String
highlight default link MewrwExe Special
highlight default link MewrwDoc PreProc

let b:current_syntax = "mewrw"
