vim.env.FZF_DEFAULT_COMMAND = "fd --type f --hidden -E '.git'"

-- noticed an issue where certain search terms in the agent's repo
-- would cause an error like "Error running <fzf command>".
-- this isn't happening with RG. The difference is that Rg runs rg once:
--     rg --column --line-number --no-heading --color=always --smart-case -- ''
-- and pipes the output into fzf. conversely, RG runs Rg  after each keystroke.
vim.keymap.set('n', '<leader>g', '<cmd>RG<CR>', { silent = true })
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
