{ lib, pkgs, ... }:

let
  masApps = {
    "iA Writer" = 775737590;
    "Photomator" = 1444636541;
    "Amphetamine" = 937984704;
    "ActionBar" = 6758538752;
  };

  masListFallbacks = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: id: ''
      if [ -e ${lib.escapeShellArg "/Applications/${name}.app/Contents/_MASReceipt/receipt"} ] \
        && ! /usr/bin/grep -q '^${toString id}[[:space:]]' "$real_list"; then
        printf '%s  %s  (0)\n' ${lib.escapeShellArg (toString id)} ${lib.escapeShellArg name}
      fi
    '') masApps
  );

  masWithReceiptFallback = pkgs.writeShellScriptBin "mas" ''
    real_mas=/opt/homebrew/bin/mas
    if [ ! -x "$real_mas" ]; then
      real_mas=${pkgs.mas}/bin/mas
    fi

    if [ "$1" = list ]; then
      real_list="$(${pkgs.coreutils}/bin/mktemp)"
      trap '${pkgs.coreutils}/bin/rm -f "$real_list"' EXIT
      "$real_mas" list >"$real_list" 2>/dev/null || true
      ${pkgs.coreutils}/bin/cat "$real_list"
      ${masListFallbacks}
      exit 0
    fi

    exec "$real_mas" "$@"
  '';
in
{
  # nix-darwin does not install Homebrew itself; it must already exist (see bootstrap).
  homebrew = {
    enable = true;

    onActivation = {
      # zap uninstalls anything not declared below, along with its data. Keep the lists complete.
      cleanup = "zap";
      autoUpdate = false;
      upgrade = false;

      # Homebrew Bundle detects MAS installs via `mas list`, which in turn
      # depends on Spotlight metadata. Our battery policy can disable Spotlight,
      # so wrap only Homebrew activation's `mas list` with a receipt-based
      # fallback. Missing apps still fall through to real `mas install`.
      extraEnv.PATH =
        lib.makeBinPath [ masWithReceiptFallback ]
        + ":/opt/homebrew/bin:${
          lib.makeBinPath [
            pkgs.mas
            pkgs.coreutils
          ]
        }:/usr/bin:/bin:/usr/sbin:/sbin";
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
      "deckset"
      "claude"
      "codex"
      "insta360-studio"
      "ia-presenter"
      "whatsapp"
    ];

    # App Store apps (no cask). Requires being signed into the App Store; mas can
    # reinstall apps tied to the Apple ID but can no longer sign in or purchase.
    inherit masApps;
  };
}
