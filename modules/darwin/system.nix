{
  config,
  pkgs,
  username,
  ...
}:

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

    # Kill UI animations for snappier window/dock interaction.
    NSGlobalDomain.NSAutomaticWindowAnimationsEnabled = false;
    NSGlobalDomain.NSWindowResizeTime = 0.001;
    dock.launchanim = false;
    dock.expose-animation-duration = 0.0;
    dock.autohide-time-modifier = 0.0;
  };

  # screencapture silently falls back to the Desktop if the target is missing.
  # Must hook a predefined phase: nix-darwin only runs those, not arbitrary keys.
  system.activationScripts.postActivation.text = ''
    /bin/mkdir -p "${shotsDir}"
  '';
}
