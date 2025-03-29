require('blink.cmp').setup({
	keymap = {
		preset = 'default',
		['<C-j>'] = { 'select_next', 'fallback_to_mappings' },
		['<C-k>'] = { 'select_prev', 'fallback_to_mappings' },
		['<CR>'] = { 'accept', 'fallback' },

		-- defaults
		-- ['<C-space>'] = { 'show', 'show_documentation', 'hide_documentation' },
		-- ['<C-e>'] = { 'hide' },
		-- ['<C-y>'] = { 'select_and_accept' },
		-- ['<Up>'] = { 'select_prev', 'fallback' },
		-- ['<Down>'] = { 'select_next', 'fallback' },
		-- ['<C-p>'] = { 'select_prev', 'fallback_to_mappings' },
		-- ['<C-n>'] = { 'select_next', 'fallback_to_mappings' },
		-- ['<C-b>'] = { 'scroll_documentation_up', 'fallback' },
		-- ['<C-f>'] = { 'scroll_documentation_down', 'fallback' },
		-- ['<Tab>'] = { 'snippet_forward', 'fallback' },
		-- ['<S-Tab>'] = { 'snippet_backward', 'fallback' },
		-- ['<C-k>'] = { 'show_signature', 'hide_signature', 'fallback' },
	},
	sources = {
		default = { 'snippets', 'lsp', 'path', 'buffer', 'copilot', 'nvim_lua' },
		providers = {
			copilot = {
				name = "copilot",
				module = "blink-copilot",
				score_offset = 100,
				async = true,
			},
			nvim_lua = {
				name = 'nvim_lua',
				module = 'blink.compat.source',
				score_offset = -1,
				enabled = function()
					if vim.bo.filetype == 'lua' then
						local start = vim.api.nvim_buf_get_name(0):find('nvim', 0, true)
						return start > 0
					end
					return false
				end,
			},
			buffer = {
				min_keyword_length = 4,
			},
		},
	},
	completion = {
		documentation = {
			auto_show = true,
			auto_show_delay_ms = 200,
		},
		menu = {
			draw = {
				columns = {
					{ 'label',    'label_description', gap = 1 },
					{ 'kind' },
					{ 'source_id' },
				},
			},
		},
	},
	fuzzy = { implementation = 'prefer_rust_with_warning' },
	snippets = { preset = 'luasnip' },
	signature = {
		enabled = true,
		window = {
			show_documentation = false,
		},
	},
})
