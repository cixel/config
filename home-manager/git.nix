{}:
{
  enable = true;
  userName = "cixel";
  userEmail = "ehdens@gmail.com";

  aliases = {
    lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'";
    aa = "add -A .";
    fpush = "push --force-with-lease";
    st = "status";
    ci = "commit";
    co = "checkout";
    cp = "cherry-pick";
    put = "push origin HEAD";
    fixup = "!sh -c 'git commit --no-verify -m \"fixup! $(git log -1 --format='\\''%s'\\'' $@)\"' -";
    squash = "!sh -c 'git commit --no-verify -m \"squash! $(git log -1 --format='\\''%s'\\'' $@)\"' -";
    doff = "reset head^";
    ri = "rebase --interactive";
    br = "branch";
    pruneremote = "remote prune origin";
    tree = "log --graph --oneline --decorate --color --all";
    tr = "log --graph --oneline --decorate --color";
    unpushed = "!\"PROJ_BRANCH=$(git symbolic-ref HEAD | sed 's|refs/heads/||') && git log origin/$PROJ_BRANCH..HEAD\"";
    unpulled = "!\"PROJ_BRANCH=$(git symbolic-ref HEAD | sed 's|refs/heads/||') && git fetch && git log HEAD..origin/$PROJ_BRANCH\"";
    add-untracked = "!\"git status --porcelain | awk '/\\?\\?/{ print $2 }' | xargs git add\"";
    ln = "log --pretty=format:'%Cblue%h %Cred* %C(yellow)%s'";
    reset-authors = "commit --amend --reset-author -CHEAD";
    rmbranch = "!f(){ git branch -d \${1} && git push origin --delete \${1}; };f";
    snapshot = "!git stash save \"snapshot: $(date)\" && git stash apply \"stash@{0}\" --abbrev-commit --date=relative";
    stash = "git stash push";
    save = "commit -m \"saving\" --no-verify";
    rpull = "pull -r";
  };
  extraConfig = {
    rerere = { enabled = true; };
    gc = {
      writeCommitGraph = true;
    };
    pull = {
      rebase = true;
    };

    difftool."vimdiff".cmd = "nvim -d $LOCAL $BASE";

    # TODO: move these to work.nix
    url."git@github.com:Contrast-Security-Inc/".insteadOf = "https://github.com/Contrast-Security-Inc/";
    url."git@bitbucket.org:".insteadOf = "https://bitbucket.org/";
  };
  ignores = [
    ".classpath"
    ".project"
    ".settings/"

    "TODO"
    "NOTES"

    "gunk/"
    "nocommit/"
  ];
}
