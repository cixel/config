require('copilot').setup({
	panel = {
		enabled = false,
	},
	suggestion = {
		enabled = false,
		-- enable for copilot to start suggesting as soon as you enter insert mode
		auto_trigger = false,
	},
	filetypes = {
		yaml = false,
		markdown = false,
		help = false,
		gitcommit = false,
		gitrebase = false,
		hgcommit = false,
		svn = false,
		cvs = false,
		["."] = false,
	},
	copilot_node_command = 'node', -- Node.js version must be > 16.x
	server_opts_overrides = {},
})
