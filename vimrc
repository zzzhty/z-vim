"====================
" Author: ZhangTianyi
" Version: 1.2
" Email: tyz1024@gmail.com
" Sections:
"	-> Initial Plugins
"	-> General Settings
"	-> Display Settings
"	-> FileEncode Settings
"	-> Filetype Settings
"	-> HotKey Settings
"	-> Others

"====================
" Initial Plugins
"====================
" 判断当前操作系统
let g:iswindows = has("win64") || has("win32") || has("win95") || has("win16")
let g:ismac = has("macunix")
let g:isdos = g:iswindows
let g:isunix = !g:iswindows

" 设置Leader键
let mapleader = ','

" 加载Vundle插件
if g:isunix
	if filereadable(expand("~/.vimrc.bundles"))
		source ~/.vimrc.bundles
	endif
else
	if filereadable(expand("~/_vimrc.bundles"))
		source ~/_vimrc.bundles
	endif
endif
" 文件类型检测
filetype plugin indent on

"====================
" General Settings
"====================
" 允许退格键删除任意内容
set backspace=indent,eol,start
" 允许光标跨越边界
set whichwrap+=<,>,h,l
" 自动读取文件内容
set autoread

" 历史记录
set nobackup		" 取消备份文件
set noswapfile      " 取消交换文件
set history=2000    " 最大历史记录
" 打开文件回到之前位置（依据.viminfo）
if has('autocmd')
    augroup z_vim_restore_cursor
        autocmd!
        autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$")
                    \ | execute "normal! g'\""
                    \ | execute "normal! g`\""
                    \ | execute "normal! zz" | endif
    augroup END
endif

" 创建持久性撤销记录
if has('persistent_undo')
	set undofile
    if g:isunix
        let &undodir = expand('~/.vim/undo/')
    else
        let &undodir = expand('$HOME/vimfiles/vimundo/')
    endif
	silent call mkdir(&undodir, 'p')
endif

" remember info about open buffers on close
set viminfo='1000,<1000,%
" turn magic on for regular expressions
set magic

if has('clipboard')
    " 支持在Visual模式下，通过C-y复制到系统剪切板
    vnoremap <C-y> "+y
    " 支持在normal模式下，通过C-p粘贴系统剪切板
    nnoremap <C-p> "+p
endif

"====================
" Display Settings
"====================
" 基础设置
syntax enable       " 语法高亮
set number		    " 显示行号
set ruler		    " 显示标尺
set autoindent      " 自动缩进
set smartindent	    " 智能缩进
set linebreak		" 智能折行
set showcmd		    " 显示正在输入指令
set hlsearch	    " 高亮显示搜索结果
set ignorecase	    " 搜索时忽略大小写
set smartcase	    " 智能区分大小写

" 文本格式
set expandtab       " 自动将Tab转换为空格
set tabstop=4		" 制表符空格数
set shiftwidth=4	" normal模式下缩进空格数
set softtabstop=4	" Tab转换的空格数目
set scrolloff=7		" 自动翻页最小距离
set textwidth=0	    " 禁用自动硬折行

" Relative Line Number
set relativenumber number
augroup z_vim_number
    autocmd!
    autocmd FocusLost * set norelativenumber number
    autocmd FocusGained * set relativenumber
    autocmd InsertEnter * set norelativenumber number
    autocmd InsertLeave * set relativenumber
augroup END
function! NumberToggle()
	if(&relativenumber == 1)
		set norelativenumber number
	else
		set relativenumber
	endif
endfunc
nnoremap <C-n> :call NumberToggle()<CR>

" 高亮配色
set cursorline		" 显示光标标线
set cursorcolumn
highlight CursorLine cterm=NONE ctermfg=NONE ctermbg=darkgray
highlight CursorColumn cterm=NONE ctermfg=NONE ctermbg=darkgray
highlight CursorLineNr cterm=NONE ctermfg=lightgreen ctermbg=NONE
" 设置Visual模式下选中区域颜色
highlight Visual cterm=NONE ctermfg=NONE ctermbg=gray

" 设置标记一列的背景颜色和数字一行颜色一致
hi! link SignColumn   LineNr

" 防止错误整行标红导致看不清
highlight clear SpellBad
highlight SpellBad term=standout ctermfg=1 term=underline cterm=underline
highlight clear SpellCap
highlight SpellCap term=underline cterm=underline
highlight clear SpellRare
highlight SpellRare term=underline cterm=underline
highlight clear SpellLocal
highlight SpellLocal term=underline cterm=underline

