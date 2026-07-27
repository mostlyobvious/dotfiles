{ config, username, ... }:

let
  icloud = "/Users/${username}/Library/Mobile Documents/com~apple~CloudDocs";
in
{
  # Shell/REPL history synced through iCloud. Only accounts signed into iCloud
  # can use this, so hosts/ imports it just for those (not cm, not VMs).
  home.file.".local/share/fish/fish_history".source =
    config.lib.file.mkOutOfStoreSymlink "${icloud}/fish_history";
  home.file.".irb_history".source = config.lib.file.mkOutOfStoreSymlink "${icloud}/.irb_history";
}
