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

    aliases = {
      l = [ "log" "-r" "(trunk()..@):: | (trunk()..@)-" "--no-pager" ];
      _l = [ "log" "-r" "(trunk()..@):: | (trunk()..@)-" "-T" "builtin_log_detailed" "--no-pager" ];
      lg = [ "log" "-r" "trunk()..@ | ::trunk()" ];
      _lg = [ "log" "-r" "trunk()..@ | ::trunk()" "-T" "builtin_log_detailed" ];

      # NOTE: this is kinda unsafe because it can pull e.g main or next up if
      # i'm already caught up
      ub = [ "bookmark" "move" "--from" "heads(::@- & bookmarks())" ];

      rb = [ "rebase" "-d" "trunk()" ];
      s = [ "status" "--no-pager" ];
      nt = [ "new" "trunk()" ];
    };
  };
}
