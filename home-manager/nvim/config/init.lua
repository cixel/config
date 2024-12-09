-- https://github.com/neovim/neovim/commit/2257ade3dc2daab5ee12d27807c0b3bcf103cd29
vim.loader.enable()

vim.g.mapleader = ','

-- don't try to load perl provider
-- (other providers are disabled for me in code generated by nix)
vim.g.loaded_perl_provider = 0

-- remap split switching
vim.keymap.set('n', '<tab>', '<c-w>')
-- open current file in new tab
vim.keymap.set('n', '<tab>t', ':tabe % <cr>', { silent = true })

-- change j and k to move by row instead of by line
vim.keymap.set('n', 'j', 'gj')
vim.keymap.set('n', 'k', 'gk')

-- relative line numbers
vim.opt.number = true
vim.opt.relativenumber = true
local relative_line_nums = vim.api.nvim_create_augroup('relative_line_nums', { clear = true })
vim.api.nvim_create_autocmd(
	{ 'InsertEnter', 'FocusLost', 'WinLeave' },
	{
		desc = 'disable relative line numbers in insert mode or when switching focus',
		pattern = '*',
		callback = function()
			if vim.wo.number then
				vim.opt.relativenumber = false
			end
		end,
		group = relative_line_nums,
	}
)
vim.api.nvim_create_autocmd(
	{ 'InsertLeave', 'FocusGained', 'WinEnter' },
	{
		desc = 'enable relative line numbers for normal mode on focused buffers',
		pattern = '*',
		callback = function()
			if vim.wo.number then
				vim.opt.relativenumber = true
			end
		end,
		group = relative_line_nums,
	}
)

-- some minor performance things
vim.opt.showcmd = false
vim.opt.lazyredraw = true

-- default tab behavior
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4

-- search settings
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = false

vim.opt.undodir = vim.fn.stdpath('cache') .. '/vimdid'
vim.opt.undofile = true

-- do not require scratch/fileless buffers to be saved
vim.opt.hidden = true

-- yank to clipboard
vim.opt.clipboard = 'unnamed'
-- copy clipboard in between "" or '
vim.keymap.set('n', '<leader>"', 'i"<Esc>p', { silent = true })
vim.keymap.set('n', '<leader>\'', 'i\'<Esc>p', { silent = true })

-- https://github.com/neovim/neovim/issues/416 changed the default for Y to y$,
-- which is admittedly more sensible, but my fingers refuse. double tapping y
-- feels worse/slower than shift-y just because of where y is
vim.keymap.set('n', 'Y', 'yy')

-- remap next/previous buffer
vim.keymap.set('n', '<C-n>', ':bnext<CR>', { silent = true })
vim.keymap.set('n', '<C-m>', ':bprev<CR>', { silent = true })
vim.keymap.set('n', '<C-e>', ':e#<CR>', { silent = true })

-- fold with treesitter
vim.opt.foldlevelstart = 99 -- so files are not folded when vim starts
vim.opt.foldmethod = 'expr'
vim.opt.foldexpr = 'nvim_treesitter#foldexpr()'

-- move selected text up/down with J/K
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

vim.opt.background = 'dark'
vim.opt.termguicolors = true

vim.opt.list = true
vim.opt.listchars = {
	-- the '·' is always used, then ' ' is used as many times as it will fit (based on tabstop)
	tab = '. ',
	trail = '-',
	nbsp = '+'
}
-- vim.api.nvim_create_autocmd(
-- 	{ 'BufReadPost', 'FileReadPost', 'BufNewFile', 'BufEnter' },
-- 	{
-- 		desc = 'disable list chars for go files',
-- 		pattern = '*',
-- 		callback = function()
-- 			if vim.bo.filetype == "go" then
-- 				vim.opt.list = false
-- 				return
-- 			end
-- 			vim.opt.list = true
-- 		end,
-- 	}
-- )

local hl_yank = vim.api.nvim_create_augroup('highlight_yank', { clear = true })
vim.api.nvim_create_autocmd('TextYankPost', {
	desc = 'highlight on yank',
	callback = function()
		vim.highlight.on_yank({ higroup = 'IncSearch', timeout = 150 })
	end,
	group = hl_yank,
})

vim.api.nvim_create_user_command('MakeGo', function()
	os.execute('./make.bash')
	vim.api.nvim_cmd({ cmd = 'LspRestart' }, { output = true })
end, {})
