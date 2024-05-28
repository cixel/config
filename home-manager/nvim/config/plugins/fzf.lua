vim.env.FZF_DEFAULT_COMMAND = "fd --type f --hidden -E '.git'"

vim.keymap.set('n', '<leader>g', '<cmd>Rg<CR>', { silent = true })
vim.keymap.set('n', '<leader>G', '<cmd>RG<CR>', { silent = true })
vim.keymap.set('n', '<leader>c', '<cmd>Commits<CR>', { silent = true })
vim.keymap.set('n', '<leader>x', '<cmd>BCommits<CR>', { silent = true })

-- local function fzfAtLSPRoot()
-- 	local client0 = vim.lsp.get_active_clients()[1]
--
-- 	local root = '.'
-- 	if client0 ~= nil then
-- 		root = client0.config.root_dir
-- 	end
--
-- 	print('FZF ' .. root)
-- 	vim.cmd('FZF ' .. root)
-- end
-- vim.keymap.set('n', ';', fzfAtLSPRoot, { silent = true })

vim.keymap.set('n', ';', '<cmd>FZF<CR>', { silent = true })
