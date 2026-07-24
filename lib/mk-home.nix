{
  nixpkgs,
  home-manager,
  inputs,
  lib,
  allowUnfreePred,
}:

# Standalone home-manager. Pass the darwin home layer via homeModules.
{
  user,
  system ? "aarch64-linux",
  homeModules ? [
    ../modules/core.nix
    ../modules/cli.nix
    ../modules/git.nix
    ../modules/fish.nix
    ../modules/neovim.nix
    ../modules/ruby.nix
    ../modules/claude.nix
    ../modules/pi.nix
    ../modules/eza.nix
    ../modules/skills.nix
  ],
  dotfilesDir ? null,
  homeDirectory ? null,
  signingKey ? null,
  email ? null,
  extraModules ? [ ],
}:
home-manager.lib.homeManagerConfiguration {
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfreePredicate = allowUnfreePred;
  };
  extraSpecialArgs = {
    username = user;
    inherit inputs;
  };
  modules = [
    inputs.agent-skills.homeManagerModules.default
  ]
  ++ homeModules
  ++ lib.optional (dotfilesDir != null) { my.dotfilesDir = dotfilesDir; }
  ++ lib.optional (signingKey != null) { my.signingKey = signingKey; }
  ++ lib.optional (email != null) { my.userEmail = email; }
  ++ lib.optional (homeDirectory != null) {
    home.homeDirectory = homeDirectory;
  }
  ++ extraModules;
}
