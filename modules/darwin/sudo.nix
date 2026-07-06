{ username, ... }:

{
  security.sudo.extraConfig = ''
    Defaults:${username} timestamp_timeout=30
  '';

  # Touch ID for sudo, via /etc/pam.d/sudo_local so it survives OS updates.
  security.pam.services.sudo_local.touchIdAuth = true;
}
