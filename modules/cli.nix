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
      "--height=40%"
      "--info=hidden"
      "--layout=reverse"
      "--marker=✓"
      "--no-separator"
      "--pointer=•"
      "--prompt= "
    ];
    fileWidget.command = "fd --hidden --exclude .git .";
  };
  programs.zoxide.enable = true;
}
