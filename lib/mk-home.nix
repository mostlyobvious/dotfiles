{
  nixpkgs,
  home-manager,
  inputs,
  allowUnfreePred,
}:

# Standalone home-manager. `modules` is one account's (or VM guest's) flat
# module list — everything it gets, including its own identity module.
{
  user,
  system,
  modules,
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
  ++ modules;
}
