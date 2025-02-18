local gruvbox_material = require('lualine.themes.gruvbox-material')

local function isJJRepo()
	local obj = vim.system({
		"jj", "root",
		"--ignore-working-copy",
	}):wait()
	return obj.code == 0
end

vim.api.nvim_create_autocmd(
	{ 'BufEnter' },
	{
		desc = 'get jj st for lualine',
		pattern = '*',
		callback = function()
			vim.system({
				"jj", "log", "-r@",
				"-n1", "--color", "never",
				"--ignore-working-copy",
				"--no-graph",
				"-T", "change_id.shortest()"
			}, {}, vim.schedule_wrap(function(obj)
				vim.g.jj_changeid = obj.stdout
				-- can also force lualine's refresh by calling refresh function
				-- like require('lualine').refresh(). not sure if it's worth doing.
			end))
		end,
	}
)

require('lualine').setup({
	options = {
		theme = 'gruvbox-material',
		component_separators = '',
		section_separators = '',
		disabled_filetypes = {}
	},
	sections = {
		lualine_b = isJJRepo() and { 'g:jj_changeid', 'diff' } or { 'branch', 'diff' },
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
			sources     = { 'nvim_diagnostic' },
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
