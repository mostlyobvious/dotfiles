{
  config,
  lib,
  pkgs,
  ...
}:

let
  pythonVersion = "3.15.1";
  pythonLauncher = pkgs.writeShellScript "python-${pythonVersion}" ''
    exec "${config.home.homeDirectory}/.local/share/uv/python/cpython-3.15-macos-aarch64-none/bin/python3.15" "$@"
  '';
  pythonCommands = pkgs.runCommand "python-${pythonVersion}-commands" { } ''
    mkdir -p "$out/bin"
    for command in python python3 python3.15; do
      ln -s ${pythonLauncher} "$out/bin/$command"
    done
  '';
in
{
  home.packages = with pkgs; [
    ast-grep
    devenv
    glab
    pythonCommands
    yq
  ];

  home.activation.uvPython = lib.mkForce (
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run ${lib.getExe pkgs.uv} python install --quiet --default ${pythonVersion}
    ''
  );

  programs.direnv = {
    enable = true;
    config = {
      global.hide_env_diff = true;
      whitelist.prefix = [ "${config.home.homeDirectory}/Code/worktrees" ];
    };
    nix-direnv.enable = true;
    silent = true;
  };

  programs.uv.enable = true;

  programs.fd.enable = true;
  programs.gh.enable = true;
  programs.jq.enable = true;
  programs.ripgrep.enable = true;

  programs.fzf = {
    enable = true;
    colors = {
      bg = "-1";
      "bg+" = "-1";
      fg = "-1";
      "fg+" = "-1";
      gutter = "-1";
      header = "8";
      hl = "4";
      "hl+" = "12";
      info = "6";
      marker = "2";
      pointer = "5";
      prompt = "4";
      spinner = "6";
    };
    defaultCommand = "fd --hidden --exclude .git .";
    defaultOptions = [
      "--gutter=⠀"
      "--gutter-raw=⠀"
      "--height=40%"
      "--info=hidden"
      "--layout=reverse"
      "--marker=✓"
      "--no-separator"
      "--pointer=•"
      "--prompt='  '"
    ];
    fileWidget.command = "fd --hidden --exclude .git .";
  };
  programs.zoxide.enable = true;
}
