require('copilot').setup({
	panel = {
		enabled = false,
	},
	suggestion = {
		enabled = false,
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
	server_opts_overrides = {},
	server = {
		type = 'binary',
		-- this should be installed by home-manager in extraPackages
		custom_server_filepath = vim.fn.exepath('copilot-language-server'),
	},
})
