vim.o.completeopt = "menuone,noselect,noinsert"

require('compe').setup {
  enabled = true;
  autocomplete = true;
  debug = false;
  min_length = 2;
  preselect = 'enable';
  throttle_time = 80;
  source_timeout = 200;
  incomplete_delay = 400;
  max_abbr_width = 100;
  max_kind_width = 100;
  max_menu_width = 100;
  documentation = true;

  source = {
    path = true;
    nvim_lsp = true;
    buffer = true; -- this is nice but i think it may be redundant w/ tabnine
    -- nvim_lua = true; -- probably only load this in lua files if possible
	-- tabnine = {
	-- 	sort = true;
	-- 	priority = 0;
	-- };
    luasnip = true;
  };
}

-- vim.api.nvim_set_keymap("i", "<C-y>", "compe#confirm(lexima#expand('<LT>CR>', 'i'))", {expr = true})
-- vim.api.nvim_set_keymap("i", "<CR>", "<C-y>", {})

local t = function(str)
  return vim.api.nvim_replace_termcodes(str, true, true, true)
end

local check_back_space = function()
    local col = vim.fn.col('.') - 1
    if col == 0 or vim.fn.getline('.'):sub(col, col):match('%s') then
        return true
    else
        return false
    end
end

-- Use (s-)tab to:
--- move to prev/next item in completion menuone
--- jump to prev/next snippet's placeholder
--
-- this is taken from the luasnip readme and used by the tab completion code
-- below
local function prequire(...)
local status, lib = pcall(require, ...)
if (status) then return lib end
    return nil
end
local t = function(str)
    return vim.api.nvim_replace_termcodes(str, true, true, true)
end
local luasnip = prequire('luasnip')
-- this is from both the luasnip readme and nvim-compe docs
_G.tab_complete = function()
    if vim.fn.pumvisible() == 1 then
        return t "<C-n>"
    elseif luasnip and luasnip.expand_or_jumpable() then
        return t "<Plug>luasnip-expand-or-jump"
    elseif check_back_space() then
        return t "<Tab>"
    else
        return vim.fn['compe#complete']()
    end
end
_G.s_tab_complete = function()
    if vim.fn.pumvisible() == 1 then
        return t "<C-p>"
    elseif luasnip and luasnip.jumpable(-1) then
        return t "<Plug>luasnip-jump-prev"
    else
    	-- If <S-Tab> is not working in your terminal, change it to <C-h>
        return t "<S-Tab>"
    end
end

vim.api.nvim_set_keymap("i", "<Tab>", "v:lua.tab_complete()", {expr = true})
vim.api.nvim_set_keymap("s", "<Tab>", "v:lua.tab_complete()", {expr = true})
vim.api.nvim_set_keymap("i", "<S-Tab>", "v:lua.s_tab_complete()", {expr = true})
vim.api.nvim_set_keymap("s", "<S-Tab>", "v:lua.s_tab_complete()", {expr = true})
