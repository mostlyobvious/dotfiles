{ ... }:

let
  masApps = {
    "iA Writer" = 775737590;
    "Photomator" = 1444636541;
    "Amphetamine" = 937984704;
    "ActionBar" = 6758538752;
    "AdGuard: Ad Blocker for Safari" = 1440147259;
  };
in
{
  # nix-darwin does not install Homebrew itself; it must already exist (see bootstrap).
  homebrew = {
    enable = true;
    enableFishIntegration = true;

    global.autoUpdate = false;

    onActivation = {
      # zap uninstalls undeclared brews/casks, along with cask data. MAS apps
      # are a Homebrew Bundle limitation: removing them here will not uninstall them.
      cleanup = "zap";
      autoUpdate = false;
      upgrade = false;

    };

    # Declared so zap keeps it (codexbar's tap).
    taps = [
      {
        name = "steipete/tap";
        trusted = true;
      }
    ];

    # CLI tooling is in Nix; only host-only tools remain here.
    brews = [
      "container"
      "mas"
    ];

    casks = [
      "discord"
      "figma"
      "ghostty"
      "logseq"
      "onyx"
      "zed"
      "rubymine"
      "autodesk-fusion"
      "blender"
      "brave-browser"
      "google-chrome"
      "codexbar"
      "slack"
      "signal"
      "affinity"
      "deckset"
      "claude"
      "codex"
      "insta360-studio"
      "ia-presenter"
      "whatsapp"
      "notion"
      "1password"
      # Cask, not the Nix package: desktop-app integration needs 1Password's
      # officially signed CLI.
      "1password-cli"
    ];

    # App Store apps (no cask). Requires being signed into the App Store; mas can
    # reinstall apps tied to the Apple ID but can no longer sign in or purchase.
    inherit masApps;
  };
}
