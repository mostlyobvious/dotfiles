{ config, lib, ... }:

{
  # nix-darwin does not install Homebrew itself; it must already exist (see bootstrap).
  homebrew = {
    enable = true;
    enableFishIntegration = false; # inlined statically in modules/fish.nix

    global.autoUpdate = false;

    onActivation = {
      # zap uninstalls undeclared brews/casks, along with cask data. MAS apps
      # are a Homebrew Bundle limitation: removing them here will not uninstall them.
      cleanup = "zap";
      autoUpdate = false;
      upgrade = false;

    };

    # CLI tooling is in Nix; hosts declare casks, any brews, and App Store
    # apps. mas is the installer nix-darwin shells out to for masApps, which
    # requires being signed into the App Store; mas can reinstall apps tied
    # to the Apple ID but can no longer sign in or purchase.
    brews = lib.optional (config.homebrew.masApps != { }) "mas";
  };
}
