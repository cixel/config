local lint = require('lint')

local severities = {
	error = vim.lsp.protocol.DiagnosticSeverity.Error,
	warning = vim.lsp.protocol.DiagnosticSeverity.Warning,
	refactor = vim.lsp.protocol.DiagnosticSeverity.Information,
	convention = vim.lsp.protocol.DiagnosticSeverity.Hint,
}

lint.linters_by_ft = {
	go = {'golangcilint'},
}
lint.linters.golangcilint.args = {
	'run',
	'--out-format', 'json',
	'--disable', 'typecheck',
}

vim.api.nvim_command("autocmd InsertLeave,BufEnter *.go lua require('lint').try_lint()")
