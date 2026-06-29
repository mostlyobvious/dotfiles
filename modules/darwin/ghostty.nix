{ config, ... }:

{
  # macOS Ghostty loads ~/Library/Application Support last, so it overrides the
  # XDG path — manage it directly. Out-of-store: edits are live (reload in app,
  # no rebuild). Host-only; Ghostty is a macOS cask, absent on the VM.
  home.file."Library/Application Support/com.mitchellh.ghostty/config".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesDir}/config/ghostty/config";
}
