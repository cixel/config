local gruvbox_material = require('lualine.themes.gruvbox_material')
require('lualine').setup({
	options = {
		theme = 'gruvbox_material',
		component_separators = '',
		section_separators = '',
		disabled_filetypes = {}
	},
	sections = {
		lualine_c = {'filename', 'diff'},
		lualine_x = {'encoding', 'bo:fileformat', 'filetype'},
  		lualine_z = {'location', {
			'diagnostics',
			sources = {'ale'}, -- don't do both this and nvim_lsp; lsp feeds into ale
        	sections = {'error', 'warn', 'info', 'hint'},
        	symbols = {error = 'E:', warn = 'W:', info = 'I:', hint = 'H:'},
			color_error = gruvbox_material.normal.a.fg,
			color_warn  = gruvbox_material.normal.a.fg,
			color_info  = gruvbox_material.normal.a.fg,
			color_hint  = gruvbox_material.normal.a.fg,
		}}
	},
})
