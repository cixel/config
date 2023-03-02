local nvim_lsp = require('lspconfig')
-- vim.lsp.set_log_level("debug")
vim.diagnostic.config({
	virtual_text = {},
	float = {
		source = "always",
	},
})

vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
	vim.lsp.diagnostic.on_publish_diagnostics, {
	signs = true,
	update_in_insert = false,
}
)

vim.api.nvim_create_autocmd("VimEnter", {
	pattern = "*",
	callback = function()
		vim.keymap.set(
			'n', '<C-q>',
			function() vim.diagnostic.goto_next({ enable_popup = false }) end,
			{ silent = true }
		)
		vim.keymap.set(
			'n', '<C-S-Q>',
			function() vim.diagnostic.goto_prev({ enable_popup = false }) end,
			{ silent = true }
		)
	end,
	desc = "set lsp diagnostic highlights and mappings",
})

-- Use an on_attach function to only map the following keys
-- after the language server attaches to the current buffer
local on_attach = function(client, bufnr)
	local buf_set_keymap = function(mode, lhs, callback)
		vim.keymap.set(mode, lhs, callback, {
			silent = true,
			buffer = bufnr,
		})
	end

	-- local buf_set_option = function(...)
	-- vim.api.nvim_buf_set_option(bufnr, ...)
	-- end
	-- Enable completion triggered by <c-x><c-o>
	-- buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

	-- See `:help vim.lsp.*` for documentation on any of the below functions
	buf_set_keymap('n', 'gD', vim.lsp.buf.declaration)
	buf_set_keymap('n', 'gd', vim.lsp.buf.definition)

	buf_set_keymap('n', 'K', vim.lsp.buf.hover)
	-- buf_set_keymap('n', 'K', ':Lspsaga hover_doc<CR>', opts)

	buf_set_keymap('n', '<leader>rn', vim.lsp.buf.rename)
	buf_set_keymap('n', 'gi', vim.lsp.buf.implementation)

	-- buf_set_keymap('n', '<C-k>', vim.lsp.buf.signature_help)
	buf_set_keymap('n', '<C-s>', vim.lsp.buf.signature_help)

	buf_set_keymap('n', '<leader>wa', vim.lsp.buf.add_workspace_folder)
	buf_set_keymap('n', '<leader>wr', vim.lsp.buf.remove_workspace_folder)
	buf_set_keymap('n', '<leader>wl', function() print(vim.inspect(vim.lsp.buf.list_workspace_folders())) end)
	buf_set_keymap('n', '<leader>D', vim.lsp.buf.type_definition)
	buf_set_keymap('n', '<leader>ca', vim.lsp.buf.code_action)
	buf_set_keymap('n', 'gr', vim.lsp.buf.references)
	buf_set_keymap('n', '<leader>e', vim.diagnostic.open_float)
	buf_set_keymap('n', '<leader>q', vim.diagnostic.setloclist)
	buf_set_keymap('n', '<leader>ff', vim.lsp.buf.formatting)

	buf_set_keymap("n", "<leader>rs", function() vim.lsp.stop_client(vim.lsp.get_active_clients()) end)
end

-- https://github.com/golang/tools/blob/master/gopls/doc/vim.md#imports
local goimports = function(wait_ms)
	local params = vim.lsp.util.make_range_params()
	params.context = { only = { "source.organizeImports" } }
	local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, wait_ms)
	for _, res in pairs(result or {}) do
		for _, r in pairs(res.result or {}) do
			if r.edit then
				vim.lsp.util.apply_workspace_edit(r.edit, 'utf-8')
			else
				vim.lsp.buf.execute_command(r.command)
			end
		end
	end
end

nvim_lsp.gopls.setup({
	-- cmd = {"gopls", "-vv", "-logfile", "gopls.log", "-rpc.trace"};
	cmd = { "gopls", "-remote=auto" },
	settings = {
		gopls = {
			-- these links aren't very useful - they're rendered in markdown and
			-- nothing is rendering the markdown or making the link particularly
			-- useable. maybe one day i can set something up to render the links more
			-- cleanly or make them shell out to `open` or something when interacted
			-- with.
			linksInHover = false,
			usePlaceholders = true,
		},
	},
	on_attach = (function(client, bufnr)
		vim.api.nvim_create_autocmd("BufWritePre", {
			pattern = "*.go",
			callback = function()
				local timeout = 1000
				vim.lsp.buf.formatting_sync(nil, timeout)
				goimports(timeout)
			end,
			desc = "format Go buffer",
		})

		on_attach(client, bufnr)
	end),
})

-- nvim_lsp.yamlls.setup({
--   on_attach = on_attach,
--   settings = {
-- 	-- trace = {
-- 	--   server = verbose,
-- 	-- },
-- 	redhat = {
-- 	  telemetry = {
-- 		enabled = false,
-- 	  },
-- 	},
-- 	yaml = {
-- 	  hover = true,
-- 	  completion = true,
-- 	  format = {
-- 		enable = true,
-- 	  },
-- 	},
--   },
-- })

nvim_lsp.lua_ls.setup {
	on_attach = on_attach,
	settings = {
		Lua = {
			runtime = {
				-- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
				version = 'LuaJIT',
			},
			diagnostics = {
				-- Get the language server to recognize the `vim` global
				globals = { 'vim' },
			},
			workspace = {
				-- Make the server aware of Neovim runtime files
				library = vim.api.nvim_get_runtime_file("", true),
			},
			-- Do not send telemetry data containing a randomized but unique identifier
			telemetry = {
				enable = false,
			},
		},
	},
}

-- Use a loop to conveniently call 'setup' on multiple servers and
-- map buffer local keybindings when the language server attaches
-- local servers = { "rnix", "rust_analyzer", "tsserver", "golangcilsp" }
local servers = { "rnix", "rust_analyzer", "tsserver" }
for _, lsp in ipairs(servers) do
	nvim_lsp[lsp].setup { on_attach = on_attach }
end
