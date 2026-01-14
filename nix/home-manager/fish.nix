{ darwin }:
{
  enable = true;

  preferAbbrs = true;

  shellAbbrs = {
    hms =
      if darwin then
        "sudo -E nix run nix-darwin -- -v -L switch --flake path:$HOME/.config"
      else
        "sudo nixos-rebuild switch -v --flake path:$HOME/.config";

    sudov = "sudo -E -s nvim";

    l = "eza --long --all";
    lg = "eza --long --all --git-ignore";
    lt = "eza --long --all --sort newest";
    ls = "eza";
    tree = "eza --tree --long";

    gd = "go doc";
    gdu = "go doc -u";

    docker = "podman";
  };

  # Fish-equivalent of the zsh envExtra: prepend tool dirs to PATH and define
  # the godev alias only when a user-local go binary exists.
  shellInit = "";
  shellInitLast = ''
    set -gx FZF_COMPLETION_OPTS '--bind=tab:down,ctrl-y:accept'

    fish_add_path --path --prepend $(go env GOBIN) $(go env GOPATH)/bin $HOME/.cargo/bin

    if test -f $HOME/go/bin/go
      alias godev "$HOME/go/bin/go"
    end
  '';

  # Interactive-only setup: vi mode + helper functions.
  interactiveShellInit = builtins.readFile ./fish/init.fish;

  functions = {
    svg = ''
      dot -Tsvg $argv[1] -o $argv[1].svg
    '';
  };

  binds = {
    # set tab to fzf completion and shift-tab to the default fish completion
    # behavior
    "tab" = {
      mode = "insert";
      operate = "user";
      command = "fzf_complete";
    };
    "shift-tab" = {
      mode = "insert";
      operate = "user";
      command = "complete";
    };

    # sorta mimic ctrl-y to select completion like in vim
    "ctrl-y" = {
      mode = "insert";
      operate = "user";
      command = "forward-char";
    };
  };
}
