{ pkgs }:
{
  enable = true;
  shortcut = "a";
  keyMode = "vi";
  escapeTime = 0;
  clock24 = true;
  # baseIndex = 1;
  shell = "${pkgs.zsh}/bin/zsh";
  terminal = "tmux-256color"; # wanna mess with this to see if it changes anything about the weird prompt spacing issue
  # terminal = "alacritty"; # wanna mess with this to see if it changes anything about the weird prompt spacing issue
  historyLimit = 4000;
  plugins = with pkgs; [
    {
      plugin = tmuxPlugins.cpu;
      extraConfig = ''
        ### I can put these all in the color scheme section at the bottom,
        ### maybe? then use #{cpu_bg_color} instead of the color strings I'm
        ### using
        # set -g @cpu_low_fg_color "#[fg=colour246]"
        # set -g @cpu_medium_fg_color "#[fg=colour246]"
        # set -g @cpu_high_fg_color "#[fg=colour246]"
        # set -g @cpu_low_bg_color "#[bg=colour237]"
        # set -g @cpu_medium_bg_color "#[bg=colour237]"
        # set -g @cpu_high_bg_color "#[bg=colour237]"
        set -g @cpu_percentage_format " cpu: %3.1f%% "

        # set -g @ram_low_fg_color "#[fg=colour246]"
        # set -g @ram_medium_fg_color "#[fg=colour246]"
        # set -g @ram_high_fg_color "#[fg=colour246]"
        # set -g @ram_low_bg_color "#[bg=colour239]"
        # set -g @ram_medium_bg_color "#[bg=colour239]"
        # set -g @ram_high_bg_color "#[bg=colour239]"
        set -g @ram_percentage_format " mem: %3.1f%% "

        set-option  -g status-right '#[fg=colour246, bg=colour237]#{cpu_percentage}'
        set-option -ag status-right '#[fg=colour246, bg=colour238]#{ram_percentage}'
      '';
    }
    {
      plugin = tmuxPlugins.battery;
      extraConfig = ''
        set-option  -ag status-right '#[fg=colour246, bg=colour239, nobold, nounderscore, noitalics] batt: #{battery_percentage} '
      '';
    }
    tmuxPlugins.vim-tmux-navigator
    tmuxPlugins.resurrect
    {
      plugin = tmuxPlugins.continuum;
      extraConfig = ''
        set -g @continuum-restore 'on'
      '';
    }
  ];
  extraConfig = ''
    set -g terminal-overrides ",alacritty:RGB"

    set -g base-index 1
    set -g pane-base-index 1

    #### so that i can programatically change title from vim
    set-option -g set-titles on

    ##### copy to keyboard with vim binding
    bind-key v split-window -h

    ##### copy to keyboard with vim binding
    unbind-key -T copy-mode-vi Space     ;   bind-key -T copy-mode-vi v send-keys -X begin-selection
    unbind-key -T copy-mode-vi Enter     ;   bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "pbcopy"
    unbind-key -T copy-mode-vi C-v       ;   bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
    unbind-key -T copy-mode-vi [         ;   bind-key -T copy-mode-vi [ send-keys -X begin-selection
    unbind-key -T copy-mode-vi ]         ;   bind-key -T copy-mode-vi ] send-keys -X copy-selection

    #### prefix + prefix window swapping
    bind-key a last-window
    bind '"' split-window -c "#{pane_current_path}"
    bind % split-window -h -c "#{pane_current_path}"
    bind c new-window -c "#{pane_current_path}"

    #### reload config
    bind r source-file ~/.tmux.conf \; display-message "Config reloaded..."

    #### mouse mode
    set -g mouse on

    #### send prefix (so C-b works as prefix on remote)
    bind-key -n C-Tab send-prefix

    ## COLORSCHEME: gruvbox dark
    set-option -g status "on"

    # default statusbar color
    set-option -g status-style bg=colour237,fg=colour223 # bg=bg1, fg=fg1

    # default window title colors
    set-window-option -g window-status-style bg=colour214,fg=colour237 # bg=yellow, fg=bg1

    # default window with an activity alert
    set-window-option -g window-status-activity-style bg=colour237,fg=colour248 # bg=bg1, fg=fg3

    # active window title colors
    set-window-option -g window-status-current-style bg=red,fg=colour237 # fg=bg1

    # pane border
    set-option -g pane-active-border-style fg=colour250 #fg2
    set-option -g pane-border-style fg=colour237 #bg1

    # message infos
    set-option -g message-style bg=colour239,fg=colour223 # bg=bg2, fg=fg1

    # writing commands inactive
    set-option -g message-command-style bg=colour239,fg=colour223 # bg=fg3, fg=bg1

    # pane number display
    set-option -g display-panes-active-colour colour250 #fg2
    set-option -g display-panes-colour colour237 #bg1

    # clock
    set-window-option -g clock-mode-colour colour109 #blue

    # bell
    set-window-option -g window-status-bell-style bg=colour167,fg=colour235 # bg=red, fg=bg

    ## Theme settings mixed with colors (unfortunately, but there is no cleaner way)
    ## NOTE(ehden): there actually may be a cleaner way to set backgrounds on
    # individual plugins via their own options. see
    # https://github.com/tmux-plugins/tmux-cpu#customization
    set-option -g status-justify "left"
    set-option -g status-left-style none
    set-option -g status-left-length "80"
    set-option -g status-right-style none
    set-option -g status-right-length "80"
    set-window-option -g window-status-separator ""

    set-option -g status-left "#[fg=colour247, bg=colour241] #S "
    set-option -ag status-right "#[fg=colour237, bg=colour248] %l:%M %p %a %d-%b-%y "
    set-window-option -g window-status-current-format "#[fg=colour239, bg=colour214] #I:#[fg=colour239, bg=colour214, bold] #W #[fg=colour214, bg=colour237, nobold, noitalics, nounderscore]"
    set-window-option -g window-status-format         "#[fg=colour223, bg=colour239] #I:#[fg=colour223, bg=colour239      ] #W #[fg=colour239, bg=colour237, noitalics]"
    # END COLORSCHEME
  '';
}
