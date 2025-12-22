# Tide prompt configuration.
#
# This recreates the starship prompt that previously lived in
# nix/home-manager/starship.nix. Layout:
#
#   user@host n branch ±status abc ~/p/dir ;                (cmd_duration)
#       ^^^^      ^^^^^^^^^^^^^ ^^^^                                ^^^^^^
#       context   git module    jj revision                         right
#
# Goals of this migration:
#   - keep the visual the same (same icons, same colors)
#   - rely on fish's async prompt rendering (tide forks a subshell to compute
#     the prompt, so slow `git status` / `jj log` work doesn't block input)
#
# Color philosophy: starship uses terminal-palette names (e.g. "bold dimmed
# blue"), letting the terminal palette (ghostty's gruvbox config) decide what
# blue actually looks like. We do the same here, passing named colors to
# `set_color` via lists so flags like `-o` (bold) and `-d` (dim) can be
# stacked. Nothing in this file should reference the gruvbox palette directly.
#
# The git rendering is delegated to `starship module ...` so it stays
# byte-identical to the previous configuration without re-deriving the format
# string here. The jj indicator is a small custom item.

# --- Prompt structure -------------------------------------------------------

# Single line, no `newline` item -> tide uses _tide_1_line_prompt.
# `pwd` is tide's standard item; we shadow tide's `_tide_pwd` via
# `programs.fish.functions._tide_pwd` in fish.nix so the rendered segment
# matches `starship module directory` byte-for-byte regardless of depth.
set -g tide_left_prompt_items context nix_shell git jj pwd character
set -g tide_right_prompt_items cmd_duration

set -g tide_left_prompt_frame_enabled false
set -g tide_right_prompt_frame_enabled false
set -g tide_prompt_add_newline_before false
set -g tide_left_prompt_prefix ''
# IMPORTANT: keep suffix empty. tide's `fish_prompt` already appends a literal
# trailing space to the assembled left prompt (`'$color_normal '` in the
# eval'd body). Setting suffix to ' ' would yield double-space before the
# user's command.
set -g tide_left_prompt_suffix ''
set -g tide_right_prompt_prefix ''
set -g tide_right_prompt_suffix ''
set -g tide_left_prompt_separator_same_color ''
set -g tide_left_prompt_separator_diff_color ''
set -g tide_right_prompt_separator_same_color ' '
set -g tide_right_prompt_separator_diff_color ' '
set -g tide_prompt_pad_items false
set -g tide_prompt_transient_enabled false
set -g tide_prompt_min_cols 34
set -g tide_prompt_color_separator_same_color brblack

# --- Character (the `;` prompt symbol) --------------------------------------

set -g tide_character_icon ';'
# starship's vimcmd_symbol default is `[❮](bold green)`; we never overrode
# it in starship.nix, so the previous prompt showed ❮ in vi normal/replace/
# visual mode. Match that here.
set -g tide_character_vi_icon_default '❮'
set -g tide_character_vi_icon_replace '❮'
set -g tide_character_vi_icon_visual '❮'
# Lists expand as multiple args to `set_color`, so we can encode "bold X".
set -g tide_character_color -o green
set -g tide_character_color_failure -o red

# --- Context (user@host, only when SSH'd by default) ------------------------

set -g tide_context_always_display false
set -g tide_context_hostname_parts 1
set -g tide_context_bg_color normal
set -g tide_context_color_default blue
set -g tide_context_color_ssh -o -d blue       # matches starship "bold dimmed blue"
set -g tide_context_color_root -o red

