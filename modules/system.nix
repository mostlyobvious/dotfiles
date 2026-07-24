{
  pkgs,
  ...
}:

{
  # Register fish in /etc/shells so it's a valid login shell.
  environment.shells = [ pkgs.fish ];
  programs.fish.enable = true;
}
