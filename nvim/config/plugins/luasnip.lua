local ls = require("luasnip")
-- some shorthands...
local s = ls.snippet
local sn = ls.snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local c = ls.choice_node
local d = ls.dynamic_node
local l = require("luasnip.extras").lambda
local r = require("luasnip.extras").rep
local p = require("luasnip.extras").partial
local m = require("luasnip.extras").match
local n = require("luasnip.extras").nonempty
local dl = require("luasnip.extras").dynamic_lambda

-- see about rewriting these in nvim-compe with compe#confirm for better
-- functionality with completion menus
vim.api.nvim_set_keymap("i", "<C-q>", "<Plug>luasnip-expand-or-jump", {})
vim.api.nvim_set_keymap("s", "<C-q>", "<Plug>luasnip-expand-or-jump", {})

ls.snippets = {
	-- if i don't define all here, :LuaSnipListAvailable won't work; maybe open an issue?
	all = {},
	go = {
		ls.parser.parse_snippet(
			{trig="cl", dscr="fmt.Println"},
			[[fmt.Println(${1})]]
		),
		ls.parser.parse_snippet(
			{trig="cf", dscr="fmt.Printf"},
			[[fmt.Printf(${1})]]
		),
		ls.parser.parse_snippet(
			{trig="main", dscr="main file template"},
			[[package main

func main() {
	${1}
}
			]]
		),
		ls.parser.parse_snippet(
			{trig="fortest", dscr="table test template"},
			[[var tests = map[string]struct{${2}}{}

for name, test := range tests {
	t.Run(name, func(t *testing.T) {
		_ = test
		${1}
	})
}]]
		),
		ls.parser.parse_snippet(
			{trig="sample", dscr="sample app template"},
			[[package main

import (
	"log"
	"net/http"
)

func main() {
	http.HandleFunc("/test", func(w http.ResponseWriter, r *http.Request) {
		input := r.URL.Query().Get("input")
		_, _ = w.Write([]byte(input))
	})

	log.Print("listening on :8080")
	log.Fatal(http.ListenAndServe("127.0.0.1:8080", nil))
}]]
		),
	},
	yaml = {
		s("config", {
			t({
                "api:",
                "  url: http://localhost:19080/Contrast",
                "  user_name: contrast_admin",
                "  api_key: demo",
                "  service_key: demo",
                "",
                "agent:",
                "  go:",
                "    dot_files: true",
                "  logger:",
                "    stdout: true",
                "    level: info",
                "  polling:",
                "    app_activity_ms: 6000",
                "  service:",
                "    grpc: true",
                "    logger:",
                "      path: service.log",
                "      level: debug",
                "    socket: /tmp/service.sock",
                "",
                "assess:",
                "  enable: true",
                "  enable_preflight: false",
                "",
                "protect:",
                "  enable: false"
			})
		})
	}
}
