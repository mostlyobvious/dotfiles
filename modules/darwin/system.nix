{ config, pkgs, username, ... }:

let
  home = config.users.users.${username}.home;
  # Final path component is a literal single space: a near-invisible "Desktop/ " dir.
  shotsDir = "${home}/Desktop/ ";
in
{
  # Register fish in /etc/shells so it's a valid login shell.
  environment.shells = [ pkgs.fish ];
  programs.fish.enable = true;

  system.defaults = {
    dock.mineffect = "scale";
    dock.show-recents = false;
    screencapture.type = "png";
    screencapture.location = shotsDir;
  };

  # screencapture silently falls back to the Desktop if the target is missing.
  system.activationScripts.screenshotsDir.text = ''
    /bin/mkdir -p "${shotsDir}"
  '';
}
