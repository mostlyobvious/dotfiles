{ pkgs, ... }:

{
  home.packages = [ pkgs.eza ];

  # ls/tree → eza; colours come from config/eza/theme.yml (Rose Pine).
  programs.fish.shellAliases = {
    ls = "eza";
    tree = "eza --tree";
  };

  xdg.configFile."eza/theme.yml".source = ../../config/eza/theme.yml;
}
