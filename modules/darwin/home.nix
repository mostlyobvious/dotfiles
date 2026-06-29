{ config, username, ... }:

let
  icloud = "/Users/${username}/Library/Mobile Documents/com~apple~CloudDocs";
in
{
  # iCloud history sync. Host-only — VMs have no iCloud, so this stays out of common.nix.
  home.file.".local/share/fish/fish_history".source =
    config.lib.file.mkOutOfStoreSymlink "${icloud}/fish_history";
  home.file.".irb_history".source =
    config.lib.file.mkOutOfStoreSymlink "${icloud}/.irb_history";

  # Host-only by design: no credentials/identity in the shared layer, so the VM uses its own keys.
  home.file.".ssh/config".source = ../../config/ssh/config;
  home.file.".ideavimrc".source = ../../config/jetbrains/ideavimrc;
  home.file.".hushlogin".source = ../../config/hushlogin;
}
