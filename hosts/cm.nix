{ inputs }:

{
  arch = "aarch64-darwin";

  system = {
    imports = [
      ../modules/darwin-core.nix
      ../modules/system.nix
      ../modules/sudo.nix
      ../modules/homebrew.nix
      ../modules/container-package.nix
      ../modules/account.nix
      ../modules/rosetta.nix
      ../modules/elasticsearch-volume.nix
    ];
  };

  homebrew = {
    brews = [
      "jnsahaj/lumen/lumen"
    ];
    casks = [
      "ghostty"
      "logseq"
      "zed"
      "google-chrome"
      "slack"
      "signal"
      "claude"
      "linear"
      "notion"
      "1password"
      "1password-cli"
    ];
  };

  users = {
    mostlyobvious = {
      admin = true;
      modules = [
        ../modules/core.nix
        ../modules/cli.nix
        ../modules/git.nix
        ../modules/fish.nix
        ../modules/neovim.nix
        ../modules/ruby.nix
        ../modules/claude.nix
        ../modules/pi.nix
        inputs.chattermill.homeModules.default
        ../modules/eza.nix
        ../modules/skills.nix
        ../modules/ghostty.nix
        ../modules/zed.nix
        ../modules/ssh.nix
        ../modules/fonts.nix
        ../modules/macos-defaults.nix
        ../modules/kubernetes.nix
        ../modules/vault.nix
        ../modules/redocly.nix
        ../modules/container.nix
        (
          { lib, pkgs, ... }:
          let
            mcpClickhouse = pkgs.writeShellScript "mcp-clickhouse" ''
              exec ${lib.getExe' pkgs.uv "uvx"} \
                --quiet \
                --no-config \
                --no-python-downloads \
                --python ${lib.getExe pkgs.python315} \
                --from mcp-clickhouse==0.7.0 \
                mcp-clickhouse "$@"
            '';
          in
          {
            my.userEmail = "pawel.pacana@chattermill.io";
            programs.git.settings.init.defaultBranch = "main"; # work convention
            programs.fish.interactiveShellInit = ''
              set --global --export MUTANT_JOBS 8
            '';
            programs.uv.python.versions = lib.mkForce [ ];
            programs.uv.tool.packages = lib.mkForce [ ];
            home.file.".local/bin/mcp-clickhouse" = {
              source = mcpClickhouse;
              force = true;
            };
          }
        )
      ];
    };
  };
}
