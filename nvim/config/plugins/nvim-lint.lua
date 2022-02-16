local lint = require('lint')

lint.linters_by_ft = {
	go = {'golangcilint'},
}

lint.linters.golangcilint.args = {
	'run',
	'--out-format', 'json',
	'--disable', 'typecheck',
}

vim.api.nvim_command("autocmd InsertLeave,BufEnter *.go lua require('lint').try_lint()")
