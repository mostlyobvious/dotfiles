{ ... }:

{
  programs.eza.enable = true;

  # Preserve the long-form tree alias; Home Manager provides ls/ll/la/lt/lla.
  programs.fish.shellAliases.tree = "eza --tree";

  # Colours come from config/eza/theme.yml (Duskfox).
  xdg.configFile."eza/theme.yml".source = ../../config/eza/theme.yml;
}
