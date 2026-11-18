-- Rex config. Managed by nix/home-manager/rex/default.nix, do not edit
-- ~/.config/rex/init.lua directly. Apply with `hms && rex config reload`.
--
-- Ported from tmux.nix (prefix C-a) and ghostty.nix.
-- Docs: https://www.superlogical.com/rex/docs/customize/key-sequences

local P = "ctrl+a>"
local TERMINAL = "com.superlogical.terminal"
local config_home = os.getenv("XDG_CONFIG_HOME")
  or (os.getenv("HOME") .. "/.config")

local function prefix(key, action, args)
  rex.bind(P .. key, action, args)
end

----------------------------------------------------------------------------
-- Prefix
----------------------------------------------------------------------------

-- Once ctrl+a starts a sequence it no longer reaches the terminal, so give
-- the shell (and remote tmux with a C-a prefix) a way to get it.
-- tmux: `bind-key -n C-Tab send-prefix`
rex.bind("ctrl+tab", "pane.send_key", { key = "ctrl+a" })

----------------------------------------------------------------------------
-- Tabs (tmux windows)
----------------------------------------------------------------------------

-- tmux `last-window` (C-a a). Rex has no "last tab" action, and the config
-- file can't hear events (active_window_changed only reaches `rex do`
-- scripts), so the tab bindings below remember the switches they make.
-- Per session, `prev` is the tab we left and `cur` the one we went to. If
-- the current tab isn't `cur`, it was changed some other way (mouse,
-- palette), so `cur` is the one to go back to. Kept in memory, so a config
-- reload forgets it.
--
-- The app picks the visible tab itself and never tells the server, so the
-- view's active_window_id is stale and session.focus_window doesn't move
-- the app. The current tab is the one holding the focused block
-- (ctx.block_id), and switching goes through the app's client.tab.*
-- actions. Tab positions are the view's window order.
local tab_history = {}

-- The current tab and every tab in order.
local function tabs(ctx)
  local view = rex.session.view({ session_id = ctx.session_id })
  if not view then
    return nil, {}
  end
  local ids, current = {}, nil
  for i, w in ipairs(view.windows or {}) do
    ids[i] = w.window_id
    for _, layer in ipairs(w.layers or {}) do
      for _, b in ipairs(layer.blocks or {}) do
        if b.block_id == ctx.block_id then
          current = w.window_id
        end
      end
    end
  end
  return current or view.active_window_id, ids
end

local function index_of(ids, id)
  for i, v in ipairs(ids) do
    if v == id then
      return i
    end
  end
end

rex.action({
  name = "goto_tab",
  title = "Go to Tab",
  category = "Tab",
  -- index counts from 1, and -1 is the last tab. offset is +1 (next) or
  -- -1 (previous) and wraps around.
  args = { index = "integer?", offset = "integer?" },
  run = function(ctx, args)
    local current, ids = tabs(ctx)
    local i = args.index
    if args.offset then
      local pos = index_of(ids, current)
      i = pos and #ids > 0 and (pos - 1 + args.offset) % #ids + 1
    elseif i == -1 then
      i = #ids
    end
    local to = i and ids[i]
    if current and to and to ~= current then
      tab_history[ctx.session_id] = { prev = current, cur = to }
    end
    if args.offset == 1 then
      rex.client.queue("client.tab.next")
    elseif args.offset == -1 then
      rex.client.queue("client.tab.previous")
    elseif args.index then
      rex.client.queue("client.tab.goto", { index = args.index })
    end
  end,
})

rex.action({
  name = "last_tab",
  title = "Go to Last Tab",
  category = "Tab",
  keywords = "previous recent last-window toggle",
  run = function(ctx, _args)
    local h = tab_history[ctx.session_id]
    local current, ids = tabs(ctx)
    if not h or not current then
      return
    end
    local target = h.prev
    if h.cur and h.cur ~= current and index_of(ids, h.cur) then
      target = h.cur
    end
    local i = target and target ~= current and index_of(ids, target)
    if i then
      tab_history[ctx.session_id] = { prev = current, cur = target }
      rex.client.queue("client.tab.goto", { index = i })
    end
  end,
})

rex.action({
  name = "new_tab",
  title = "New Tab (remember last)",
  category = "Tab",
  run = function(ctx, _args)
    local current = tabs(ctx)
    if current then
      -- The app creates the tab, so its ID isn't known here. cur = nil
      -- makes last_tab return to `prev`.
      tab_history[ctx.session_id] = { prev = current }
    end
    rex.client.queue("client.tab.new")
  end,
})

