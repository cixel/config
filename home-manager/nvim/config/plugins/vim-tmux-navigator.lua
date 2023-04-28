vim.g.tmux_navigator_no_mappings = 1
vim.keymap.set('n', '<C-h>', ':TmuxNavigateLeft<CR>', { silent = true })
vim.keymap.set('n', '<C-j>', ':TmuxNavigateDown<CR>', { silent = true })
vim.keymap.set('n', '<C-k>', ':TmuxNavigateUp<CR>', { silent = true })
vim.keymap.set('n', '<C-l>', ':TmuxNavigateRight<CR>', { silent = true })
vim.keymap.set('n', '<C-\\>', ':TmuxNavigatePrevious<CR>', { silent = true })

if vim.fn.exists('$TMUX') then
	vim.api.nvim_create_autocmd(
		{ 'BufReadPost', 'FileReadPost', 'BufNewFile', 'BufEnter' },
		{
			pattern = '*',
			callback = function()
				local t = vim.fn.expand('%:t')
				vim.fn.system('tmux rename-window ' .. t)
			end,
		}
	)
	vim.api.nvim_create_autocmd(
		{ 'VimLeave' },
		{
			pattern = '*',
			callback = function()
				vim.fn.system('tmux setw automatic-rename')
			end,
		}
	)
end
