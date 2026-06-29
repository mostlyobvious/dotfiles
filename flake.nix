{
  description = "mostlyobvious dotfiles — home-manager + nix-darwin";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Determinate owns the Nix daemon and /etc/nix/nix.conf. nix-darwin runs with
    # nix.enable = false; this module wires in the Determinate integration.
    determinate.url = "github:DeterminateSystems/determinate";
  };

  outputs =
    { self
    , nixpkgs
    , home-manager
    , nix-darwin
    , determinate
    , ...
    }:
    let
      username = "mostlyobvious";
    in
    {
      darwinConfigurations.pro = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = { inherit username; };
        modules = [
          determinate.darwinModules.default
          ./modules/darwin
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # Back up colliding files instead of aborting the switch.
            home-manager.backupFileExtension = "hm-bak";
            home-manager.extraSpecialArgs = { inherit username; };
            home-manager.users.${username}.imports = [
              ./modules/home/common.nix
              ./modules/darwin/home.nix
              ./modules/darwin/ssh.nix
            ];
          }
        ];
      };

      # VM. Portable subset only — no darwin, no brew.
      homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.aarch64-linux;
        extraSpecialArgs = { inherit username; };
        modules = [ ./modules/home/common.nix ];
      };
    };
}
