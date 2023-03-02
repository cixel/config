local nvim_tree = require('nvim-tree')
nvim_tree.setup({
	diagnostics = {
		enable = true, -- default is false
		icons = {
			hint = "H",
			info = "I",
			warning = "W",
			error = "E",
		},
	},
	remove_keymaps = { "m" },
	git = {
		ignore = false,
	},
	renderer = {
		add_trailing = true,
		icons = {
			webdev_colors = true,
			git_placement = "after",
			padding = "",
			symlink_arrow = " -> ",
			show = {
				file = true,
				folder = true,
				folder_arrow = true,
				git = true,
			},
			glyphs = {
				default = "",
				symlink = "",
				bookmark = "",
				folder = {
					arrow_closed = "▸",
					arrow_open = "▾",
					default = "",
					open = "",
					empty = "",
					empty_open = "",
					symlink = "",
					symlink_open = "",
				},
				git = {
					unstaged = "!",
					staged = "+",
					unmerged = "?",
					renamed = "➜",
					untracked = "★",
					deleted = "x",
					ignored = "-",
				},
			},
		},
	},
	update_focused_file = {
		update_root = true,
	},
})


vim.keymap.set('n', '\\e', '<cmd>NvimTreeToggle<CR>', { silent = true })
vim.keymap.set('n', '\\E', '<cmd>NvimTreeFindFileToggle<CR>', { silent = true })
