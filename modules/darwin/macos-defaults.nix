{ config, lib, ... }:

let
  # Final path component is a literal single space: a near-invisible "Desktop/ " dir.
  shotsDir = "${config.home.homeDirectory}/Desktop/ ";
in
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
      NSConvolutionOverride1 = 10; # window corner radius; Tahoe default 16, Sequoia ~10
    };

    "com.apple.screencapture" = {
      type = "png";
      location = shotsDir;
    };
  };

  # targets.darwin.defaults writes prefs but does not reload the Dock.
  home.activation.restartDock = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    /usr/bin/killall Dock 2>/dev/null || true
  '';

  # screencapture silently falls back to the Desktop if the target is missing.
  home.activation.createShotsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    /bin/mkdir -p "${shotsDir}"
  '';
}
