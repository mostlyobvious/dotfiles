{ ... }:

{
  # nix-darwin does not install Homebrew itself; it must already exist (see bootstrap).
  homebrew = {
    enable = true;

    onActivation = {
      # zap uninstalls anything not declared below, along with its data. Keep the lists complete.
      cleanup = "zap";
      autoUpdate = false;
      upgrade = false;
    };

    # Declared so zap keeps it (codexbar's tap).
    taps = [
      "steipete/tap"
    ];

    # CLI tooling is in Nix; only host-only tools remain here.
    brews = [
      "rtl_433"
      "lima"
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
      "autodesk-fusion"
      "blender"
      "brave-browser"
      "codexbar"
      "slack"
      "signal"
      "affinity"
      "adguard"
      "deckset"
      "claude"
      "codex"
      "insta360-studio"
      "ia-presenter"
    ];

    # App Store apps (no cask). Requires being signed into the App Store; mas can
    # reinstall apps tied to the Apple ID but can no longer sign in or purchase.
    masApps = {
      "iA Writer" = 775737590;
      "Photomator" = 1444636541;
      "Amphetamine" = 937984704;
      "ActionBar" = 6758538752;
    };
  };
}
