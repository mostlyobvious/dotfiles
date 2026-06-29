{ config, username, ... }:

let
  icloud = "/Users/${username}/Library/Mobile Documents/com~apple~CloudDocs";
in
{
  # Shell/REPL history synced through iCloud. Host-only — VMs have no iCloud,
  # so this stays out of common.nix.
  home.file.".local/share/fish/fish_history".source =
    config.lib.file.mkOutOfStoreSymlink "${icloud}/fish_history";
  home.file.".irb_history".source = config.lib.file.mkOutOfStoreSymlink "${icloud}/.irb_history";
}
