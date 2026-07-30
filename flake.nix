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
    # `nix flake update skills-*` to bump. Consumed by modules/skills.nix.
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

    glab-tui = {
      url = "github:rcieri/glab-tui";
      flake = false;
    };

    # Private repo carrying purchased, non-redistributable font zips. Fetched
    # over SSH so no token is stored; pinned in flake.lock. Consumed by
    # modules/fonts.nix.
    fonts = {
      url = "git+ssh://git@github.com/mostlyobvious/fonts.git";
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
      lib = nixpkgs.lib;

      nixSource = lib.fileset.toSource {
        root = ./.;
        fileset = lib.fileset.fileFilter (file: file.hasExt "nix") ./.;
      };

      # Narrow unfree allowance — only the packages we knowingly accept, not a
      # blanket allowUnfree. Set at pkgs instantiation: both useGlobalPkgs (host)
      # and the VM's directly-passed pkgs bypass home-manager's nixpkgs.config.
      allowUnfreePred =
        pkg:
        builtins.elem (nixpkgs.lib.getName pkg) [
          "claude-code"
          "berkeley-mono"
          "pragmatapro"
          "vault"
        ];

      forAllSystems = lib.genAttrs [
        "aarch64-darwin"
        "aarch64-linux"
      ];

      # The host is the root of the tree: one file per machine, its whole
      # system + every account + every VM.
      hosts = {
        pro = import ./hosts/pro.nix;
        cm = import ./hosts/cm.nix;
      };

      mkHome = import ./lib/mk-home.nix {
        inherit
          nixpkgs
          home-manager
          inputs
          allowUnfreePred
          ;
      };

      mkDarwin = import ./lib/mk-darwin.nix {
        inherit
          nix-darwin
          determinate
          allowUnfreePred
          lib
          ;
      };

      mkApps = import ./lib/apps.nix {
        inherit
          nixpkgs
          nix-darwin
          lib
          self
          ;
      };

      # homeConfigurations."<host>-<user>" for every account on every host.
      hostUserHomeConfigs = lib.concatMapAttrs (
        hostName: host:
        lib.mapAttrs' (
          userName: user:
          lib.nameValuePair "${hostName}-${userName}" (mkHome {
            user = userName;
            system = host.arch;
            modules = user.modules;
          })
        ) host.users
      ) hosts;

      # homeConfigurations.<vm> for every VM's single-user guest.
      vmHomeConfigs = lib.concatMapAttrs (
        _hostName: host:
        lib.mapAttrs (
          _vmName: vm:
          mkHome {
            user = vm.user;
            system = vm.arch;
            modules = vm.home;
          }
        ) (host.vms or { })
      ) hosts;

      # nixosConfigurations.<vm> for every VM's system.
      vmNixosConfigs = lib.concatMapAttrs (
        _hostName: host:
        lib.mapAttrs (
          _vmName: vm:
          lib.nixosSystem {
            system = vm.arch;
            specialArgs = {
              username = vm.user;
            };
            modules = [
              { nixpkgs.config.allowUnfreePredicate = allowUnfreePred; }
              vm.system
            ];
          }
        ) (host.vms or { })
      ) hosts;

      # checks.aarch64-darwin: every host's system + every account's home.
      darwinChecks = lib.concatMapAttrs (
        hostName: host:
        {
          "darwin-${hostName}" = self.darwinConfigurations.${hostName}.system;
        }
        // lib.mapAttrs' (
          userName: _:
          lib.nameValuePair "home-${hostName}-${userName}"
            self.homeConfigurations."${hostName}-${userName}".activationPackage
        ) host.users
      ) hosts;

      # checks.aarch64-linux: every VM's system + guest home.
      linuxChecks = lib.concatMapAttrs (
        _hostName: host:
        lib.concatMapAttrs (vmName: _vm: {
          "nixos-${vmName}" = self.nixosConfigurations.${vmName}.config.system.build.toplevel;
          "home-${vmName}" = self.homeConfigurations.${vmName}.activationPackage;
        }) (host.vms or { })
      ) hosts;
    in
    {
      darwinConfigurations = lib.mapAttrs mkDarwin hosts;

      homeConfigurations = hostUserHomeConfigs // vmHomeConfigs;

      nixosConfigurations = vmNixosConfigs;

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
        // lib.optionalAttrs (system == "aarch64-darwin") darwinChecks
        // lib.optionalAttrs (system == "aarch64-linux") linuxChecks
      );

      apps = forAllSystems (system: lib.optionalAttrs (system == "aarch64-darwin") (mkApps hosts system));

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
