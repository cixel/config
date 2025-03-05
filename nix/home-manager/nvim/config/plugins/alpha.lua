local alpha = require('alpha')
local dashboard = require('alpha.themes.dashboard')

-- dashboard.section.header.val = {
dashboard.section.header.val = {
	[[                                                                ]],
	[[                                                                ]],
	[[                                                                ]],
	[[                                                                ]],
	[[                                     .;c:;'                     ]],
	[[                      .cldkxc.  .,dkxxkd;'.                     ]],
	[[                       ..,xXNkldOKXN0o'.                        ]],
	[[                    .;ooooxXWWNNNNNNKdolllllc,.                 ]],
	[[             .'lkOOO0XMMMMMMMMMMMMMMMWWWWWWNN0kxc..             ]],
	[[           ,dKXNWMMMMMMMMMMMMMMMMMMMMMMMMWWWWNNXK0xl'           ]],
	[[         .oKWMMMMMMMMMMMMMMMMMMMMMMMMMMMMMWWWWWNXXK0xc.         ]],
	[[        .oNMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMWWWWWNXXK0Oxc'       ]],
	[[       .oXMMMMMMWWWWWWMMMMMMMMMMMMMMWWWWWMMWWWWWNNXXK0OOd.      ]],
	[[      .oKWMMMMWXk:,cONWMMMMMMMMMWWWXx:,l0NMMMWWWWNXXXK0Ox,      ]],
	[[     .oKWWMMMMNo.   .xWMMMMMMMMMWWXl.   'kMMMMWWWNXXXX0OOx;     ]],
	[[   .l0NWWMMMMMW0c. .lKMMMMMMMMMMMMWO:. .oKMMMWWWWNXXXX0OOOd;.   ]],
	[[ .cOXNNWMMMMMMMMN0OKWMMMMMMMMMMMMMMMN0OKWMMMMWWWWNXXXXK0Okkko,  ]],
	[[.;cdOXNWMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMWWWWNXXXK0OOxlcoc. ]],
	[[   .,xXWWWMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMWWWWNXXK0OOOx;..'. ]],
	[[    .lXWWWMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMWWWWWNXXK0OOOx:.    ]],
	[[    .lXWMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMWWNWWWXXK0OOkxo:.   ]],
	[[    .oXWMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMWWMWNXNNNXXK0Okddol;.  ]],
	[[   .dKNWMMWWWMMMMMMMMMMMMMMMMMMMWWMMMMMWNNNWWNXXXXXXK0Okdool:'. ]],
	[[   'kXNWWWNNWMMMWNWMMMMMMMMMMMWWNNWMMMWNXXXNNXXXK00KXK0kxdoc... ]],
	[[   'kXXXNNNWWWWNNNNWMMWWNWWMMWNXXXNNWWNNNXXXXXXX0OOO0K0kkxdc.   ]],
	[[  .cOXXXNWWNNNNNNNWWMWNNNNNWWWNNNWWNNNNWWNXXXXXXK0OOOOOkxdd:.   ]],
	[[ .l00KXXNNWNNNWWNNNWWWNWWWWNNNNNWNNNWWWWNXXXXXXXXKOkkkkxdddl;.  ]],
	[[.:xOOOKXXNNNNNNNXXXNWWNNNWWWWNNNNXXXXNNNXXXKKXXXXKOkxxdddddol'  ]],
	[[ .,lkO0KXXKXXXXXXXKKXNXXNWWWWNXXXK0O0KKKXK0OO0KKKKOxdddddddol;. ]],
	[[  .cxOOO00O0KKXXXK0O0KXXXNWNXXXK00OOOOOO0OkxxkOOOOkxddddddoooo:.]],
	[[  ,dxkkkkkOOO000K0OOOO0KKXNXKK0OOOOOOkkkxxxdddxxxdddddoooooooo:.]],
	[[  .:odddddxkOOOOOOOOOOOOO000OOOOOOkkxxdddddddoooollllll:,'''''. ]],
	[[    ......'coooooooooooooooooooooolllll:'...............        ]],
	[[           .............................                        ]],
};
dashboard.section.header.opts.hl = 'NonText'

dashboard.section.buttons.val = {}
dashboard.config.opts.noautocmd = true

alpha.setup(dashboard.config)
