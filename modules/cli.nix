{ pkgs, ... }:

{
  home.packages = with pkgs; [
    secretspec
    devenv
    glab
  ];

  programs.direnv = {
    enable = true;
    config.global.hide_env_diff = true;
    nix-direnv.enable = true;
    silent = true;
  };

  programs.fd.enable = true;
  programs.gh.enable = true;
  programs.jq.enable = true;
  programs.ripgrep.enable = true;

  programs.fzf = {
    enable = true;
    colors = {
      bg = "#232136";
      "bg+" = "#2d2a45";
      fg = "#e0def4";
      "fg+" = "#eae8ff";
      gutter = "#232136";
      header = "#817c9c";
      hl = "#ea9a97";
      "hl+" = "#f6c177";
      info = "#9ccfd8";
      marker = "#a3be8c";
      pointer = "#eb6f92";
      prompt = "#c4a7e7";
      spinner = "#f6c177";
    };
    defaultCommand = "fd --hidden --exclude .git .";
    defaultOptions = [
      "--height=40%"
      "--info=hidden"
      "--layout=reverse"
      "--marker=✓"
      "--no-separator"
      "--pointer=›"
      "--prompt=› "
    ];
    fileWidget.command = "fd --hidden --exclude .git .";
  };
  programs.zoxide.enable = true;
}
