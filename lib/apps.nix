{
  nixpkgs,
  nix-darwin,
  lib,
  self,
}:

# Two commands, total: `bootstrap <host>` on a fresh machine, `switch`
# forever after. Both run the same per-host sequence — system, then every
# account's home, then every VM — derived from the host tree so a new
# account or VM needs no new app.
hosts: system:
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
        ];
      }
    }/bin/${name}";
  };

  darwinRebuild = "${nix-darwin.packages.${system}.darwin-rebuild}/bin/darwin-rebuild";

  # Every account: build its home, then activate directly if we're the
  # invoking user, else via sudo -u. Not gated on admin-ness — any admin can
  # run switch, and only sudo (step 1 above) requires one.
  accountScript = hostName: accountName: ''
    nix build ${self}#homeConfigurations."${hostName}-${accountName}".activationPackage
    if [ "$WHOAMI" = "${accountName}" ]; then
      ./result/activate
    else
      HOME_MANAGER_BACKUP_EXT=hm-bak sudo -u ${accountName} -H ./result/activate
    fi
  '';

  # Every VM: start it, then rebuild its system and its guest home straight
  # from the read-only dotfiles mount (no rsync staging).
  vmScript = vmName: ''
    STATUS="$(limactl list --format '{{.Name}}	{{.Status}}' | awk -v vm="${vmName}" '$1 == vm { print $2 }')"
    if [ -z "$STATUS" ]; then
      limactl start --name="${vmName}" "${self + "/vms/${vmName}/lima.yaml"}"
    elif [ "$STATUS" != "Running" ]; then
      limactl start "${vmName}"
    fi

    limactl shell "${vmName}" -- sudo nixos-rebuild switch --flake /mnt/dotfiles#${vmName}

    # single-quoted on purpose: $RESULT and the $(...) run in the guest, not here
    # shellcheck disable=SC2016
    limactl shell "${vmName}" -- bash -c '
      set -euo pipefail
      RESULT="$(nix build /mnt/dotfiles#homeConfigurations.${vmName}.activationPackage --no-link --print-out-paths)"
      HOME_MANAGER_BACKUP_EXT=hm-bak "$RESULT/activate"
    '
  '';

  hostScript = hostName: host: ''
    sudo -H ${darwinRebuild} switch --flake ${self}#${hostName}

    WHOAMI="$(whoami)"

    ${lib.concatStrings (map (accountScript hostName) (builtins.attrNames host.users))}
    ${lib.concatStrings (map vmScript (builtins.attrNames (host.vms or { })))}
  '';

  # One case branch per known host; the caller decides how $HOST gets set.
  hostCases = lib.concatStrings (
    lib.mapAttrsToList (hostName: host: ''
      ${hostName})
      ${hostScript hostName host}
        ;;
    '') hosts
  );
in
{
  bootstrap = mkApp "dotfiles-bootstrap" ''
    HOST="''${1:?usage: bootstrap <host>}"

    if ! test -x /opt/homebrew/bin/brew; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    case "$HOST" in
      ${hostCases}
      *)
        echo "Unknown host: $HOST" >&2
        exit 1
        ;;
    esac
  '';

  switch = mkApp "dotfiles-switch" ''
    HOST="$(scutil --get LocalHostName)"

    case "$HOST" in
      ${hostCases}
      *)
        echo "Unknown host: $HOST" >&2
        exit 1
        ;;
    esac
  '';
}
