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

    git = {
      push-bookmark-prefix = "ehden/push-";
    };

    revset-aliases = {
      "closest_bookmark(to)" = "heads(::to & bookmarks())";
      "closest_pushable(to)" = ''heads(::to & ~description(exact:"") & (~empty() | merges()))'';
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
    };
  };
}
