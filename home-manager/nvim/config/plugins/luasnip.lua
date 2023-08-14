local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node

-- see about rewriting these in nvim-compe with compe#confirm for better
-- functionality with completion menus
vim.keymap.set({ "i", "s" }, "<C-q>", "<Plug>luasnip-expand-or-jump", {})

ls.add_snippets("all", {})
ls.add_snippets("javascript", {
	ls.parser.parse_snippet(
		{ trig = "cl", dscr = "console.log" },
		[[console.log(${1})]]
	),
	ls.parser.parse_snippet(
		{ trig = "sample", dscr = "sample app template" },
		[['use strict';
const express = require('express');
const app = express();

Error.stackTraceLimit = 100;

app.get('/', (req, res) => {
  res.send('!');
});

app.get('/test', (req, res) => {
  const input = req.query.input;
  res.send(input);
});

app.listen(3000, () => console.log('Example app listening on port 3000!'));]]
	),
})
ls.add_snippets("yaml", {
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
			"",
			"assess:",
			"  enable: true",
			"  enable_preflight: false",
			"",
			"protect:",
			"  enable: false"
		})
	})
})
ls.add_snippets("go", {
	ls.parser.parse_snippet(
		{ trig = "cl", dscr = "fmt.Println" },
		[[fmt.Println(${1})]]
	),
	ls.parser.parse_snippet(
		{ trig = "cf", dscr = "fmt.Printf" },
		[[fmt.Printf(${1})]]
	),
	ls.parser.parse_snippet(
		{ trig = "tf", dscr = "t.Fatal" },
		[[t.Fatal(${1})]]
	),
	ls.parser.parse_snippet(
		{ trig = "fix", dscr = "fixme" },
		[[// FIXME(ehden)]]
	),
	ls.parser.parse_snippet(
		{ trig = "todo", dscr = "todo" },
		[[// TODO(1:ticket)]]
	),
	ls.parser.parse_snippet(
		{ trig = "main", dscr = "main file template" },
		[[package main

func main() {
	${1}
}
	]]
	),
	ls.parser.parse_snippet(
		{ trig = "im", dscr = "import statement" },
		[[import (
			${1}
	)]]
	),
	ls.parser.parse_snippet(
		{ trig = "fortest", dscr = "table test template" },
		[[var tests = map[string]struct{${2}}{}

for name, test := range tests {
	t.Run(name, func(t *testing.T) {
		_ = test
		${1}
	})
}]]
	),
	ls.parser.parse_snippet(
		{ trig = "tr", dscr = "test.Run template" },
		[[t.Run(${1}, func(t *testing.T) {
})]]
	),
	ls.parser.parse_snippet(
		{ trig = "json", dscr = "sample app template" },
		[[
{
	var buf bytes.Buffer
	json.Indent(&buf, data, "", "\t")
	fmt.Println(buf.String())
}
]]
	),
	ls.parser.parse_snippet(
		{ trig = "sample", dscr = "sample app template" },
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
})
