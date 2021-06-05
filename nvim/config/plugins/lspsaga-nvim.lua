saga = require 'lspsaga'
saga.init_lsp_saga({
	use_saga_diagnostic_sign = false,
	error_sign = 'E',
	warn_sign = 'W',
	hint_sign = 'H',
	infor_sign = 'I',

	code_action_icon = 'A',
	code_action_prompt = {
		enable = false,
	},
})
