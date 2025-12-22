{ darwin, pkgs }:
{
  enable = true;

  preferAbbrs = true;

  # Tide is our async fish prompt (configured in ./fish/tide.fish). The plugin
  # source ships `functions/` and `conf.d/`, which home-manager links onto
  # `fish_function_path` for us.
  plugins = [
    {
      name = "tide";
      src = pkgs.fishPlugins.tide.src;
    }
  ];

  shellAbbrs = {
    hms =
      if darwin then
        "sudo -E nix run nix-darwin -- -v -L switch --flake path:$HOME/.config"
      else
        "sudo nixos-rebuild switch -v --flake path:$HOME/.config";

    sudov = "sudo -E -s nvim";

    lg = "eza --long --all --git-ignore";
    lt = "eza --long --all --sort newest";
    ls = "eza";
    tree = "eza --tree --long";

    gd = "go doc";
    gdu = "go doc -u";

    docker = "podman";
  };

  # Tide prompt setup must run in non-interactive subshells too: tide forks
  # `fish -c` to compute the prompt asynchronously, and that subshell needs
  # both the `tide_*` globals and our custom `_tide_item_*` functions. Putting
  # the config in shellInit (config.fish) covers interactive + -c sessions;
  # interactiveShellInit only runs for interactive shells and would leave the
  # background prompt subshell undefined.
  shellInit = builtins.readFile ./fish/tide.fish;
  shellInitLast = ''
    set -gx FZF_COMPLETION_OPTS '--bind=tab:down,ctrl-y:accept'

    fish_add_path --path --prepend $(go env GOBIN) $(go env GOPATH)/bin $HOME/.cargo/bin

    if test -f $HOME/go/bin/go
      alias godev "$HOME/go/bin/go"
    end
  '';

  # Interactive-only setup: vi mode + gruvbox colors.
  interactiveShellInit = builtins.readFile ./fish/init.fish;

  functions = {
    svg = ''
      dot -Tsvg $argv[1] -o $argv[1].svg
    '';

    # Override tide's `_tide_pwd` with a starship-style "repo anchor"
    # renderer.
    #
    # Defined here (not in shellInit) so home-manager drops it at
    # ~/.config/fish/functions/_tide_pwd.fish. Fish's autoload walks
    # $fish_function_path in order and $fish_function_path[1] is the user
    # functions dir, so our copy shadows the one shipped by the tide plugin
    # (injected at index 2 by plugin-tide.fish). This also keeps
    # `source (functions --details _tide_pwd)` in tide's fish_prompt cheap:
    # it re-sources just this file rather than all of config.fish (which is
    # where a `shellInit` definition would land).
    #
    # Behavior mirrors starship's `directory` module with `truncate_to_repo`:
    # walk up from $PWD to the nearest ancestor containing a VCS marker
    # (.git / .jj / .hg / .svn / .bzr), then render the parent dirs above
    # that anchor as single-char abbreviations and keep the anchor + tail
    # in full. Examples (with HOME=/Users/ehdens, repo at
    # ~/contrast/go-agent):
    #   ~/contrast/go-agent             -> ~/c/go-agent
    #   ~/contrast/go-agent/agent       -> ~/c/go-agent/agent
    #   ~/contrast/go-agent/agent/sub   -> ~/c/go-agent/agent/sub
    # When no anchor is found we fall back to plain `prompt_pwd`
    # (per-component truncation via $fish_prompt_pwd_dir_length, leaf full).
    #
    # We only walk filesystem ancestors of $PWD, so this is O(depth) stats
    # per prompt redraw. tide already runs the prompt in a forked subshell,
    # so the stats don't block keystrokes. We don't reuse `$_tide_parent_dirs`
    # because that global is only kept current inside the interactive
    # parent shell, while `_tide_pwd` is invoked from tide's forked prompt
    # subshell where it can be stale.
    #
    # Color: tide paints the whole segment via `tide_pwd_color` in
    # `_tide_print_item`. We don't try to highlight the anchor specially.
    #
    # `_tide_pwd_len` is the global tide reads to compute right-prompt
    # connection padding; track it the same way tide's own _tide_pwd does.
    _tide_pwd = ''
      set -l real $PWD
      set -l markers .git .jj .hg .svn .bzr

      set -l anchor ""
      set -l d $real
      while true
          for m in $markers
              if test -e "$d/$m"
                  set anchor $d
                  break
              end
          end
          test -n "$anchor"; and break
          test "$d" = / ; and break
          set d (path dirname -- $d)
      end

      set -l out
      if test -n "$anchor"
          # `tail` is the suffix of $real after the anchor, including the
          # leading slash (empty when $PWD is the anchor itself).
          set -l tail (string sub -s (math (string length -- $anchor) + 1) -- $real)

          if test "$anchor" = "$HOME"
              # Repo lives at $HOME; just collapse to ~.
              set out "~$tail"
          else
              # Truncate every component of the parent (the dirs above the
              # anchor) to one char, after replacing a $HOME prefix with ~.
              # Use explicit prefix matching instead of `string replace`
              # because the latter would also rewrite a literal "$HOME"
              # occurrence in the middle of the path.
              set -l parent (path dirname -- $anchor)
              set -l p $parent
              switch $p
                  case "$HOME"
                      set p '~'
                  case "$HOME/*"
                      set p '~/'(string sub -s (math (string length -- $HOME) + 2) -- $p)
              end
              set -l parts (string split / -- $p)
              set -l shortparts
              for c in $parts
                  if test -z "$c"; or test "$c" = '~'
                      set -a shortparts $c
                  else
                      set -a shortparts (string sub -l 1 -- $c)
                  end
              end
              set -l short (string join / $shortparts)
              if test -z "$short"
                  # Anchor sits directly under / (e.g. /foo with /foo/.git).
                  set out /(path basename -- $anchor)$tail
              else
                  set out $short/(path basename -- $anchor)$tail
              end
          end
      else
          set out (prompt_pwd)
      end

      string length -V -- $out | read -g _tide_pwd_len
      echo -n $out
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
