local nvim_lsp = require('lspconfig')
-- vim.lsp.set_log_level("debug")
vim.diagnostic.config({
	virtual_text = {},
	float = {
		source = true,
	},
})

-- I'm not sure what this actually does anymore; might not be necessary
-- vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
-- 	vim.lsp.diagnostic.on_publish_diagnostics, {
-- 		signs = true,
-- 		update_in_insert = false,
-- 	}
-- )

-- it'd be nice not to link these to Gruvbox groups. also not super sure why
-- this needs to be an autocmd.
-- XXX check if these still do the same thing for highlights after 0.6
vim.api.nvim_create_autocmd("VimEnter", {
	pattern = "*",
	callback = function()
		vim.keymap.set(
			'n', '<C-q>',
			function() vim.diagnostic.jump({ count = 1, float = true }) end,
			{ silent = true }
		)
		vim.keymap.set(
			'n', '<C-S-Q>',
			function() vim.diagnostic.jump({ count = -1, float = true }) end,
			{ silent = true }
		)
	end,
	desc = "set lsp diagnostic highlights and mappings",
})

-- Use an on_attach function to only map the following keys
-- after the language server attaches to the current buffer
local function on_attach(_, bufnr)
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
	buf_set_keymap('n', 'gD', vim.lsp.buf.type_definition)
	buf_set_keymap('n', 'gd', vim.lsp.buf.definition)

	buf_set_keymap('n', 'K', vim.lsp.buf.hover)
	-- buf_set_keymap('n', 'K', ':Lspsaga hover_doc<CR>', opts)

	buf_set_keymap('n', '<leader>rn', vim.lsp.buf.rename)
	buf_set_keymap('n', 'gi', vim.lsp.buf.implementation)

	-- buf_set_keymap('n', '<C-k>', vim.lsp.buf.signature_help)
	buf_set_keymap('n', '<C-s>', vim.lsp.buf.signature_help)

	buf_set_keymap('n', '<leader>r', vim.lsp.buf.references)
	buf_set_keymap('n', '<leader>wa', vim.lsp.buf.add_workspace_folder)
	buf_set_keymap('n', '<leader>wr', vim.lsp.buf.remove_workspace_folder)
	buf_set_keymap('n', '<leader>wl', function() print(vim.inspect(vim.lsp.buf.list_workspace_folders())) end)
	buf_set_keymap('n', '<leader>D', vim.lsp.buf.type_definition)
	buf_set_keymap('n', '<leader>ca', vim.lsp.buf.code_action)
	buf_set_keymap('n', 'gr', vim.lsp.buf.references)
	buf_set_keymap('n', '<leader>e', vim.diagnostic.open_float)
	buf_set_keymap('n', '<leader>q', vim.diagnostic.setloclist)
	-- buf_set_keymap('n', '<leader>ff', vim.lsp.buf.formatting)
	buf_set_keymap('n', '<leader>ff', function() vim.lsp.buf.format({ async = true }) end)

	buf_set_keymap("n", "<leader>rs", function() vim.lsp.stop_client(vim.lsp.get_clients()) end)
end

-- https://github.com/golang/tools/blob/master/gopls/doc/vim.md#imports
-- https://github.com/golang/tools/blob/master/gopls/doc/features/transformation.md#source.organizeImports
local goimports = function(client, wait_ms)
	local params = vim.lsp.util.make_range_params(0, client.offset_encoding)
	local results = client:request_sync(
		vim.lsp.protocol.Methods.textDocument_codeAction,
		{
			textDocument = params.textDocument,
			range = params.range,
			context = {
				only = { vim.lsp.protocol.CodeActionKind.SourceOrganizeImports },
			},
		},
		wait_ms
	)

	for _, result in pairs(results or {}) do
		for _, r in pairs(result or {}) do
			if r.edit then
				vim.lsp.util.apply_workspace_edit(r.edit, client.offset_encoding)
			end
		end
	end
end

local capablities = require('blink.cmp').get_lsp_capabilities()

nvim_lsp.gopls.setup({
	-- cmd = {"gopls", "-vv", "-logfile", "gopls.log", "-rpc.trace"};
	capablities = capablities,
	cmd = { "gopls", "-remote=auto" },
	settings = {
		gopls = {
			linksInHover = true,
			completeFunctionCalls = true,
			usePlaceholders = true,
			experimentalPostfixCompletions = true,
			staticcheck = true,
		},
	},
	-- FIXME: yoinked from
	-- https://github.com/hrsh7th/nvim-cmp/wiki/Language-Server-Specific-Samples#golang-gopls
	-- i'm not sure if it's redundant with the usePlaceholders setting above?
	init_options = {
		usePlaceholders = true,
	},
	on_attach = (function(client, bufnr)
		vim.api.nvim_create_autocmd("BufWritePre", {
			pattern = "*.go",
			callback = function()
				local timeout = 1000
				vim.lsp.buf.format({
					options = {
						timeout_ms = timeout,
					}
				})
				goimports(client, timeout)
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
	capablities = capablities,
	settings = {
		Lua = {
			runtime = {
				-- Tell the language server which version of Lua you're using
				-- (most likely LuaJIT in the case of Neovim)
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

-- https://github.com/oxalica/nil/blob/2f3ed6348bbf1440fcd1ab0411271497a0fbbfa4/dev/nvim-lsp.nix#L83
nvim_lsp.nil_ls.setup {
	on_attach = on_attach,
	capablities = capablities,
	settings = {
		['nil'] = {
			formatting = {
				command = { "nixpkgs-fmt" },
			},
		},
	},
}

-- local servers = { "rnix", "rust_analyzer", "tsserver", "golangcilsp" }
local servers = {
	"bashls",
	"eslint", "ts_ls",
	"rust_analyzer",
	"yamlls",
	"zls",
}
for _, lsp in ipairs(servers) do
	nvim_lsp[lsp].setup { on_attach = on_attach, capabilities = capablities }
end
