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
let g:isdos = 0
let g:isunix = 0
if(has("win64") || has("win32") || has("win95") || has("win16"))
    let g:isdos = 1
	set shellslash	" 路径使用左斜杠
else
    let g:isunix = 1
endif

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
    autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$")
                \ | exe "normal! g'\""
                \ | exe "normal! g`\""
                \ | exe "normal! zz" | endif
endif

" 创建持久性撤销记录
if has('persistent_undo')
	set undofile
    if g:isunix
		set undodir=/tmp/vimundo/
        " :help set
        "space between '=' and {value} is not allowed.
    else
        let &undodir = expand('$HOME/vimfiles/vimundo/')
        " :help let
        "'let &{option}' equals to 'set {option}', but more flexible.
	endif
	silent call mkdir(&undodir, 'p')
endif

" remain the content after quit
set t_ti= t_te=
" remember info about open buffers on close
set viminfo^=%
" enabled to paste more than 50 lines
set viminfo='1000,<1000
" turn magic on for regular expressions
set magic

" 支持在Visual模式下，通过C-y复制到系统剪切板
vnoremap <C-y> "+y
" 支持在normal模式下，通过C-p粘贴系统剪切板
nnoremap <C-p> "*p

"====================
" Display Settings
"====================
" 基础设置
syntax enable       " 语法高亮
set number		    " 显示行号
set ruler		    " 显示标尺
set autoindent      " 自动缩进
set smartindent	    " 智能缩进
set nowrap		    " 关闭自动折行
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
set textwidth=1000	" 设置最大行宽

" Relative Line Number
set relativenumber number
au FocusLost * :set norelativenumber number
au FocusGained * :set relativenumber
" Use Absolute Line Number while typing
autocmd InsertEnter * :set norelativenumber number
autocmd InsertLeave * :set relativenumber
function! NumberToggle()
	if(&relativenumber == 1)
		set norelativenumber number
	else
		set relativenumber
	endif
endfunc
nnoremap <C-n> :call NumberToggle()<CR>

" 高亮配色
set t_Co=256		" 开启256色
set cursorline		" 显示光标标线
set cursorcolumn
highlight CursorLine cterm=NONE ctermfg=NONE ctermbg=darkgray
highlight CursorColumn cterm=NONE ctermfg=NONE ctermbg=darkgray
highlight CursorLineNr cterm=NONE ctermfg=lightgreen ctermbg=NONE
" 设置Visual模式下选中区域颜色
highlight Visual cterm=NONE ctermfg=NONE ctermbg=gray

" 设置标记一列的背景颜色和数字一行颜色一致
hi! link SignColumn   LineNr
hi! link ShowMarksHLl DiffAdd
hi! link ShowMarksHLu DiffChange

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
" 下面这句只影响非图形界面下的Vim
set termencoding=utf-8

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
au BufRead,BufNewFile *.py match OverLength /\%>80v.\+\|\s\+$/

" 文件保存时删除句尾空格
function! DeleteTrailingWS() abort
	normal mz
	%s/\s\+$//ge
	normal `z
endfunc
autocmd BufWrite * :call DeleteTrailingWS()
nnoremap <Leader><Space> :call DeleteTrailingWS()

"====================
" HotKey Settings
"====================
" 快速进入命令行
nnoremap ; :

" 命令行模式加强
cnoremap <C-j> <t_kd>
cnoremap <C-k> <t_ku>
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
nnoremap <Leader>sa ggVG"
" 选择块
nnoremap <Leader>v V'}

" 去掉搜索高亮
noremap <silent> <Leader>/ :noh<CR>

" 大括号自动补全
inoremap {<CR> {}<ESC>i<CR><ESC>O

"====================
" Others
"====================
if g:isunix
    autocmd! bufwritepost .vimrc source % "vimrc文件修改之后自动加载(linux)
else
    autocmd! bufwritepost _vimrc source % "vimrc文件修改之后自动加载(windows)
endif

" auto-complete configuration
set completeopt=longest,menu

" 增强模式中的命令行自动完成操作
set wildmenu
set wildignore+=*.o,*~,*.pyc,*.class

" 离开插入模式后自动关闭预览窗口
autocmd InsertLeave * if pumvisible() == 0 | pclose | endif
" 若下拉菜单显示，则映射为前值。<C-y>确认并退出；<C-e>取消并退出。
inoremap <expr> <CR>    pumvisible() ? "\<C-y>" : "\<CR>"
inoremap <expr> <ESC>   pumvisible() ? "\<C-e>" : "\<ESC>"
inoremap <expr> <Down>  pumvisible() ? "\<C-n>" : "\<Down>"
inoremap <expr> <Up>    pumvisible() ? "\<C-p>" : "\<Up>"


"End-of-Config
