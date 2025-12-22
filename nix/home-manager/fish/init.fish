fish_vi_key_bindings
bind -M default V edit_command_buffer
set -g fish_greeting
set -g fish_prompt_pwd_dir_length 1
set -g fish_prompt_pwd_full_dirs 3

# LLM-derived color scheme, pulled from elsewhere in the config

# Gruvbox Dark Hard — match ghostty palette + tmux statusline.
# Command-line syntax highlighting.
set -g fish_color_normal       fbf1c7  # fg
set -g fish_color_command      b8bb26  # green   (matches starship character ;)
set -g fish_color_keyword      fb4934  # red
set -g fish_color_quote        b8bb26  # green
set -g fish_color_redirection  d3869b  # purple  (matches starship git_branch)
set -g fish_color_end          fe8019  # orange
set -g fish_color_error        fb4934  # red
set -g fish_color_param        d5c4a1  # fg2
set -g fish_color_comment      928374  # gray
set -g fish_color_selection    --background=3c3836
set -g fish_color_search_match --background=3c3836
set -g fish_color_operator     8ec07c  # aqua
set -g fish_color_escape       fe8019
set -g fish_color_autosuggestion 665c54
set -g fish_color_cwd          83a598  # blue    (matches starship directory)
set -g fish_color_user         83a598
set -g fish_color_host         83a598

# Completion pager.
set -g fish_pager_color_progress       'fabd2f --background=3c3836'
set -g fish_pager_color_prefix         'fb4934 --bold'
set -g fish_pager_color_completion     d5c4a1
set -g fish_pager_color_description    '928374 --italics'
set -g fish_pager_color_selected_background --background=504945
set -g fish_pager_color_selected_prefix     fb4934
set -g fish_pager_color_selected_completion fbf1c7
set -g fish_pager_color_selected_description '928374 --italics'
