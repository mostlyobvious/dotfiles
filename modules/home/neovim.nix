{ config, pkgs, ... }:

{
  # Binary only; plugins are managed by native vim.pack (config/nvim/nvim-pack-lock.json), not Nix.
  home.packages = [ pkgs.neovim ];

  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesDir}/config/nvim";
}
