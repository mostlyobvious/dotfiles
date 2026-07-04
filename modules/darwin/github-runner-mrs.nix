# Runs the mostlyobvious/mrs self-hosted runner inside mostlyobvious's GUI
# (Aqua) launchd session as a home-manager LaunchAgent, instead of as the
# system LaunchDaemon that github-nix-ci creates.
#
# Why: the ociman Apple integration job drives Apple `container`, which talks
# to a per-user apiserver over XPC registered in the `gui/<uid>` domain. A
# system LaunchDaemon has no GUI session, so that XPC lookup is invalid and
# `container` fails. Running the listener as a LaunchAgent in mostlyobvious's
# Aqua session — where `container system start` is already registered — fixes
# it. `LimitLoadToSessionType = "Aqua"` guarantees it only loads there.
#
# This is a home-manager module; import it from modules/darwin/home.nix.
#
# Before your next `darwin-rebuild switch`, provision the runner token in the
# login Keychain through SecretSpec:
#   secretspec --file secretspec.toml set --provider keyring GITHUB_RUNNER_MRS_TOKEN
#
# The value may be either a GitHub runner registration token or a PAT.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  runner = pkgs.github-runner;
  url = "https://github.com/mostlyobvious/mrs";
  runnerName = "pro-mostlyobvious-mrs-01";
  labels = "aarch64-darwin";
  root = "${config.home.homeDirectory}/.local/share/github-runner-mrs";
  workDir = "${root}/_work";
  secretSpec = ../../secretspec.toml;
  secretspec = lib.getExe pkgs.secretspec;
  binPath = lib.makeBinPath (
    with pkgs;
    [
      bash
      coreutils
      git
      gnutar
      gzip
      nix
    ]
  );
  runScript = pkgs.writeShellApplication {
    name = "github-runner-mrs-run";
    text = ''
      export PATH="${binPath}:/usr/bin:/bin:/usr/sbin:/sbin"
      export RUNNER_ROOT="${root}"
      mkdir -p "${root}" "${workDir}"

      # Start each run from a clean work tree.
      find "${workDir}" -mindepth 1 -delete || true

      if [ ! -f "${root}/.runner" ]; then
        token="$(${secretspec} --file ${secretSpec} get --provider keyring GITHUB_RUNNER_MRS_TOKEN)"
        args=(
          --unattended --disableupdate --replace
          --url "${url}" --work "${workDir}"
          --labels "${labels}" --name "${runnerName}"
        )
        case "$token" in
          ghp_* | github_pat_*) args+=(--pat "$token") ;;
          *) args+=(--token "$token") ;;
        esac
        "${runner}/bin/config.sh" "''${args[@]}"
      fi

      exec "${runner}/bin/Runner.Listener" run --startuptype service
    '';
  };
in
{
  launchd.agents.github-runner-mrs = {
    enable = true;
    config = {
      ProgramArguments = [ (lib.getExe runScript) ];
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Interactive";
      LimitLoadToSessionType = "Aqua";
      StandardOutPath = "${root}/launchd-stdout.log";
      StandardErrorPath = "${root}/launchd-stderr.log";
    };
  };
}
