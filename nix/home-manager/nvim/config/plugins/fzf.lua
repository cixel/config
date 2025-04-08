local fzf_lua = require('fzf-lua')
-- https://github.com/ibhagwan/fzf-lua/blob/main/lua/fzf-lua/profiles/max-perf.lua
fzf_lua.setup({
	'max-perf',
	keymap = {
		fzf = {
			true, -- inherit default bindings
			["tab"] = "down",
			["ctrl-j"] = "down",
			["shift-tab"] = "up",
			["ctrl-k"] = "up",
			["right"] = "toggle+down",
			["left"] = "toggle+up",
			["ctrl-space"] = "toggle",
			["ctrl-y"] = "accept",
		},
	},
})

-- pass search="" to avoid the prompt we'd normally get
vim.keymap.set('n', '<leader>g', function() fzf_lua.grep({ search = "" }) end, { silent = true })
vim.keymap.set('n', '<leader>f', fzf_lua.grep_cword, { silent = true })
vim.keymap.set('n', '<leader>G', fzf_lua.live_grep, { silent = true })
vim.keymap.set('n', ';', fzf_lua.files, { silent = true })
vim.keymap.set('n', '<leader>t', fzf_lua.treesitter, { silent = true })
vim.keymap.set('n', '<leader>c', fzf_lua.git_commits, { silent = true })
vim.keymap.set('n', '<leader>b', fzf_lua.git_bcommits, { silent = true })
vim.keymap.set('n', '<leader>s', fzf_lua.lsp_live_workspace_symbols, { silent = true })
