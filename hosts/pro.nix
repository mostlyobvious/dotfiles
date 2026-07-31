{
  arch = "aarch64-darwin";

  system = {
    imports = [
      ../modules/darwin-core.nix
      ../modules/system.nix
      ../modules/sudo.nix
      ../modules/homebrew.nix
      ../modules/account.nix
    ];
  };

  # Homebrew installs are machine-wide, so casks/MAS apps are a host concern.
  homebrew = {
    brews = [
      "container"
      "jnsahaj/lumen/lumen"
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
      "google-chrome"
      "slack"
      "signal"
      "affinity"
      "deckset"
      "claude"
      "insta360-studio"
      "ia-presenter"
      "whatsapp"
      "1password"
      "1password-cli"
    ];
    masApps = {
      "iA Writer" = 775737590;
      "Photomator" = 1444636541;
      "Amphetamine" = 937984704;
      "ActionBar" = 6758538752;
      "AdGuard: Ad Blocker for Safari" = 1440147259;
    };
  };

  # the invoking admin activates directly, every other account via sudo -u
  users = {
    mostlyobvious = {
      admin = true;
      modules = [
        ../modules/core.nix
        ../modules/cli.nix
        ../modules/git.nix
        ../modules/fish.nix
        ../modules/neovim.nix
        ../modules/ruby.nix
        ../modules/claude.nix
        ../modules/pi.nix
        ../modules/eza.nix
        ../modules/skills.nix
        ../modules/ghostty.nix
        ../modules/zed.nix
        ../modules/ssh.nix
        ../modules/fonts.nix
        ../modules/macos-defaults.nix
        ../modules/history.nix # iCloud-backed; this account only
        ../modules/lima.nix
        {
          my.limaVms = [ "nixden" ]; # aliased in ssh config; declared in vms below
        }
      ];
    };
  };

  vms = {
    # nixden = import ../vms/nixden.nix;
  };
}
