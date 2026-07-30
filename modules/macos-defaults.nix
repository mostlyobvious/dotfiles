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
      autohide = true;
      autohide-delay = 2.0;
      mineffect = "scale";
      show-recents = false;
      launchanim = false;
      expose-animation-duration = 0.0;
      autohide-time-modifier = 0.0;
      tilesize = 64;
    };

    "com.apple.finder" = {
      _FXSortFoldersFirst = true;
      FXEnableExtensionChangeWarning = false;
      ShowExternalHardDrivesOnDesktop = false;
      ShowRemovableMediaOnDesktop = false;
    };

    NSGlobalDomain = {
      ApplePressAndHoldEnabled = false;
      KeyRepeat = 2;
      InitialKeyRepeat = 15;
      NSAutomaticWindowAnimationsEnabled = false;
      NSWindowResizeTime = 0.001;
      NSConvolutionOverride1 = 10; # window corner radius; Tahoe default 16, Sequoia ~10
    };

    "com.apple.screencapture" = {
      type = "png";
      location = shotsDir;
    };
  };

  # targets.darwin.defaults writes prefs but does not reload readers.
  home.activation.restartPreferenceDaemon = lib.hm.dag.entryAfter [ "setDarwinDefaults" ] ''
    /usr/bin/killall cfprefsd 2>/dev/null || true
  '';

  home.activation.applyKeyboardSettings = lib.hm.dag.entryAfter [ "setDarwinDefaults" ] ''
    /usr/bin/hidutil property --set '{"HIDKeyRepeat":33333333,"HIDInitialKeyRepeat":250000000,"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":30064771300,"HIDKeyboardModifierMappingDst":30064771302}]}' >/dev/null
  '';

  home.activation.restartDock = lib.hm.dag.entryAfter [ "setDarwinDefaults" ] ''
    /usr/bin/killall Dock 2>/dev/null || true
  '';

  # Finder must relaunch to pick up its prefs.
  home.activation.restartFinder = lib.hm.dag.entryAfter [ "setDarwinDefaults" ] ''
    /usr/bin/killall Finder 2>/dev/null || true
  '';

  # screencapture silently falls back to the Desktop if the target is missing.
  home.activation.createShotsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    /bin/mkdir -p "${shotsDir}"
  '';
}
