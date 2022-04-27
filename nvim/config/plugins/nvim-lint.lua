local lint = require('lint')

lint.linters_by_ft = {
  -- go = {'golangcilint'},
}

lint.linters.golangcilint.args = {
  'run',
  '--out-format', 'json',
  '--disable', 'typecheck',
}

vim.api.nvim_create_autocmd({"InsertLeave", "BufEnter"}, {
  pattern = "*.go",
  callback = function ()
	lint.try_lint()
  end, 
  desc = "lint go Buffer",
})
