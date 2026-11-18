vim.g.tmux_navigator_no_mappings = 1

local in_tmux = vim.env.TMUX ~= nil
-- Rex sets REX_SESSION in every terminal it starts. Inside tmux, tmux owns
-- the splits, so only take the Rex path when tmux isn't in between.
local in_rex = not in_tmux and vim.env.REX_SESSION ~= nil

if in_rex then
	-- Same idea as vim-tmux-navigator: move between nvim windows, and at the
	-- edge hand off to Rex. The Rex side (rex/init.lua) passes C-h/j/k/l
	-- through to nvim when it's the foreground process.
	local rex = vim.env.REX_BIN_DIR and (vim.env.REX_BIN_DIR .. '/rex') or 'rex'
	local function navigate(wincmd, direction)
		return function()
			local win = vim.api.nvim_get_current_win()
			vim.cmd.wincmd(wincmd)
			if vim.api.nvim_get_current_win() == win then
				-- Async so nvim never blocks on the server. Rex stops at the
				-- layout edge rather than wrapping.
				vim.system({ rex, 'focus', direction, '-s', vim.env.REX_SESSION })
			end
		end
	end
	vim.keymap.set('n', '<C-h>', navigate('h', 'left'), { silent = true })
	vim.keymap.set('n', '<C-j>', navigate('j', 'down'), { silent = true })
	vim.keymap.set('n', '<C-k>', navigate('k', 'up'), { silent = true })
	vim.keymap.set('n', '<C-l>', navigate('l', 'right'), { silent = true })
	vim.keymap.set('n', '<C-\\>', '<Cmd>wincmd p<CR>', { silent = true })
else
	vim.keymap.set('n', '<C-h>', ':TmuxNavigateLeft<CR>', { silent = true })
	vim.keymap.set('n', '<C-j>', ':TmuxNavigateDown<CR>', { silent = true })
	vim.keymap.set('n', '<C-k>', ':TmuxNavigateUp<CR>', { silent = true })
	vim.keymap.set('n', '<C-l>', ':TmuxNavigateRight<CR>', { silent = true })
	vim.keymap.set('n', '<C-\\>', ':TmuxNavigatePrevious<CR>', { silent = true })
end

-- vim.fn.exists() returns 0 or 1, and 0 is truthy in Lua, so check the
-- environment directly. Otherwise this shells out to tmux on every BufEnter
-- even outside tmux.
if in_tmux then
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
