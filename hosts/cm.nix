{ inputs }:

{
  arch = "aarch64-darwin";

  system = {
    imports = [
      ../modules/profiles/darwin-system.nix
      ../modules/rosetta.nix
      ../modules/elasticsearch-volume.nix
    ];
  };

  homebrew = {
    brews = [ ];
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
        ../modules/profiles/darwin-home.nix
        inputs.chattermill.homeModules.default
        ../modules/kubernetes.nix
        ../modules/vault.nix
        ../modules/redocly.nix
        ../modules/container.nix
        (
          { lib, pkgs, ... }:
          let
            terraformVersion = "1.5.7";
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
            home.packages = [ pkgs.tfenv ];
            home.activation.terraform = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              run ${lib.getExe pkgs.tfenv} install ${terraformVersion}
              run ${lib.getExe pkgs.tfenv} use ${terraformVersion}
            '';
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