" 图形界面模式下补充参数
if has("gui_running")
    set guifont=Monaco:h14
    if has("gui_gtk2")   "GTK2
        set guifont=Monaco\ 12, Monospace\ 12
    endif
    set guioptions-=T
    set guioptions+=e
    set guioptions-=r
    set guioptions-=L
    set guitablabel=%M\ %t
    set showtabline=1
    set linespace=2
    set noimd
endif

"====================
" FileEncode Settings
"====================
" 文件编码
set encoding=utf-8
set fileencoding=utf-8
" 自动判断编码时，依次尝试以下编码：
set fileencodings=ucs-bom,utf-8,cp936,gb18030,big5,euc-jp,euc-kr,latin1
set helplang=cn

" Use Unix as the standard file type
set ffs=unix,dos,mac
if g:isunix
	set ff=unix
else
	set ff=dos
endif

" 如遇Unicode值大于255的文本，不必等到空格再折行。
set formatoptions+=m
" 合并两行中文时，不在中间加空格：
set formatoptions+=B

"====================
" Filetype Settings
"====================
" 突出显示超出第80列的所有内容及行末空格
highlight OverLength cterm=NONE ctermfg=white ctermbg=darkred
function! s:HighlightPythonOverLength() abort
    if exists('w:z_vim_overlength_match')
        silent! call matchdelete(w:z_vim_overlength_match)
    endif
    let w:z_vim_overlength_match = matchadd('OverLength', '\%>80v.\+\|\s\+$')
endfunction

" 文件保存时删除句尾空格
let s:trailing_ws_excluded_filetypes = ['markdown', 'gitcommit', 'mail', 'diff']
function! s:DeleteTrailingWS(force) abort
    if !a:force && index(s:trailing_ws_excluded_filetypes, &filetype) >= 0
        return
    endif
    let l:view = winsaveview()
    keeppatterns %s/\s\+$//e
    call winrestview(l:view)
endfunc
augroup z_vim_filetype
    autocmd!
    autocmd FileType python call <SID>HighlightPythonOverLength()
    autocmd BufWritePre * call <SID>DeleteTrailingWS(0)
augroup END
nnoremap <Leader><Space> :call <SID>DeleteTrailingWS(1)<CR>

"====================
" HotKey Settings
"====================
" 快速进入命令行
nnoremap ; :

" 命令行模式加强
cnoremap <C-j> <Down>
cnoremap <C-k> <Up>
cnoremap <C-a> <Home>
cnoremap <C-e> <End>

" Use sane regexes
nnoremap / /\v
vnoremap / /\v

" Keep search pattern at the center of the screen
nnoremap <silent> n nzz
nnoremap <silent> N Nzz
nnoremap <silent> * *zz
nnoremap <silent> # #zz
nnoremap <silent> g* g*zz

" 选择全部
nnoremap <Leader>sa ggVG
" 选择块
nnoremap <Leader>v V}

" 去掉搜索高亮
noremap <silent> <Leader>/ :noh<CR>

"====================
" Others
"====================
if g:isunix
    augroup z_vim_reload
        autocmd!
        autocmd BufWritePost .vimrc source % "vimrc文件修改之后自动加载(unix)
    augroup END
else
    augroup z_vim_reload
        autocmd!
        autocmd BufWritePost _vimrc source % "vimrc文件修改之后自动加载(windows)
    augroup END
endif

" auto-complete configuration
set completeopt=longest,menu

" 增强模式中的命令行自动完成操作
set wildmenu
set wildignore+=*.o,*~,*.pyc,*.class

" 离开插入模式后自动关闭预览窗口
augroup z_vim_completion
    autocmd!
    autocmd InsertLeave * if pumvisible() == 0 | pclose | endif
augroup END
" 若下拉菜单显示，则映射为前值。<C-y>确认并退出；<C-e>取消并退出。
inoremap <expr> <CR>    pumvisible() ? "\<C-y>" : "\<CR>"
inoremap <expr> <ESC>   pumvisible() ? "\<C-e>" : "\<ESC>"
inoremap <expr> <Down>  pumvisible() ? "\<C-n>" : "\<Down>"
inoremap <expr> <Up>    pumvisible() ? "\<C-p>" : "\<Up>"


"End-of-Config
