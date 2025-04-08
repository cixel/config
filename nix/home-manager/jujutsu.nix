{ lib }:
{
  enable = true;
  settings = {
    user = {
      name = lib.mkDefault "Ehden Sinai";
      email = lib.mkDefault "ehdens@gmail.com";
    };

    ui = {
      paginate = "auto";
      default-command = "log";
    };

    templates = {
      git_push_bookmark = ''"ehden/push-" ++ change_id.short()'';
    };

    template-aliases = {
      "bookmarks_at_remote(remote)" = ''
        remote_bookmarks.filter(|b| b.remote() == remote)
      '';
    };

    revset-aliases = {
      "closest_bookmark(to)" = "heads(::to & bookmarks())";
      "closest_pushable(to)" = ''heads(::to & ~description(exact:"") & (~empty() | merges()))'';
      "dependabot_prs" = ''remote_bookmarks(glob:"dependabot/*")'';

      # https://youtu.be/ZnTNFIMjDwg?t=779
      "stack(x, n)" = "ancestors(reachable(x, mutable()), n)";
      "stack(x)" = "stack(x, 2)";
      "stack()" = "stack(@)";
    };

    aliases = {
      l = [ "log" "-r" "(trunk()..@):: | (trunk()..@)-" "--no-pager" ];
      _l = [ "log" "-r" "(trunk()..@):: | (trunk()..@)-" "-T" "builtin_log_detailed" "--no-pager" ];
      lg = [ "log" "-r" "trunk()..@ | ::trunk()" ];
      _lg = [ "log" "-r" "trunk()..@ | ::trunk()" "-T" "builtin_log_detailed" ];

      # https://github.com/jj-vcs/jj/discussions/5568#discussioncomment-12674748
      ub = ["bookmark" "move" "--from" "closest_bookmark(@)" "--to" "closest_pushable(@)"];

      rb = [ "rebase" "-d" "trunk()" ];
      s = [ "status" "--no-pager" ];
      nt = [ "new" "trunk()" ];

      dependabot_update = [
        "util" "exec" "--" "bash" "-c" ''
          jj git fetch
          jj bookmark track $(jj log -r 'dependabot_prs' -T 'bookmarks_at_remote("origin") ++ " "' --no-graph)
          jj rebase -d 'trunk()' -r 'dependabot_prs'
        ''
      ];
      dependabot = [
        "util" "exec" "--" "bash" "-c" ''
          jj dependabot_update
          jj git push -r 'trunk()+:: & bookmarks(glob:"dependabot/*")'
        ''
      ];

      pr = [
        "util" "exec" "--" "bash" "-c" ''
          gh pr create --head $(
            jj log -r 'closest_bookmark(@)' -T 'bookmarks' --no-graph | cut -d ' ' -f 1
          )
        ''
      ];
    };
  };
}
