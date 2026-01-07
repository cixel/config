vim.api.nvim_create_autocmd('FileType', {
	group = vim.api.nvim_create_augroup('ui.treesitter', { clear = true }),
	pattern = '*',
	callback = function(e)
		local lang = vim.treesitter.language.get_lang(e.match) or ""
		if vim.treesitter.language.add(lang) then
			-- according to docs, also disables regex syntax highlighting
			vim.treesitter.start()
			vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
		end
	end,
	desc = 'enable treesitter for available languages',
})

require('nvim-treesitter-textobjects').setup {
	select = {
		-- automatically jump forward to textobj.vim. this is what lets me
		-- `vif` to a function my cursor isn't in yet
		lookahead = true,
	},
	move = {
		-- whether to set jumps in the jumplist
		set_jumps = true,
	}
}

local function bind_select(lhs, query)
	vim.keymap.set(
		{
			"o", -- operator pending
			"x" -- executing an autocommand
		},
		lhs,
		function()
			require("nvim-treesitter-textobjects.select").select_textobject(query, "textobjects")
		end,
		{ silent = true }
	)
end

-- https://github.com/nvim-treesitter/nvim-treesitter-textobjects#built-in-textobjects
bind_select("af", "@function.outer")
bind_select("if", "@function.inner")
-- don't really need both but i feel like my fingers are gonna
-- be weird about "in comment"
bind_select("ac", "@comment.outer")
bind_select("ic", "@comment.outer")
-- "klass"
bind_select("ak", "@class.outer")
bind_select("ik", "@class.inner")
bind_select("al", "@loop.outer")
bind_select("il", "@loop.inner")
bind_select("ab", "@block.outer")
bind_select("ib", "@block.inner")
bind_select("av", "@variable.outer")
bind_select("iv", "@variable.inner")
-- "arg"
bind_select("aa", "@parameter.outer")
bind_select("ia", "@parameter.inner")
-- ... "qall"?
bind_select("aq", "@call.outer")
bind_select("iq", "@call.inner")

local function bind_swap(lhs, query, direction)
	vim.keymap.set("n", lhs,
		function()
			require("nvim-treesitter-textobjects.swap")["swap_" .. direction](query)
		end,
		{ silent = true }
	)
end

bind_swap("<leader>a", "@parameter.inner", "next")
bind_swap("<leader>A", "@parameter.inner", "previous")

-- https://github.com/nvim-treesitter/nvim-treesitter-textobjects/issues/6
local move = require 'nvim-treesitter-textobjects.move'
local mode = { "n", "v", "x", "o" }
local opt = { silent = true }
vim.keymap.set(mode, '[[', function() move.goto_previous_start('@function.outer') end, opt)
vim.keymap.set(mode, '[]', function() move.goto_previous_end('@function.outer') end, opt)
vim.keymap.set(mode, '][', function() move.goto_next_end('@function.outer') end, opt)
vim.keymap.set(mode, ']]', function() move.goto_next_start('@function.outer') end, opt)

vim.keymap.set(mode, '[A', function() move.goto_previous_end('@parameter.outer') end, opt)
vim.keymap.set(mode, '[a', function() move.goto_previous_start('@parameter.outer') end, opt)
vim.keymap.set(mode, ']A', function() move.goto_next_end('@parameter.outer') end, opt)
vim.keymap.set(mode, ']a', function() move.goto_next_start('@parameter.outer') end, opt)

vim.keymap.set(mode, '[C', function() move.goto_previous_end('@comment.outer') end, opt)
vim.keymap.set(mode, '[c', function() move.goto_previous_start('@comment.outer') end, opt)
vim.keymap.set(mode, ']C', function() move.goto_next_end('@comment.outer') end, opt)
vim.keymap.set(mode, ']c', function() move.goto_next_start('@comment.outer') end, opt)

vim.keymap.set(mode, '[F', function() move.goto_previous_end('@function.outer') end, opt)
vim.keymap.set(mode, '[f', function() move.goto_previous_start('@function.outer') end, opt)
vim.keymap.set(mode, ']F', function() move.goto_next_end('@function.outer') end, opt)
vim.keymap.set(mode, ']f', function() move.goto_next_start('@function.outer') end, opt)

vim.keymap.set(mode, '[K', function() move.goto_previous_end('@class.outer') end, opt)
vim.keymap.set(mode, '[k', function() move.goto_previous_start('@class.outer') end, opt)
vim.keymap.set(mode, ']K', function() move.goto_next_end('@class.outer') end, opt)
vim.keymap.set(mode, ']k', function() move.goto_next_start('@class.outer') end, opt)

vim.keymap.set(mode, '[L', function() move.goto_previous_end('@loop.outer') end, opt)
vim.keymap.set(mode, '[l', function() move.goto_previous_start('@loop.outer') end, opt)
vim.keymap.set(mode, ']L', function() move.goto_next_end('@loop.outer') end, opt)
vim.keymap.set(mode, ']l', function() move.goto_next_start('@loop.outer') end, opt)

vim.keymap.set(mode, '[Q', function() move.goto_previous_end('@call.outer') end, opt)
vim.keymap.set(mode, '[q', function() move.goto_previous_start('@call.outer') end, opt)
vim.keymap.set(mode, ']Q', function() move.goto_next_end('@call.outer') end, opt)
vim.keymap.set(mode, ']q', function() move.goto_next_start('@call.outer') end, opt)

vim.keymap.set(mode, '[V', function() move.goto_previous_end('@variable.outer') end, opt)
vim.keymap.set(mode, '[v', function() move.goto_previous_start('@variable.outer') end, opt)
vim.keymap.set(mode, ']V', function() move.goto_next_end('@variable.outer') end, opt)
vim.keymap.set(mode, ']v', function() move.goto_next_start('@variable.outer') end, opt)

vim.keymap.set(mode, '[K', function() move.goto_previous_end('@class.outer') end, opt)
vim.keymap.set(mode, '[k', function() move.goto_previous_start('@class.outer') end, opt)
vim.keymap.set(mode, ']K', function() move.goto_next_end('@class.outer') end, opt)
vim.keymap.set(mode, ']k', function() move.goto_next_start('@class.outer') end, opt)

local ts_context = require('treesitter-context')
ts_context.setup {
	enable = true,
}
vim.keymap.set('n', '<leader>l', function() ts_context.toggle() end, opt)
