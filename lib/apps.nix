{
  nixpkgs,
  nix-darwin,
  self,
}:

system:
let
  pkgs = nixpkgs.legacyPackages.${system};

  mkApp = name: text: {
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

  darwinRebuild = "${nix-darwin.packages.${system}.darwin-rebuild}/bin/darwin-rebuild";

  vmSwitchScript = ''
    VMS="''${VMS:-nixden}"

    for VM in $VMS; do
      case "$VM" in
        nixden)
          NIXOSCFG="nixden"
          TEMPLATE="${../vms/nixden/lima.yaml}"
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

  # Activate the sudo-less cm account's home config on the local host:
  # `nix run .#cm-switch`.
  cm-switch = mkApp "dotfiles-cm-switch" ''
    nix build ${self}#homeConfigurations.cm.activationPackage
    # Back up colliding files instead of aborting, matching the host's
    # home-manager.backupFileExtension.
    HOME_MANAGER_BACKUP_EXT=hm-bak ./result/activate
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
}
