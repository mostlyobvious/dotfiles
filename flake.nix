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

    # Declarative agent-skill management (discovery, prefixing, both-agent targets).
    agent-skills = {
      url = "github:Kyure-A/agent-skills-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Agent skill sources — content repos, not flakes. Pinned in flake.lock;
    # `nix flake update skills-*` to bump. Consumed by modules/home/skills.nix.
    skills-mattpocock = {
      url = "github:mattpocock/skills";
      flake = false;
    };
    skills-impeccable = {
      url = "github:pbakaus/impeccable";
      flake = false;
    };
    skills-mutant = {
      url = "github:mbj/mutant";
      flake = false;
    };
    skills-modularity = {
      url = "github:vladikk/modularity";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      nix-darwin,
      determinate,
      ...
    }:
    let
      username = "mostlyobvious";
      lib = nixpkgs.lib;

      nixSource = lib.fileset.toSource {
        root = ./.;
        fileset = lib.fileset.fileFilter (file: file.hasExt "nix") ./.;
      };

      # Narrow unfree allowance — only the packages we knowingly accept, not a
      # blanket allowUnfree. Set at pkgs instantiation: both useGlobalPkgs (host)
      # and the VM's directly-passed pkgs bypass home-manager's nixpkgs.config.
      allowUnfreePred = pkg: builtins.elem (nixpkgs.lib.getName pkg) [ "claude-code" ];

      forAllSystems = lib.genAttrs [
        "aarch64-darwin"
        "aarch64-linux"
      ];

      mkLinuxHome =
        {
          system ? "aarch64-linux",
          dotfilesDir ? null,
          homeDirectory ? null,
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfreePredicate = allowUnfreePred;
          };
          extraSpecialArgs = { inherit username inputs; };
          modules = [
            inputs.agent-skills.homeManagerModules.default
            ./modules/home/common.nix
          ]
          ++ lib.optional (dotfilesDir != null) { my.dotfilesDir = dotfilesDir; }
          ++ lib.optional (homeDirectory != null) {
            home.homeDirectory = homeDirectory;
          };
        };

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
              home-manager.extraSpecialArgs = { inherit username hostname inputs; };
              home-manager.users.${username}.imports = [
                inputs.agent-skills.homeManagerModules.default
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

      # Linux VMs. Portable subset only — no darwin, no brew.
      homeConfigurations.${username} = mkLinuxHome { };
      homeConfigurations.nixden = mkLinuxHome {
        dotfilesDir = "/tmp/lima-nixden/dotfiles";
        homeDirectory = "/home/mostlyobvious.guest";
      };

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          nixfmt = pkgs.runCommand "nixfmt-check" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
            find ${nixSource} -name '*.nix' -print0 | xargs -0 nixfmt --check
            touch $out
          '';

          deadnix = pkgs.runCommand "deadnix-check" { nativeBuildInputs = [ pkgs.deadnix ]; } ''
            deadnix --fail ${nixSource}
            touch $out
          '';
        }
        // lib.optionalAttrs (system == "aarch64-darwin") {
          darwin-pro = self.darwinConfigurations.pro.system;
        }
      );

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
