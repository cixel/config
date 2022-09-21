require 'nvim-treesitter.configs'.setup {
	-- ensure_installed = "all", -- "all", or a list of languages
	ensure_installed = {}, -- https://github.com/NixOS/nixpkgs/issues/189838#issuecomment-1239101579
	-- ignore_install = { "go" }, -- List of parsers to ignore installing
	highlight = {
		enable = true, -- false will disable the whole extension
		additional_vim_regex_highlighting = false,
	},
	indent = {
		enable = true,
	},
	incremental_selection = {
		enable = true,
		keymaps = {
			init_selection = "gn",
			node_incremental = "gn",
			scope_incremental = "g,",
			node_decremental = "gm",
		},
	},
	-- andymass/vim-matchup/
	matchup = {
		enable = true,
	},
	textobjects = {
		move = {
			enable = true,
			set_jumps = true, -- whether to set jumps in the jumplist
			goto_next_start = {
				["]k"] = "@class.outer",
				["]]"] = "@function.outer",
				["]f"] = "@function.outer",
				["]c"] = "@comment.outer",
				["]a"] = "@parameter.outer",
				["]q"] = "@call.outer",
				["]l"] = "@loop.outer",
				["]v"] = "@variable.outer",
			},
			goto_next_end = {
				["]K"] = "@class.outer",
				["]["] = "@function.outer",
				["]F"] = "@function.outer",
				["]C"] = "@comment.outer",
				["]A"] = "@parameter.outer",
				["]Q"] = "@call.outer",
				["]L"] = "@loop.outer",
				["]V"] = "@variable.outer",
			},
			goto_previous_start = {
				["[k"] = "@class.outer",
				["[["] = "@function.outer",
				["[f"] = "@function.outer",
				["[c"] = "@comment.outer",
				["[a"] = "@parameter.outer",
				["[q"] = "@call.outer",
				["[l"] = "@loop.outer",
				["[v"] = "@variable.outer",
			},
			goto_previous_end = {
				["[K"] = "@class.outer",
				["[]"] = "@function.outer",
				["[F"] = "@function.outer",
				["[C"] = "@comment.outer",
				["[A"] = "@parameter.outer",
				["[Q"] = "@call.outer",
				["[L"] = "@loop.outer",
				["[V"] = "@variable.outer",
			},
		},

		swap = {
			enable = true,
			swap_next = {
				["<leader>a"] = "@parameter.inner",
			},
			swap_previous = {
				["<leader>A"] = "@parameter.inner",
			},
		},

		select = {
			enable = true,

			-- Automatically jump forward to textobj, similar to targets.vim
			lookahead = true,

			-- https://github.com/nvim-treesitter/nvim-treesitter-textobjects#built-in-textobjects
			keymaps = {
				["af"] = "@function.outer",
				["if"] = "@function.inner",

				-- don't really need both but i feel like my fingers are gonna
				-- be weird about "in comment"
				["ac"] = "@comment.outer",
				["ic"] = "@comment.outer",

				-- "klass"
				["ak"] = "@class.outer",
				["ik"] = "@class.inner",
				["al"] = "@loop.outer",
				["il"] = "@loop.inner",
				["ab"] = "@block.outer",
				["ib"] = "@block.inner",
				["av"] = "@variable.outer",
				["iv"] = "@variable.inner",
				-- "arg"
				["aa"] = "@parameter.outer",
				["ia"] = "@parameter.inner",

				-- ... "qall"?
				["aq"] = "@call.outer",
				["iq"] = "@call.inner",
			},
		},
	},
}

-- https://github.com/nvim-treesitter/nvim-treesitter-textobjects/issues/6
local move = require 'nvim-treesitter.textobjects.move'
local opt = { silent = true }
vim.keymap.set('v', '[C', function() move.goto_previous_end('@comment.outer') end, opt)
vim.keymap.set('v', '[F', function() move.goto_previous_end('@function.outer') end, opt)
vim.keymap.set('v', '[]', function() move.goto_previous_end('@function.outer') end, opt)
vim.keymap.set('v', '[K', function() move.goto_previous_end('@class.outer') end, opt)
vim.keymap.set('v', '[V', function() move.goto_previous_end('@variable.outer') end, opt)
vim.keymap.set('v', '[L', function() move.goto_previous_end('@loop.outer') end, opt)
vim.keymap.set('v', '[Q', function() move.goto_previous_end('@call.outer') end, opt)
vim.keymap.set('v', '[A', function() move.goto_previous_end('@parameter.outer') end, opt)
vim.keymap.set('v', '[a', function() move.goto_previous_start('@parameter.outer') end, opt)
vim.keymap.set('v', '[c', function() move.goto_previous_start('@comment.outer') end, opt)
vim.keymap.set('v', '[f', function() move.goto_previous_start('@function.outer') end, opt)
vim.keymap.set('v', '[[', function() move.goto_previous_start('@function.outer') end, opt)
vim.keymap.set('v', '[k', function() move.goto_previous_start('@class.outer') end, opt)
vim.keymap.set('v', '[v', function() move.goto_previous_start('@variable.outer') end, opt)
vim.keymap.set('v', '[l', function() move.goto_previous_start('@loop.outer') end, opt)
vim.keymap.set('v', '[q', function() move.goto_previous_start('@call.outer') end, opt)
vim.keymap.set('v', ']Q', function() move.goto_next_end('@call.outer') end, opt)
vim.keymap.set('v', ']A', function() move.goto_next_end('@parameter.outer') end, opt)
vim.keymap.set('v', ']C', function() move.goto_next_end('@comment.outer') end, opt)
vim.keymap.set('v', ']F', function() move.goto_next_end('@function.outer') end, opt)
vim.keymap.set('v', '][', function() move.goto_next_end('@function.outer') end, opt)
vim.keymap.set('v', ']K', function() move.goto_next_end('@class.outer') end, opt)
vim.keymap.set('v', ']V', function() move.goto_next_end('@variable.outer') end, opt)
vim.keymap.set('v', ']L', function() move.goto_next_end('@loop.outer') end, opt)
vim.keymap.set('v', ']v', function() move.goto_next_start('@variable.outer') end, opt)
vim.keymap.set('v', ']f', function() move.goto_next_start('@function.outer') end, opt)
vim.keymap.set('v', ']l', function() move.goto_next_start('@loop.outer') end, opt)
vim.keymap.set('v', ']]', function() move.goto_next_start('@function.outer') end, opt)
vim.keymap.set('v', ']q', function() move.goto_next_start('@call.outer') end, opt)
vim.keymap.set('v', ']k', function() move.goto_next_start('@class.outer') end, opt)
vim.keymap.set('v', ']a', function() move.goto_next_start('@parameter.outer') end, opt)
vim.keymap.set('v', ']c', function() move.goto_next_start('@comment.outer') end, opt)
