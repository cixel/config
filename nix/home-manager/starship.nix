{ pkgs, lib }:
{
  enable = true;
  enableZshIntegration = true;
  settings = {
    scan_timeout = 5;
    add_newline = false;
    format = lib.concatStrings [
      "$cmd_duration"
      "$time"
      "$username$hostname"
      "$nix_shell"

      "\${custom.git_branch}"
      "\${custom.git_state}"
      "\${custom.git_status}"
      "\${custom.jj}"

      "$directory"
      "$jobs"
      "$character"
    ];

    character = {
      success_symbol = "[;](bold green)";
      error_symbol = "[;](bold red)";
    };

    aws = {
      symbol = "";
    };

    battery = {
      disabled = true;
    };

    cmd_duration = {
      style = "dimmed white";
      show_milliseconds = true;
      format = "[\\($duration\\)]($style)\n";
    };

    directory = {
      style = "bold blue";
      fish_style_pwd_dir_length = 1;
    };

    git_branch = {
      style = "purple";
      format = "[$symbol$branch]($style) ";
    };

    git_status = {
      # re-enabling for now to see how it behaves with potential performance improvements
      # disabled = true;
      deleted = "X";
    };

    hostname = {
      style = "bold dimmed blue";
      format = "[@$hostname]($style) ";
    };

    nix_shell = {
      # this appears to add an extra space following "character" when enabled if
      # state is a snowflake, and not otherwise. starship (or alacritty? or tmux?)
      # may have trouble counting non-single width characters in the prompt
      #
      # in fucking around w/ this elsehwere, it may be tmux's fault
      format = "[$state \\($name\\)]($style) ";
      # impure_msg = "❄️";
      # impure_msg = "🤗";
      impure_msg = "n";
      pure_msg = "[n](green)";
    };

    time = {
      disabled = true;
      format = "[$time]($style) ";
      style = "bold green";
    };

    username = {
      style_user = "bold dimmed blue";
      format = "[$user]($style)";
    };

    custom.jj = {
      detect_folders = [ ".jj" ];
      command = "jj log -r@ -n1 --color always --ignore-working-copy --no-graph -T 'change_id.shortest()'";
      shell = ["${pkgs.dash}/bin/dash" "-f" "-c" "-"];
      use_stdin = false;
    };
    custom.git_branch = {
      detect_folders = [ "!.jj" ".git" ];
      command = "starship module git_branch";
      description = "only show if we're not in a jj repo";
      shell = ["${pkgs.dash}/bin/dash" "-f" "-c" "-"];
      use_stdin = false;
    };
    custom.git_state = {
      detect_folders = [ "!.jj" ".git" ];
      command = "starship module git_state";
      description = "only show if we're not in a jj repo";
      shell = ["${pkgs.dash}/bin/dash" "-f" "-c" "-"];
      use_stdin = false;
    };
    custom.git_status = {
      detect_folders = [ "!.jj" ".git" ];
      command = "starship module git_status";
      description = "only show if we're not in a jj repo";
      shell = ["${pkgs.dash}/bin/dash" "-f" "-c" "-"];
      use_stdin = false;
    };
  };
}
