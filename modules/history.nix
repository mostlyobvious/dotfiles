{ config, username, ... }:

let
  icloud = "/Users/${username}/Library/Mobile Documents/com~apple~CloudDocs";
in
{
  # Shell/REPL history synced through iCloud. Primary-account-only: only that
  # user is signed into iCloud, so this is imported per-user in flake.nix rather
  # than the shared darwin home layer (cm has no iCloud) or common.nix (VMs).
  home.file.".local/share/fish/fish_history".source =
    config.lib.file.mkOutOfStoreSymlink "${icloud}/fish_history";
  home.file.".irb_history".source = config.lib.file.mkOutOfStoreSymlink "${icloud}/.irb_history";
}
