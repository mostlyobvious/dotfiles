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

  programs.fzf.enable = true;
  programs.zoxide.enable = true;
}