prefix("a", "last_tab")
prefix("c", "new_tab")
prefix("n", "goto_tab", { offset = 1 })
prefix("p", "goto_tab", { offset = -1 })
prefix(",", "client.tab.rename")
prefix("shift+7", "client.tab.close") -- &
for i = 1, 9 do -- tmux base-index 1; Rex tabs also count from 1
  prefix(tostring(i), "goto_tab", { index = i })
end
prefix("0", "goto_tab", { index = -1 })

----------------------------------------------------------------------------
-- Panes
----------------------------------------------------------------------------

prefix("shift+5", "pane.split", { direction = "right" }) -- %
prefix("shift+'", "pane.split", { direction = "down" }) -- "
prefix("v", "pane.split", { direction = "right" })
prefix("z", "pane.zoom")
-- Close the focused pane, and its tab if it was the last pane (tmux
-- kill-pane). The client's pane.close and client.close both refuse to close
-- a tab's last pane, so call the server directly: block.close without
-- keep_last closes the window (tab) along with its last block.
local function close_pane(ctx, _ev)
  local block_id = ctx.block_id
  if not block_id then
    local view = rex.session.view({ session_id = ctx.session_id })
    for _, w in ipairs((view and view.windows) or {}) do
      if w.window_id == view.active_window_id then
        block_id = w.focused_block_id
      end
    end
  end
  if not block_id then
    return false
  end
  local _, err = rex.call("block.close", {
    session_id = ctx.session_id,
    block_id = block_id,
  })
  if err then
    rex.log("warn", "close_pane: " .. err)
  end
  return true
