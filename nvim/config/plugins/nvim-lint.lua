local lint = require('lint')

local severities = {
	error = vim.lsp.protocol.DiagnosticSeverity.Error,
	warning = vim.lsp.protocol.DiagnosticSeverity.Warning,
	refactor = vim.lsp.protocol.DiagnosticSeverity.Information,
	convention = vim.lsp.protocol.DiagnosticSeverity.Hint,
}

-- TODO: when https://github.com/mfussenegger/nvim-lint/pull/128
-- is merged and the plugin is updated in nix, remove this
local function parser(output, bufnr)
	if output == '' then
		return {}
	end
	local decoded = vim.fn.json_decode(output)
	if decoded["Issues"] == nil or type(decoded["Issues"]) == 'userdata' then
		return {}
	end

	local diagnostics = {}
	for _, item in ipairs(decoded["Issues"]) do
		local curfile = vim.api.nvim_buf_get_name(bufnr)
		local lintedfile = vim.fn.getcwd() .. "/" .. item.Pos.Filename
		if curfile == lintedfile then
			-- only publish if those are the current file diagnostics
			local sv = severities[item.Severity] or severities.warning
			table.insert(diagnostics, {
				range = {
					['start'] = {
						line = item.Pos.Line - 1,
						character = item.Pos.Column - 1,
					},
					['end'] = {
					line = item.Pos.Line - 1,
					character = item.Pos.Column - 1,
					},
				},
				severity = sv,
				source = item.FromLinter,
				message = item.Text,
			})
		end
	end
	return diagnostics
end


lint.linters_by_ft = {
	go = {'golangcilint'},
}
lint.linters.golangcilint.args = {
	'run',
	'--out-format', 'json',
	'--disable', 'typecheck',
}
lint.linters.golangcilint.parser = parser

vim.api.nvim_command("autocmd InsertLeave,BufEnter *.go lua require('lint').try_lint()")
