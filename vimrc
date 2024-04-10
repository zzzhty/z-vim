"====================
" Author: ZhangTianyi
" Version: 1.2
" Email: tyz1024@gmail.com
" Sections:
"	-> InitialPlugins
"	-> General Settings
"	-> Display Settings
"	-> FileEncode Settings
"	-> Filetype Settings
"	-> HotKey Settings
"	-> Others


"====================
" Initial Plugins
"====================

" 修改leader键
let mapleader = ','
let g:mapleader = ','
let g:C_Mapleader = '\'

" Initial Vundle bundles
if filereadable(expand("~/.vimrc.bundles"))
	source ~/.vimrc.bundles
endif

" Ensure ftdetect et al. take effect after Vundle
filetype plugin indent on


"====================
" General Settings
"====================

" Set backspace
set backspace=indent,eol,start
set whichwrap+=<,>,h,l

" history storage
set history=2000

" detect the file type
filetype on
" adapt diffrent Format for different file type
filetype indent on
" plugins allowed
filetype plugin on
" autocomplete on
filetype plugin indent on

" autoread the file if modificated
set autoread

" disable the backup
set nobackup
" close the swapfile
set noswapfile

" create undo file
if has('persistent_undo')
	set undolevels=1000		"How many undos
	set undoreload=10000	"number of lines to save for undo
	set undofile
	set undodir=/tmp/vimundo/
endif

set wildignore=*.swp,*.bak,*.pyc,*.class,.svn

" remain the content after quit
set t_ti= t_te=

" remember info about open buffers on close
set viminfo^=%

" For regular expressiongs turn magic on
set magic

" Enabled to paste more than 50 lines
set viminfo='1000,<1000

" 支持在Visual模式下，通过C-y复制到系统剪切板
vnoremap <C-y> "+y
" 支持在normal模式下，通过C-p粘贴系统剪切板
nnoremap <C-p> "*p


"====================
" Display Settings
"====================

" Display basic
set ruler
set showmode
set showcmd

" scroll lines
set scrolloff=7

" display the line-number
set number

" Highlight the grammar
syntax on
noremap <F12> <Esc>:syntax sync fromstart<CR>
inoremap <F12> <C-o>:syntax sync fromstart<CR>

" Set the highlight tips
" hightlight the content in search
set hlsearch
" ignore the capslock
set ignorecase
" Smartcase
set smartcase

" Set TAB
set tabstop=4
set shiftwidth=4
set softtabstop=4

" Indent
set smartindent	"Smart indent
set autoindent	"auto indent

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
nnoremap <C-n> :call NumberToggle()<cr>

" 大括号自动完成并换行
inoremap {<CR> {}<ESC>i<CR><ESC>O
" { 加回车，自动换行；{ 加空格，则为补全大括号

" Set extra options when running in GUI mode
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

" 主题设置
" colorscheme solarized
" set background=dark

" 高亮配色
set t_Co=256	" 开启256色
set cursorline	" 显示光标标线
set cursorcolumn
highlight CursorLine cterm=NONE ctermfg=NONE ctermbg=darkgray
highlight CursorColumn cterm=NONE ctermfg=NONE ctermbg=darkgray
highlight CursorLineNr cterm=NONE ctermfg=lightgreen ctermbg=NONE
" 突出显示超出第80列的所有内容及行末空格
highlight OverLength cterm=NONE ctermfg=white ctermbg=darkred
au BufRead,BufNewFile *.py match OverLength /\%>80v.\+\|\s\+$/

" 设置标记一列的背景颜色和数字一行颜色一致
hi! link SignColumn   LineNr
hi! link ShowMarksHLl DiffAdd
hi! link ShowMarksHLu DiffChange

" for error highlight，防止错误整行标红导致看不清
highlight clear SpellBad
highlight SpellBad term=standout ctermfg=1 term=underline cterm=underline
highlight clear SpellCap
highlight SpellCap term=underline cterm=underline
highlight clear SpellRare
highlight SpellRare term=underline cterm=underline
highlight clear SpellLocal
highlight SpellLocal term=underline cterm=underline


"====================
" FileEncode Settings
"====================

" set new file in UTF-8
set encoding=utf-8
set fileencoding=utf-8
" 自动判断编码时，依次尝试以下编码：
set fileencodings=ucs-bom,utf-8,cp936,gb18030,big5,euc-jp,euc-kr,latin1
set helplang=cn
" 下面这句只影响非图形界面下的Vim
set termencoding=utf-8

" Use Unix as the standard file type
set ffs=unix,dos,mac

" 如遇Unicode值大于255的文本，不必等到空格再折行。
set formatoptions+=m
" 合并两行中文时，不在中间加空格：
set formatoptions+=B


"====================
" Filetype Settings
"====================

" Python 文件的一般设置，比如不要 tab 等
autocmd FileType python set tabstop=4 shiftwidth=4 expandtab ai

" Delete trailing white space on save, useful for Python and CoffeeScript ;)
func! DeleteTrailingWS()
  exe "normal mz"
  %s/\s\+$//ge
  exe "normal `z"
endfunc
autocmd BufWrite *.py :call DeleteTrailingWS()

" 定义函数AutoSetFileHead，自动插入文件头
autocmd BufNewFile *.sh,*.py,*.pl exec ":call AutoSetFileHead()"
function! AutoSetFileHead()
    "如果文件类型为.sh文件
    if &filetype == 'sh'
        call setline(1, "\#!/bin/bash")
    endif

    "如果文件类型为python
    if &filetype == 'python'
        call setline(1, "\#!/usr/bin/env python")
        call append(1, "\# encoding: utf-8")
    endif

	"如果文件类型为perl
    if &filetype == 'perl'
        call setline(1, "\#!/usr/bin/env perl")
        call append(1, "\use strict;")
		call append(1, "\use warnings;")
		call append(1, "use utf8;")
    endif

    normal G
    normal o
    normal o
endfunc

" F10 to run python script
nnoremap <buffer> <F10> :exec '!python' shellescape(@%, 1)<cr>


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

" 去掉搜索高亮
noremap <silent><leader>/ :nohls<CR>

" 选择全部
nnoremap <leader>sa ggVG"
" 选择块
nnoremap <leader>v V'}


"====================
" Others
"====================

autocmd! bufwritepost _vimrc source % "vimrc文件修改之后自动加载(windows)
autocmd! bufwritepost .vimrc source % "vimrc文件修改之后自动加载(linux)

" auto-complete configuration
set completeopt=longest,menu

" 增强模式中的命令行自动完成操作
set wildmenu
" Ignore compiled files
set wildignore=*.o,*~,*.pyc,*.class

" 离开插入模式后自动关闭预览窗口
autocmd InsertLeave * if pumvisible() == 0|pclose|endif
" 回车即选中当前项
inoremap <expr> <CR>       pumvisible() ? "\<C-y>" : "\<CR>"

" 上下左右键的行为 会显示其他信息
inoremap <expr> <Down>     pumvisible() ? "\<C-n>" : "\<Down>"
inoremap <expr> <Up>       pumvisible() ? "\<C-p>" : "\<Up>"
inoremap <expr> <PageDown> pumvisible() ? "\<PageDown>\<C-p>\<C-n>" : "\<PageDown>"
inoremap <expr> <PageUp>   pumvisible() ? "\<PageUp>\<C-p>\<C-n>" : "\<PageUp>"

" 打开文件回到之前位置
" if this not work, make sure .viminfo is writable for you
if has("autocmd")
	au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
endif


"End-of-Config