# --- Directory --------------------------------------------------------------
#
# Two-layer render:
#   1. tide's `_tide_print_item pwd @PWD@` emits `set_color $tide_pwd_color
#      -b $tide_pwd_bg_color` right before the `@PWD@` placeholder.
#   2. `fish_prompt` does `string replace @PWD@ (_tide_pwd)` and our
#      `_tide_pwd` (in fish.nix) returns plain `prompt_pwd` output. The
#      `set_color` from step 1 paints the whole segment in one color.
#
# `tide_pwd_color_dirs` is kept because tide's `_tide_cache_variables` reads
# pwd colors when computing values for sibling items. Anchor color,
# truncated-dir color, and the markers list are only consulted by tide's
# stock `_tide_pwd`, which we no longer call — unset them so a stale value
# can't sneak in if someone flips back to the stock renderer without
# revisiting this block.
set -g tide_pwd_bg_color normal
set -g tide_pwd_color -o blue
set -g tide_pwd_color_dirs -o blue
set -g tide_pwd_icon ''
set -g tide_pwd_icon_home ''
set -g tide_pwd_icon_unwritable ''
set -ge tide_pwd_color_anchors
set -ge tide_pwd_color_truncated_dirs
set -g tide_pwd_markers .bzr .citc .git .hg .jj .node-version .python-version .ruby-version .shorten_folder_marker .svn .terraform bun.lockb Cargo.toml composer.json CVS go.mod package.json build.zig

# --- cmd_duration (right prompt) --------------------------------------------

set -g tide_cmd_duration_bg_color normal
set -g tide_cmd_duration_color -d white        # matches starship "dimmed white"
set -g tide_cmd_duration_icon ''
set -g tide_cmd_duration_decimals 0
set -g tide_cmd_duration_threshold 2000        # 2s, same as starship default

# --- Items kept for tide's caching even if we override them ------------------

# `_tide_cache_variables` reads $tide_git_color_branch for $_tide_location_color.
# Our overridden git item ignores tide's colors, but cache_variables still runs.
set -g tide_git_bg_color normal
set -g tide_git_color_branch magenta           # ANSI 5 (your terminal renders as purple)

# Tide's `nix_shell` is overridden below but it still wants these vars.
set -g tide_nix_shell_bg_color normal
set -g tide_nix_shell_color normal
set -g tide_nix_shell_icon n

# Jobs item isn't in our prompt, but keep sane defaults if added later.
set -g tide_jobs_bg_color normal
set -g tide_jobs_color green
set -g tide_jobs_icon ''
set -g tide_jobs_number_threshold 1000

# Custom jj item background, in case tide caching ever reads it.
set -g tide_jj_bg_color normal

# --- Custom items -----------------------------------------------------------
#
# These mimic the separator-handling pattern used by `_tide_print_item`: when
# we're the first rendered item on a side, emit the prompt prefix; otherwise
# emit the same-color separator. `add_prefix` is set globally by
# `_tide_1_line_prompt` and consumed (`set -e`) by the first item that emits
# output. Returning early without touching it preserves it for the next item,
# which is what we want when an item is hidden (e.g. git inside a jj repo).

# Emit the leading separator/prefix for a custom item. Mirrors the same-bg
# branch of `_tide_print_item`. `$_tide_color_separator_same_color` is the
# *raw ANSI escape sequence* for the configured color (tide caches it that
# way in `_tide_cache_variables` via `set_color | read`), so we echo it
# directly. Passing it back through `set_color` is wrong, set_color expects
# color *names* (or hex), not escapes.
function _tide_custom_item_prefix
    if set -e add_prefix
        set_color normal -b normal
        v=tide_"$_tide_side"_prompt_prefix echo -ns $$v
    else
        v=tide_"$_tide_side"_prompt_separator_same_color echo -ns $_tide_color_separator_same_color$$v
    end
end

