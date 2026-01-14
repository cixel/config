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

-- Don't resolve symlinks to their target on select; open the symlink path
-- itself. Oil's only symlink-resolution point is the files adapter's
-- normalize_url (it calls uv.fs_realpath), which init.lua documents as the
-- intended hook for link following. We replace it with a version that keeps
-- the symlink path but still stats through it to classify file vs directory.
-- do
-- 	local fs = require("oil.fs")
-- 	local util = require("oil.util")
-- 	local files = require("oil.adapters.files")
-- 	local uv = vim.uv or vim.loop
--
-- 	files.normalize_url = function(url, callback)
-- 		local scheme, path = util.parse_url(url)
-- 		assert(path)
--
-- 		if fs.is_windows then
-- 			if path == "/" then
-- 				return callback(url)
-- 			end
-- 			if path:match("^/%u$") then
-- 				return callback(url .. "/")
-- 			end
-- 		end
--
-- 		local os_path = vim.fn.fnamemodify(fs.posix_to_os_path(path), ":p")
-- 		uv.fs_stat(
-- 			os_path,
-- 			vim.schedule_wrap(function(_, stat)
-- 				local is_directory
-- 				if stat then
-- 					is_directory = stat.type == "directory"
-- 				elseif vim.endswith(os_path, "/") or (fs.is_windows and vim.endswith(os_path, "\\")) then
-- 					is_directory = true
-- 				else
-- 					local filetype = vim.filetype.match({ filename = vim.fs.basename(os_path) })
-- 					is_directory = filetype == nil
-- 				end
--
-- 				if is_directory then
-- 					callback(scheme .. util.addslash(fs.os_to_posix_path(os_path)))
-- 				else
-- 					callback(os_path)
-- 				end
-- 			end)
-- 		)
-- 	end
-- end

vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })
