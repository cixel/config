local gruvbox_material = require('lualine.themes.gruvbox-material')
require('lualine').setup({
	options = {
		theme = 'gruvbox-material',
		component_separators = '',
		section_separators = '',
		disabled_filetypes = {}
	},
	sections = {
		lualine_b = { 'branch', 'diff' },
		lualine_c = {
			{
				'filename',
				file_status = true, -- displays file status (readonly status, modified status)
				path = 1 -- 0 = just filename, 1 = relative path, 2 = absolute path
			},
		},
		lualine_x = { 'encoding', 'bo:fileformat', { 'filetype', icons_enabled = false } },
		lualine_z = { 'location', {
			'diagnostics',
			sources     = { 'nvim_diagnostic' }, -- don't do both this and nvim_lsp; lsp feeds into ale
			sections    = { 'error', 'warn', 'info', 'hint' },
			symbols     = { error = 'E:', warn = 'W:', info = 'I:', hint = 'H:' },
			color_error = gruvbox_material.normal.a.fg,
			color_warn  = gruvbox_material.normal.a.fg,
			color_info  = gruvbox_material.normal.a.fg,
			color_hint  = gruvbox_material.normal.a.fg,
		} }
	},
	inactive_sections = {
		lualine_a = {},
		lualine_b = {},
		lualine_c = {
			{
				'filename',
				file_status = true, -- displays file status (readonly status, modified status)
				path = 1 -- 0 = just filename, 1 = relative path, 2 = absolute path
			},
		},
		lualine_x = { 'location' },
		lualine_y = {},
		lualine_z = {}
	},
})
