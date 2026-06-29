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
    ];
  };
}
