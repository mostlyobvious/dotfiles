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
      username = "mostlyobvious";
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

      mkHome = import ./lib/mk-home.nix {
        inherit
          nixpkgs
          home-manager
          inputs
          lib
          allowUnfreePred
          ;
      };

      mkDarwin = import ./lib/mk-darwin.nix {
        inherit
          home-manager
          nix-darwin
          determinate
          inputs
          username
          allowUnfreePred
          ;
      };

      darwinApps = import ./lib/apps.nix { inherit nixpkgs nix-darwin self; };
    in
    {
      darwinConfigurations.pro = mkDarwin {
        hostname = "pro";
        nonAdminAccounts = [ "cm" ];
        adminKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFai8QY2psbXCIconVn7fLRxtWmIpsasY03qgBVA8NdS mostlyobvious@pro"
        ];
      };

      nixosConfigurations.nixden = lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = { inherit username inputs; };
        modules = [
          home-manager.nixosModules.home-manager
          { nixpkgs.config.allowUnfreePredicate = allowUnfreePred; }
          ./vms/nixden/configuration.nix
        ];
      };

      # Linux VMs. Portable subset only — no darwin, no brew.
      homeConfigurations.${username} = mkHome { user = username; };
      homeConfigurations.nixden = mkHome {
        user = username;
        dotfilesDir = "/tmp/lima-nixden/dotfiles";
        homeDirectory = "/home/mostlyobvious.guest";
        extraModules = [
          {
            programs.zed-editor = {
              enable = true;
              installRemoteServer = true;
            };
          }
        ];
      };

      # Sudo-less second account. Standalone home-manager, shared darwin layer.
      homeConfigurations.cm = mkHome {
        user = "cm";
        system = "aarch64-darwin";
        dotfilesDir = "/Users/cm/dotfiles";
        signingKey = "/Users/cm/.ssh/id_ed25519.pub";
        email = "pawel.pacana@chattermill.io";
        homeModules = [
          ./modules/core.nix
          ./modules/cli.nix
          ./modules/git.nix
          ./modules/fish.nix
          ./modules/neovim.nix
          ./modules/ruby.nix
          ./modules/claude.nix
          ./modules/pi.nix
          ./modules/eza.nix
          ./modules/skills.nix
          ./modules/ssh.nix
          ./modules/ghostty.nix
          ./modules/zed.nix
          ./modules/logseq.nix
          ./modules/fonts.nix
          ./modules/macos-defaults.nix
          ./modules/kubernetes.nix
          ./modules/vault.nix
          ./modules/redocly.nix
        ];
        extraModules = [
          { my.logseqGraphs = [ "Documents/CM" ]; }
        ];
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

      apps = forAllSystems (system: lib.optionalAttrs (system == "aarch64-darwin") (darwinApps system));

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
