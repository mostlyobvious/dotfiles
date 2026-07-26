{
  homebrewCasks ? [ ],
  homebrewMasApps ? { },
  ...
}:

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

    # CLI tooling is in Nix; only host-only tools remain here.
    brews = [
      "container"
      "mas"
    ];

    casks = homebrewCasks;

    # App Store apps (no cask). Requires being signed into the App Store; mas can
    # reinstall apps tied to the Apple ID but can no longer sign in or purchase.
    masApps = homebrewMasApps;
  };
}
