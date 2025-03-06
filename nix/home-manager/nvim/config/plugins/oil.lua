require("oil").setup {
	view_options = {
		show_hidden = true,
	},
	keymaps = {
		-- defaults
		-- ["g?"] = { "actions.show_help", mode = "n" },
		-- ["<CR>"] = "actions.select",
		-- ["<C-s>"] = { "actions.select", opts = { vertical = true } },
		-- ["<C-h>"] = { "actions.select", opts = { horizontal = true } },
		-- ["<C-t>"] = { "actions.select", opts = { tab = true } },
		-- ["<C-p>"] = "actions.preview",
		-- ["<C-c>"] = { "actions.close", mode = "n" },
		-- ["<C-l>"] = "actions.refresh",
		-- ["-"] = { "actions.parent", mode = "n" },
		-- ["_"] = { "actions.open_cwd", mode = "n" },
		-- ["`"] = { "actions.cd", mode = "n" },
		-- ["~"] = { "actions.cd", opts = { scope = "tab" }, mode = "n" },
		-- ["gs"] = { "actions.change_sort", mode = "n" },
		-- ["gx"] = "actions.open_external",
		-- ["g."] = { "actions.toggle_hidden", mode = "n" },
		-- ["g\\"] = { "actions.toggle_trash", mode = "n" },


		-- unbind these since use them for navigation
		["<C-h>"] = false,
		["<C-l>"] = false,
		-- make this match split bindings (s opens a split below the current)
		["<C-s>"] = { "actions.select", opts = { horizontal = true } },
	},
}

vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })
