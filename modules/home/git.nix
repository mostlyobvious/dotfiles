{
  config,
  lib,
  pkgs,
  ...
}:

let
  stripAnsiItalic = pkgs.writeText "strip-ansi-italic.pl" ''
    sub sgr {
      my @in = split /;/, shift;
      my @out;
      for (my $i = 0; $i < @in; $i++) {
        my $p = $in[$i];
        if (($p eq "38" || $p eq "48") && (($in[$i + 1] // "") eq "2")) {
          push @out, @in[$i .. $i + 4];
          $i += 4;
          next;
        }
        if (($p eq "38" || $p eq "48") && (($in[$i + 1] // "") eq "5")) {
          push @out, @in[$i .. $i + 2];
          $i += 2;
          next;
        }
        next if $p eq "3" || $p eq "03" || $p eq "23";
        push @out, $p if $p ne "";
      }
      return "\e[" . (@out ? join(";", @out) : "0") . "m";
    }
    s/\e\[([0-9;]*)m/sgr($1)/eg;
  '';
  difftNoItalic = pkgs.writeShellApplication {
    name = "difft-no-italic";
    runtimeInputs = with pkgs; [
      difftastic
      perl
    ];
    text = ''
      set +e
      difft "$@" | perl -CS -p ${stripAnsiItalic}
      status="''${PIPESTATUS[0]}"
      set -e
      exit "$status"
    '';
  };
in
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
      "dark" = true;
      "navigate" = true;
      "side-by-side" = true;
      "syntax-theme" = "ansi";
      "true-color" = "always";
      "zero-style" = "syntax";
      "minus-style" = "syntax";
      "minus-emph-style" = "syntax";
      "minus-non-emph-style" = "syntax";
      "plus-style" = "syntax";
      "plus-emph-style" = "syntax";
      "plus-non-emph-style" = "syntax";
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
          dc = "diff --cached";
          cp = "cherry-pick";
          df = "diff";
          ca = "commit --amend --reuse-message=HEAD --no-verify";
          pu = "pull";
          pr = "pull --rebase";
          ra = "rebase --abort";
          rc = "rebase --continue";
          ri = "rebase --interactive --no-verify";
          rs = "reset --soft HEAD~1";
          rh = "reset --hard";
          lg = "log -p --ext-diff";
          ls = ''log --ext-diff --pretty=format:"%C(yellow)%h%Cred%d\ %Cblue%ci\ %Creset%s%Cblue\ [%cn]" --decorate'';
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
          external = lib.getExe difftNoItalic;
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
