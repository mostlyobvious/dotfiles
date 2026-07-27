{ pkgs, ... }:

{
  # Runs the VMs declared by the host file; their SSH aliases come from
  # my.limaVms (see ssh.nix).
  home.packages = [ pkgs.lima ];
}
