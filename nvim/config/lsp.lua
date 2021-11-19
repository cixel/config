local nvim_lsp = require('lspconfig')

-- vim.lsp.set_log_level("debug")

vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
  vim.lsp.diagnostic.on_publish_diagnostics, {
    underline = true,
    -- virtual_text = false,
    signs = true,
    update_in_insert = false,
  }
)

-- it'd be nice not to link these to Gruvbox groups. also not super sure why
-- this needs to be an autocmd.
vim.api.nvim_command("autocmd VimEnter * highlight! link LspDiagnosticsDefaultError GruvboxRed")
vim.api.nvim_command("autocmd VimEnter * highlight! link LspDiagnosticsDefaultWarning GruvboxYellow")

-- Use an on_attach function to only map the following keys
-- after the language server attaches to the current buffer
local on_attach = function(client, bufnr)
  local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
  local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end

  --Enable completion triggered by <c-x><c-o>
  -- buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

  -- Mappings.
  local opts = { noremap=true, silent=true }

  -- See `:help vim.lsp.*` for documentation on any of the below functions
  buf_set_keymap('n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<CR>', opts)
  buf_set_keymap('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>', opts)

  buf_set_keymap('n', 'K', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
  -- buf_set_keymap('n', 'K', ':Lspsaga hover_doc<CR>', opts)


  buf_set_keymap('n', '<leader>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
  buf_set_keymap('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)

  -- buf_set_keymap('n', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
  buf_set_keymap('n', '<C-s>', '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)

  buf_set_keymap('n', '<leader>wa', '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>', opts)
  buf_set_keymap('n', '<leader>wr', '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>', opts)
  buf_set_keymap('n', '<leader>wl', '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>', opts)
  buf_set_keymap('n', '<leader>D', '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
  buf_set_keymap('n', '<leader>ca', '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)
  buf_set_keymap('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
  buf_set_keymap('n', '<leader>e', '<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>', opts)
  buf_set_keymap('n', '<leader>q', '<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>', opts)
  buf_set_keymap("n", "<leader>ff", "<cmd>lua vim.lsp.buf.formatting()<CR>", opts)

  buf_set_keymap("n", "<leader>rs", "<cmd>lua vim.lsp.stop_client(vim.lsp.get_active_clients())<CR>", opts)

  -- no longer getting these from ale
  buf_set_keymap('n', '<C-Q>', '<cmd>lua vim.lsp.diagnostic.goto_prev({ enable_popup = false })<CR>', opts)
  buf_set_keymap('n', '<C-q>', '<cmd>lua vim.lsp.diagnostic.goto_next({ enable_popup = false })<CR>', opts)
end

-- https://github.com/golang/tools/blob/master/gopls/doc/vim.md#imports
function goimports(wait_ms)
	local params = vim.lsp.util.make_range_params()
	params.context = {only = {"source.organizeImports"}}
	local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, wait_ms)
	for _, res in pairs(result or {}) do
		for _, r in pairs(res.result or {}) do
			if r.edit then
				vim.lsp.util.apply_workspace_edit(r.edit)
			else
				vim.lsp.buf.execute_command(r.command)
			end
		end
	end
end

nvim_lsp.gopls.setup({
	-- cmd = {"gopls", "-remote=auto", "-vv", "-logfile", "/home/alnitak/gopls.log", "-rpc.trace"};
	cmd = {"gopls", "-remote=auto"};
	on_attach = (function(client, bufnr)
		vim.api.nvim_command("autocmd BufWritePre *.go lua vim.lsp.buf.formatting_sync(nil, 1000)")
		vim.api.nvim_command("autocmd BufWritePre *.go lua goimports(1000)")
		on_attach(client, bufnr)
	end);
})

if not nvim_lsp.golangcilsp then 
	local configs = require('lspconfig/configs')
	configs.golangcilsp = {
		default_config = {
			cmd = {'golangci-lint-langserver'},
			root_dir = nvim_lsp.util.root_pattern("go.mod", ".git"),
			file_types = { 'go '},
			init_options = {
				command = { "golangci-lint", "run", "--out-format", "json" };
			},
		};
	}
end

-- Use a loop to conveniently call 'setup' on multiple servers and
-- map buffer local keybindings when the language server attaches
local servers = { "rnix", "rust_analyzer", "tsserver", "golangcilsp" }
for _, lsp in ipairs(servers) do
  nvim_lsp[lsp].setup { on_attach = on_attach }
end