# Context (user@host): shadow tide's stock `_tide_item_context` so we can
# append a trailing space. The stock item leans on the left-prompt separator
# for spacing, but we run with empty separators (every other item appends its
# own trailing space instead -- see the jj and nix_shell items below), so
# without this the context segment would be glued to the following item.
function _tide_item_context
    if set -q SSH_TTY
        set -fx tide_context_color $tide_context_color_ssh
    else if test "$EUID" = 0
        set -fx tide_context_color $tide_context_color_root
    else if test "$tide_context_always_display" = true
        set -fx tide_context_color $tide_context_color_default
    else
        return
    end

    string match -qr "^(?<h>(\.?[^\.]*){0,$tide_context_hostname_parts})" @$hostname
    _tide_print_item context $USER$h
    # Trailing space so the next item isn't glued to user@host. Mirrors the
    # convention used by the jj and nix_shell custom items below.
    echo -ns ' '
end

# True inside a jj repo, even from a subdirectory of the workspace.
#
# `_tide_parent_dirs` is maintained by tide via an `--on-variable PWD`
# handler and contains every ancestor of `$PWD` (plus `$PWD` itself), so
# `path is -d $_tide_parent_dirs/.jj` is a glob-style multi-stat: zero forks,
# zero new subshells, and we still detect when we're deep inside a workspace
# instead of only at the root. This is the same trick the stock tide items
# (`_tide_item_node`, `_tide_item_rustc`, etc.) use for their marker files.
function _tide_in_jj_repo
    path is -d $_tide_parent_dirs/.jj
end

# Git module: only render in a git repo and only outside jj repos. Delegates
# to `starship prompt --profile git`, which uses the `[profiles] git = ...`
# entry in ~/.config/starship.toml to emit `$git_branch$git_state$git_status`
# in a single starship invocation (one config parse, one git subprocess fork).
# Formatting stays identical to the previous starship configuration.
function _tide_item_git
    _tide_in_jj_repo; and return
    command git rev-parse --is-inside-work-tree 2>/dev/null 1>/dev/null
    or return

    _tide_custom_item_prefix

    # Starship emits its own ANSI colors per ~/.config/starship.toml, so we
    # don't need set_color here. The profile's format already includes the
    # per-module trailing spaces.
    command starship prompt --profile git

    set -g prev_bg_color normal
end

# jj revision: short change id with jj's own coloring, only in a jj repo.
# `jj log` from a subdirectory of a workspace works fine, so we don't need
# to cd or pass --repository.
function _tide_item_jj
    _tide_in_jj_repo; or return
    set -l rev (command jj log -r@ -n1 --color always --ignore-working-copy --no-graph -T 'change_id.shortest()' 2>/dev/null)
    test -z "$rev"; and return

    _tide_custom_item_prefix
    # Trailing space so the next item (pwd) isn't glued to the change id.
    # Other items follow the same convention (starship's git format has a
    # literal trailing space; nix_shell below appends one explicitly).
    echo -ns $rev ' '
    set -g prev_bg_color normal
end

# `_tide_pwd` (the actual path renderer) is defined as an autoload function
# via `programs.fish.functions._tide_pwd` in fish.nix; see that file for the
# starship-parity mapping and the rationale for keeping it out of shellInit.

# nix_shell indicator: green `n` when pure, default `n` otherwise. Appends
# ` (name)` if nix-shell was entered with `--name`. Matches the starship
# format `[$state ($name)]` with `pure_msg = green n`, `impure_msg = n`.
function _tide_item_nix_shell
    set -q IN_NIX_SHELL
    or return

    _tide_custom_item_prefix

    # Start from a known color state. `_tide_custom_item_prefix` leaves the
    # foreground set to `$_tide_color_separator_same_color` (the dim
    # separator color), so without an explicit reset the impure `n` would
    # inherit it and render in brblack instead of the terminal default.
    set_color normal -b normal
    if test "$IN_NIX_SHELL" = pure
        set_color green
        echo -ns n
        set_color normal -b normal
    else
        echo -ns n
    end

    if set -q name; and test -n "$name"
        echo -ns " ($name)"
    end

    # Trailing space so the next item isn't glued to this one. Mirrors the
    # starship `nix_shell` format string, which ends with a literal space.
    echo -ns ' '

    set -g prev_bg_color normal
end
