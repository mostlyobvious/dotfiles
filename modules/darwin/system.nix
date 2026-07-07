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

  # Dock/window user prefs moved to the home layer (./macos-defaults.nix) so the
  # sudo-less cm account gets them too. Only truly system-scoped keys stay here.
  system.defaults = {
    screencapture.type = "png";
    screencapture.location = shotsDir;
  };

  # screencapture silently falls back to the Desktop if the target is missing.
  # Must hook a predefined phase: nix-darwin only runs those, not arbitrary keys.
  system.activationScripts.postActivation.text = ''
    /bin/mkdir -p "${shotsDir}"
  '';
}