end
rex.bind(P .. "x", close_pane)
prefix("shift+1", "pane.move_to_new_tab") -- ! (break-pane)
-- f opens a new shell in a floating pane. F floats the current pane
-- (Rex's default for that is alt+cmd+enter). m minimizes the floating pane
-- (Rex's default is alt+cmd+m).
prefix("f", "pane.new_floating")
prefix("shift+f", "pane.float") -- F
prefix("m", "pane.minimize_floating")
prefix("o", "pane.focus_next")
prefix(";", "pane.focus_previous")
prefix("shift+e", "pane.balance") -- E (select-layout -E)

for _, dir in ipairs({ "left", "right", "up", "down" }) do
  prefix(dir, "pane.focus", { direction = dir })
  -- tmux: C-arrow resizes by 1 cell, M-arrow by 5. Rex amounts are percent.
  prefix("ctrl+" .. dir, "pane.resize", { direction = dir, amount = 2 })
  prefix("alt+" .. dir, "pane.resize", { direction = dir, amount = 10 })
end

-- tmux's resize bindings repeat without re-pressing the prefix. Sequences
-- don't, so add a resize mode: C-a R, then hjkl/arrows, Esc/Enter to leave.
rex.mode("resize", { exclusive = true })
prefix("shift+r", "client.mode.enter", { name = "resize" })
for key, dir in pairs({
  h = "left", j = "down", k = "up", l = "right",
  left = "left", down = "down", up = "up", right = "right",
}) do
  rex.bind("resize/" .. key, "pane.resize", { direction = dir })
  rex.bind("resize/shift+" .. key, "pane.resize", { direction = dir, amount = 15 })
end
rex.bind("resize/=", "pane.balance")
rex.bind("resize/enter", "client.mode.exit")

----------------------------------------------------------------------------
-- Sessions / misc
----------------------------------------------------------------------------

-- C-a s starts a sequence (Esc cancels):
--   1-9  go to that session, in `rex ls` order (same numbers the CLI uses)
--   s    open the session switcher (what C-a s alone used to do)
--   < >  move the current session earlier/later in that order
-- A key can't both run an action and start a sequence, so the switcher
-- moved to C-a s s.
local function list_session_ids()
  local res, err = rex.call("session.list", {})
  if not res then
    return nil, err
  end
  local ids = {}
  for _, s in ipairs(res.sessions or {}) do
    ids[#ids + 1] = s.session_id
  end
  return ids
end

rex.action({
  name = "select_session_n",
  title = "Go to Session by Number",
  category = "Session",
  args = { index = "integer" },
  run = function(_ctx, args)
    local ids = assert(list_session_ids())
    local id = ids[args.index]
    if id then
      rex.client.queue("session.select", { session_id = id })
    end
  end,
})

rex.action({
  name = "move_session",
  title = "Move Session",
  category = "Session",
  keywords = "reorder session order earlier later",
  args = { offset = "integer" },
  run = function(ctx, args)
    local ids = assert(list_session_ids())
    local from
    for i, id in ipairs(ids) do
      if id == ctx.session_id then
        from = i
      end
    end
    if not from then
      return
    end
    local to = math.max(1, math.min(#ids, from + args.offset))
    if to == from then
      return
    end
    -- session.move places a session before another one, or last when
    -- before_session_id is nil. Moving later skips over the session itself.
    local before = ids[to]
    if to > from then
      before = ids[to + 1] -- nil when moving last
    end
    assert(rex.call("session.move", {
      session_id = ctx.session_id,
      before_session_id = before,
    }))
  end,
})

for i = 1, 9 do
  prefix("s>" .. i, "select_session_n", { index = i })
end
prefix("s>s", "session.switch")
prefix("s>shift+,", "move_session", { offset = -1 }) -- <
prefix("s>shift+.", "move_session", { offset = 1 }) -- >
prefix("shift+4", "session.rename") -- $
prefix("shift+9", "session.previous") -- (
prefix("shift+0", "session.next") -- )
prefix("r", "client.config.reload")
prefix("shift+;", "client.palette.toggle") -- : (command prompt)
prefix("shift+/", "client.palette.toggle") -- ? (list-keys)
prefix("/", "client.find.open")

----------------------------------------------------------------------------
-- Copy mode (tmux C-a [)
--
-- Rex's copy mode is a key mode named "copy" whose defaults already follow
-- tmux's copy-mode-vi: hjkl/wbe/WBE, 0 ^ $, H M L, C-u C-d C-b C-f, g G,
-- { }, f F t T ; ,, / ? n N, counts, v V C-v, o, y, D, and q/Esc to leave.
-- List them with `jq '.reply.bindings[] | select(.mode == "copy")'` on the
-- app's cache in ~/Library/Caches/com.superlogical.rex/Keymap/. Only the
-- differences from tmux.nix's copy-mode-vi table are bound here.
----------------------------------------------------------------------------

prefix("[", "pane.copy_mode.enter")

rex.bind("copy/ctrl+c", "pane.copy_mode.exit") -- tmux cancel
rex.bind("copy/[", "pane.copy_mode.select", { mode = "char" }) -- begin-selection
-- tmux copy-selection: copy but stay in copy mode. Rex's yank always leaves,
-- so copy the pane's selection instead, which copy mode drives.
rex.bind("copy/]", "pane.copy")
-- tmux.nix unbinds Enter in copy-mode-vi, so block Rex's default yank.
rex.unbind("copy/enter")

----------------------------------------------------------------------------
-- vim-tmux-navigator
--
-- C-h/j/k/l move between panes, but pass through to (n)vim/fzf so they can
-- handle it. At its edge, nvim calls `rex focus <dir>` to cross into the
-- neighboring Rex pane (nvim/config/plugins/vim-tmux-navigator.lua).
----------------------------------------------------------------------------

local function is_vim(ctx)
  local proc = rex.block.call(TERMINAL, "process", { block_id = ctx.block_id })
  local fg = proc and proc.foreground
  if not fg or not fg.name then
    return false
  end
  -- Mirror vim-tmux-navigator's pattern: vim, nvim, view, vimdiff, fzf,
  -- plus nix's `.foo-wrapped` names.
  local name = fg.name:gsub("^%.", ""):gsub("%-wrapped$", "")
  return name:match("^g?n?vim?x?$") ~= nil
    or name:match("^g?n?vim?diff$") ~= nil
    or name == "view"
    or name == "fzf"
end

for key, dir in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
  rex.bind("ctrl+" .. key, function(ctx, _ev)
    if is_vim(ctx) then
      return false -- let the key reach the terminal
    end
    local _, err = rex.session.focus_direction({ direction = dir, wrap = false })
    return err == nil
  end)
  -- Copy mode doesn't fall through to the function binding above, and a
  -- mode binding must name an action. The terminal isn't reading keys in
  -- copy mode, so there's no vim to pass through to.
  rex.bind("copy/ctrl+" .. key, "pane.focus", { direction = dir })
end

----------------------------------------------------------------------------
-- Ghostty keybinds (ghostty.nix)
----------------------------------------------------------------------------

rex.bind("cmd+-", "client.font.decrease")
rex.bind("cmd+=", "client.font.increase")
rex.bind("cmd+0", "client.font.reset")
rex.bind("cmd+n", "client.window.new")
rex.bind("cmd+w", close_pane) -- ghostty close_surface (see prefix x)

----------------------------------------------------------------------------
-- Theme
--
-- Rex can't set colors from Lua. This action imports the Ghostty theme file
-- that default.nix renders from ghostty.nix's palette. Run it once from the
-- command palette ("Import Gruvbox Theme"). The app remembers the choice.
----------------------------------------------------------------------------

rex.action({
  name = "import_theme",
  title = "Import Gruvbox Theme",
  category = "View",
  keywords = "theme gruvbox ghostty colors palette",
  run = function(_ctx, _args)
    rex.client.queue("client.theme.import", {
      path = config_home .. "/rex/themes/gruvbox-dark-hard.ghostty",
    })
  end,
})
