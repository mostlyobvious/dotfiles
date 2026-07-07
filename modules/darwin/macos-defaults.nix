{ lib, ... }:

{
  # User-level macOS prefs. Kept in the home layer (not nix-darwin's
  # system.defaults) so the sudo-less cm account gets them via home-manager;
  # system.defaults only ever reach system.primaryUser.
  targets.darwin.defaults = {
    "com.apple.dock" = {
      mineffect = "scale";
      show-recents = false;
      launchanim = false;
      expose-animation-duration = 0.0;
      autohide-time-modifier = 0.0;
    };

    NSGlobalDomain = {
      NSAutomaticWindowAnimationsEnabled = false;
      NSWindowResizeTime = 0.001;
    };
  };

  # targets.darwin.defaults writes prefs but does not reload the Dock.
  home.activation.restartDock = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    /usr/bin/killall Dock 2>/dev/null || true
  '';
}
