{
  lib,
  hostname,
  ...
}:

let
  excludedByHost = {
    cm = {
      masApps = [
        "iA Writer"
        "Photomator"
        "Amphetamine"
        "ActionBar"
        "AdGuard: Ad Blocker for Safari"
      ];
      casks = [
        "affinity"
        "autodesk-fusion"
        "blender"
        "brave-browser"
        "deckset"
        "discord"
        "figma"
        "ia-presenter"
        "insta360-studio"
        "onyx"
        "whatsapp"
      ];
    };
  };

  excluded = excludedByHost.${hostname} or { };
  excludedMasApps = excluded.masApps or [ ];
  excludedCasks = excluded.casks or [ ];

  masApps = lib.filterAttrs (name: _: !(builtins.elem name excludedMasApps)) {
    "iA Writer" = 775737590;
    "Photomator" = 1444636541;
    "Amphetamine" = 937984704;
    "ActionBar" = 6758538752;
    "AdGuard: Ad Blocker for Safari" = 1440147259;
  };

  casks = builtins.filter (cask: !(builtins.elem cask excludedCasks)) [
    "discord"
    "figma"
    "ghostty"
    "logseq"
    "onyx"
    "zed"
    "autodesk-fusion"
    "blender"
    "brave-browser"
    "google-chrome"
    "slack"
    "signal"
    "affinity"
    "deckset"
    "claude"
    "insta360-studio"
    "ia-presenter"
    "whatsapp"
    "notion"
    "1password"
    # Cask, not the Nix package: desktop-app integration needs 1Password's
    # officially signed CLI.
    "1password-cli"
  ];
in
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

    inherit casks;

    # App Store apps (no cask). Requires being signed into the App Store; mas can
    # reinstall apps tied to the Apple ID but can no longer sign in or purchase.
    inherit masApps;
  };
}
