{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.packages = [ pkgs.tig ];

  programs.difftastic = {
    enable = true;
    options.color = "always";
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      # Rosé Pine-flavoured decorations around delta's syntax output.
      # Delta does not ship a Rosé Pine syntect theme, so keep syntax colours
      # terminal-driven while matching the chrome to the shared palette.
      "dark" = true;
      "navigate" = true;
      "line-numbers" = true;
      "side-by-side" = true;
      "syntax-theme" = "ansi";
      "true-color" = "always";
      "zero-style" = "syntax";
      "minus-style" = "syntax #3e252f";
      "plus-style" = "syntax #23362f";
      "file-style" = "bold #c4a7e7";
      "hunk-header-style" = "file line-number syntax bold";
      "hunk-header-decoration-style" = "#ebbcba";
      "line-numbers-left-style" = "#908caa";
      "line-numbers-right-style" = "#908caa";
      "line-numbers-minus-style" = "#eb6f92";
      "line-numbers-plus-style" = "#9ccfd8";
    };
  };

  programs.git = {
    enable = true;

    signing = lib.mkIf pkgs.stdenv.isDarwin {
      format = "ssh";
      key = "${config.home.homeDirectory}/.ssh/id_ed25519.pub";
      signByDefault = true;
    };

    ignores = [
      "*.gem"
      "*.rbc"
      "*.sublime-workspace"
      ".DS_Store"
      ".byebug_history"
      ".env"
      ".generators"
      ".idea"
      ".ruby-lsp"
      ".rakeTasks"
      ".rspec"
      ".ruby-gemset"
      ".ruby-version"
      ".rvmrc"
      ".vscode"
      ".yarn-integrity"
      "/yarn-error.log"
      "node_modules"
      "yarn-debug.log*"
      ".claude/settings.local.json"
      ".nvim.lua"
    ];

    settings = lib.mkMerge [
      {
        user = {
          name = "Paweł Pacana";
          email = "pawel.pacana@gmail.com";
        };

        alias = {
          aa = "add -A";
          st = "status";
          ci = "commit -v --no-verify";
          rv = "revert";
          mg = "merge";
          br = "branch";
          co = "checkout";
          dc = "diff --cached -w --patience --word-diff=color";
          cp = "cherry-pick";
          df = "diff -w --patience --word-diff=color";
          dft = "!f() { GIT_EXTERNAL_DIFF=difft git diff --ext-diff \"$@\"; }; f";
          showft = "!f() { GIT_EXTERNAL_DIFF=difft git show --ext-diff \"$@\"; }; f";
          logft = "!f() { GIT_EXTERNAL_DIFF=difft git log -p --ext-diff \"$@\"; }; f";
          ca = "commit --amend --reuse-message=HEAD --no-verify";
          pu = "pull";
          pr = "pull --rebase";
          ra = "rebase --abort";
          rc = "rebase --continue";
          ri = "rebase --interactive --no-verify";
          rs = "reset --soft HEAD~1";
          rh = "reset --hard";
          lg = "log -p";
          ls = ''log --pretty=format:"%C(yellow)%h%Cred%d\ %Cblue%ci\ %Creset%s%Cblue\ [%cn]" --decorate'';
        };

        core = {
          editor = "nvim";
          quotepath = false;
          pager = "delta";
        };
        merge.tool = "nvim -d";
        color.ui = true;
        github.user = "mostlyobvious";
        push.default = "current";
        branch.autosetupmerge = true;
        url."git@github.com:" = {
          insteadOf = "gh:";
          pushInsteadOf = [
            "https://github.com/"
            "http://github.com/"
            "gh:"
          ];
        };
        diff = {
          indentHeuristic = true;
          noprefix = true;
          tool = "nvim_difftool";
        };
        pull.rebase = true;
        commit.verbose = true;
        trailer.coop = {
          key = "Co-authored-by: ";
          ifmissing = "add";
        };
        init.defaultBranch = "master";
        branch.sort = "-committerdate";
        tag.sort = "version:refname";
        column.ui = "auto";
        difftool.nvim_difftool.cmd = ''nvim -c "DiffTool $LOCAL $REMOTE"'';
      }

    ];
  };
}
