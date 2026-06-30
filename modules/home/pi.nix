{
  config,
  inputs,
  pkgs,
  ...
}:

{
  # Pi the coding agent, from nixpkgs; shared module so both host and VM get it.
  # The module wraps pi with Node/npm for package installs without adding Node to
  # the user's global package set.
  programs.pi-coding-agent = {
    enable = true;
    extraPackages = [ pkgs.nodejs ];
  };

  home.packages = [ inputs.mcp-nixos.packages.${pkgs.system}.mcp-nixos ];

  # Out-of-store: pi rewrites settings.json and MCP adapter config at runtime,
  # so edits land straight in the working copy. The rest of ~/.pi (auth.json,
  # trust.json, npm/) is runtime state and secrets, left unmanaged.
  home.file.".pi/agent/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesDir}/config/pi/settings.json";

  home.file.".pi/agent/mcp.json".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesDir}/config/pi/mcp.json";
}
