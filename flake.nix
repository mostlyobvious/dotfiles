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
          extraModules ? [ ],
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
          }
          ++ extraModules;
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
            {
              disabledModules = [ "${nix-darwin}/modules/services/github-runner/service.nix" ];
              imports = [ ./modules/darwin/github-runner-determinate.nix ];
            }
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

      mkDarwinApp =
        system: name: text:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          type = "app";
          program = "${
            pkgs.writeShellApplication {
              inherit name text;
              runtimeInputs = with pkgs; [
                curl
                lima
                rsync
              ];
            }
          }/bin/${name}";
        };

      darwinApps =
        system:
        let
          darwinRebuild = "${nix-darwin.packages.${system}.darwin-rebuild}/bin/darwin-rebuild";
          mkApp = mkDarwinApp system;
          vmSwitchScript = ''
            VMS="''${VMS:-nixden}"

            for VM in $VMS; do
              case "$VM" in
                nixden)
                  NIXOSCFG="nixden"
                  TEMPLATE="${./vms/nixden/lima.yaml}"
                  VM_WORKDIR="/tmp/lima-nixden/dotfiles"
                  ;;
                *)
                  echo "Unknown VM: $VM" >&2
                  exit 1
                  ;;
              esac

              mkdir -p "$(dirname "$VM_WORKDIR")"

              STATUS="$(limactl list --format '{{.Name}}	{{.Status}}' | awk -v vm="$VM" '$1 == vm { print $2 }')"
              if [ -z "$STATUS" ]; then
                limactl start --name="$VM" "$TEMPLATE"
              elif [ "$STATUS" != "Running" ]; then
                limactl start "$VM"
              fi

              rsync -a --delete \
                --exclude .git \
                --exclude .direnv \
                --exclude result \
                ./ "$VM_WORKDIR/"

              limactl shell --workdir="$VM_WORKDIR" "$VM" -- \
                sudo nixos-rebuild switch --flake ".#$NIXOSCFG"
            done
          '';
        in
        {
          bootstrap = mkApp "dotfiles-bootstrap" ''
            HOST="''${HOST:-pro}"

            if ! test -x /opt/homebrew/bin/brew; then
              /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi

            sudo -H ${darwinRebuild} switch --flake ${self}#"$HOST"
          '';

          home = mkApp "dotfiles-home" ''
            VM="''${VM:-nixden}"
            HMCFG="''${HMCFG:-nixden}"
            VM_WORKDIR="/tmp/lima-$VM/dotfiles"

            rsync -a --delete \
              --exclude .git \
              --exclude .direnv \
              --exclude result \
              ./ "/tmp/lima-$VM/dotfiles/"

            limactl shell --workdir="$VM_WORKDIR" "$VM" -- \
              bash -lc "nix build .#homeConfigurations.$HMCFG.activationPackage && ./result/activate"
          '';

          vm-switch = mkApp "dotfiles-vm-switch" vmSwitchScript;

          switch = mkApp "dotfiles-switch" ''
            HOST="''${HOST:-pro}"
            sudo -H ${darwinRebuild} switch --flake ${self}#"$HOST"

            ${vmSwitchScript}
          '';

          update = mkApp "dotfiles-update" ''
            nix flake update
            nix run .#switch
          '';
        };
    in
    {
      darwinConfigurations.pro = mkDarwin { hostname = "pro"; };

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
      homeConfigurations.${username} = mkLinuxHome { };
      homeConfigurations.nixden = mkLinuxHome {
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
