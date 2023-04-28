vim.opt.background = 'dark'
vim.opt.termguicolors = true
vim.g['gruvbox_contrast_dark'] = 'hard'
vim.cmd [[colorscheme gruvbox]]

vim.opt.list = true

local hl_yank = vim.api.nvim_create_augroup('highlight_yank', { clear = true })
vim.api.nvim_create_autocmd('TextYankPost', {
	desc = 'highlight on yank',
	callback = function()
		vim.highlight.on_yank({ higroup = 'IncSearch', timeout = 150 })
	end,
	group = hl_yank,
})
