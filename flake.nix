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
    {
      self,
      nixpkgs,
      home-manager,
      nix-darwin,
      determinate,
      ...
    }:
    let
      username = "mostlyobvious";

      # Narrow unfree allowance — only the packages we knowingly accept, not a
      # blanket allowUnfree. Set at pkgs instantiation: both useGlobalPkgs (host)
      # and the VM's directly-passed pkgs bypass home-manager's nixpkgs.config.
      allowUnfreePred = pkg: builtins.elem (nixpkgs.lib.getName pkg) [ "claude-code" ];

      forAllSystems = nixpkgs.lib.genAttrs [
        "aarch64-darwin"
        "aarch64-linux"
      ];

      # Per-host config (extra casks, host-only modules) goes in extraModules.
      mkDarwin =
        {
          hostname,
          system ? "aarch64-darwin",
          extraModules ? [ ],
        }:
        nix-darwin.lib.darwinSystem {
          inherit system;
          specialArgs = { inherit username hostname; };
          modules = [
            determinate.darwinModules.default
            ./modules/darwin
            home-manager.darwinModules.home-manager
            { nixpkgs.config.allowUnfreePredicate = allowUnfreePred; }
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              # Back up colliding files instead of aborting the switch.
              home-manager.backupFileExtension = "hm-bak";
              home-manager.extraSpecialArgs = { inherit username hostname; };
              home-manager.users.${username}.imports = [
                ./modules/home/common.nix
                ./modules/darwin/home.nix
              ];
            }
          ]
          ++ extraModules;
        };
    in
    {
      darwinConfigurations.pro = mkDarwin { hostname = "pro"; };

      # VM. Portable subset only — no darwin, no brew.
      homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "aarch64-linux";
          config.allowUnfreePredicate = allowUnfreePred;
        };
        extraSpecialArgs = { inherit username; };
        modules = [ ./modules/home/common.nix ];
      };

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);

      # Loaded on cd via .envrc + nix-direnv.
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              nixd
              nixfmt
              deadnix
            ];
          };
        }
      );
    };
}
