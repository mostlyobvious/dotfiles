{ pkgs, ... }:

{
  home.packages = with pkgs; [
    secretspec
    devenv
    glab
  ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.fd.enable = true;
  programs.gh.enable = true;
  programs.jq.enable = true;
  programs.ripgrep.enable = true;

  programs.fzf.enable = true;
  programs.zoxide.enable = true;
}
