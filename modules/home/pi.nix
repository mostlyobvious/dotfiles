{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:

let
  piNodejs = lib.findFirst (
    pkg: lib.getName pkg == "nodejs"
  ) (throw "pi-coding-agent no longer exposes a nodejs build input") pkgs.pi-coding-agent.buildInputs;
  piWithNpm = pkgs.symlinkJoin {
    name = "pi-coding-agent-with-npm";
    paths = [ pkgs.pi-coding-agent ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/pi --prefix PATH : ${lib.makeBinPath [ piNodejs ]}
    '';
  };
in
{
  # pi the coding agent, from nixpkgs; shared module so both host and VM get it.
  # Its wrapper exposes the same npm bundled with pi-coding-agent to pi's package
  # installer without adding Node/npm to the user's global packages.
  home.packages = [
    piWithNpm
    inputs.mcp-nixos.packages.${pkgs.system}.mcp-nixos
  ];

  # Out-of-store: pi rewrites settings.json and MCP adapter config at runtime,
  # so edits land straight in the working copy. The rest of ~/.pi (auth.json,
  # trust.json, npm/) is runtime state and secrets, left unmanaged.
  home.file.".pi/agent/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesDir}/config/pi/settings.json";

  home.file.".pi/agent/mcp.json".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesDir}/config/pi/mcp.json";
}
