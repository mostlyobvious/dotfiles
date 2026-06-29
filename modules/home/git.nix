{
  config,
  lib,
  pkgs,
  ...
}:

let
  diffHighlight = "${pkgs.git}/share/git/contrib/diff-highlight/diff-highlight";
in
{
  programs.git = {
    enable = true;

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
          pager = "less -iXFR";
        };
        merge.tool = "nvim -d";
        color.ui = true;
        pager = {
          log = "${diffHighlight} | less";
          show = "${diffHighlight} | less";
          diff = "${diffHighlight} | less";
        };
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
        difftool.nvim_difftool.cmd = ''nvim -c "DiffTool $LOCAL $REMOTE"'';
      }

      # Darwin-only: the signing key is host-bound (the VM uses its own), so
      # gpgSign must not reach the VM.
      (lib.mkIf pkgs.stdenv.isDarwin {
        gpg.format = "ssh";
        user.signingKey = "${config.home.homeDirectory}/.ssh/id_ed25519.pub";
        commit.gpgSign = true;
        tag.gpgSign = true;
      })
    ];
  };
}
