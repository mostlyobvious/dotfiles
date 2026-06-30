{ config, ... }:

{
  # Plugins are managed by native vim.pack (config/nvim/nvim-pack-lock.json), not Nix.
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    sideloadInitLua = true;
    withPython3 = false;
    withRuby = false;
  };

  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesDir}/config/nvim";
}
