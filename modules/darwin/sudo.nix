{ username, ... }:

{
  security.sudo.extraConfig = ''
    Defaults:${username} timestamp_timeout=30
  '';
}
