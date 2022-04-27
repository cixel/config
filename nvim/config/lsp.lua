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

-- it'd be nice not to link these to Gruvbox groups. also not super sure why
-- this needs to be an autocmd.
-- XXX check if these still do the same thing after 0.6
vim.api.nvim_create_autocmd("VimEnter", {
  pattern = "*",
  callback = function()
	vim.api.nvim_set_hl(0, 'LspDiagnosticsDefaultError', {link = 'GruvboxRed'})
	vim.api.nvim_set_hl(0, 'LspDiagnosticsDefaultWarning', {link = 'GruvboxYellow'})
  end,
  desc = "set lsp diagnostic highlights",
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

  local buf_set_option = function(...)
	vim.api.nvim_buf_set_option(bufnr, ...)
  end

  --Enable completion triggered by <c-x><c-o>
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

  -- no longer getting these from ale
  buf_set_keymap('n', '<C-Q>', function() vim.diagnostic.goto_prev({ enable_popup = false }) end)
  buf_set_keymap('n', '<C-q>', function() vim.diagnostic.goto_next({ enable_popup = false }) end)
end

-- https://github.com/golang/tools/blob/master/gopls/doc/vim.md#imports
local goimports = function(wait_ms)
  local params = vim.lsp.util.make_range_params()
  params.context = {only = {"source.organizeImports"}}
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
  -- cmd = {"gopls", "-remote=auto", "-vv", "-logfile", "/home/alnitak/gopls.log", "-rpc.trace"};
  cmd = {"gopls", "-remote=auto"};
  on_attach = (function(client, bufnr)
	vim.api.nvim_create_autocmd("BufWritePre", {
	  pattern = "*.go",
	  callback = function()
		vim.lsp.buf.formatting_sync(nil, 1000)
		goimports(1000)
	  end,
	  desc = "format Go buffer",
	})

	on_attach(client, bufnr)
  end);
})

-- Use a loop to conveniently call 'setup' on multiple servers and
-- map buffer local keybindings when the language server attaches
-- local servers = { "rnix", "rust_analyzer", "tsserver", "golangcilsp" }
local servers = { "rnix", "rust_analyzer", "tsserver" }
for _, lsp in ipairs(servers) do
  nvim_lsp[lsp].setup { on_attach = on_attach }
end
