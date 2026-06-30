{ config, lib, ... }:

let
  masAppIndexing = lib.concatMapStringsSep "\n" (name: ''
    if [ -d ${lib.escapeShellArg "/Applications/${name}.app"} ]; then
      /usr/bin/mdimport ${lib.escapeShellArg "/Applications/${name}.app"} >/dev/null 2>&1 || true
    fi
  '') (lib.attrNames config.homebrew.masApps);
in
{
  # macOS exposes no "index only on AC" setting, and mdutil needs root, so a
  # launchd daemon polls the power source and flips Spotlight indexing to match.
  # launchd has no power-change event for third parties, hence the interval poll.
  # mdutil -i on/off is idempotent, so re-asserting the same state each tick is cheap.
  launchd.daemons.spotlight-on-ac = {
    script = ''
      if /usr/bin/pmset -g batt | /usr/bin/grep -q "Battery Power"; then
        /usr/bin/mdutil -i off -a >/dev/null 2>&1
      else
        /usr/bin/mdutil -i on -a >/dev/null 2>&1
      fi
    '';
    serviceConfig = {
      RunAtLoad = true;
      StartInterval = 60;
    };
  };

  # `make switch` re-enables indexing immediately before Homebrew runs so mas can
  # see installed App Store apps and not reinstall them. The daemon resumes its
  # battery-aware policy next tick.
  system.activationScripts.homebrew.text = lib.mkBefore ''
    /usr/bin/mdutil -i on -a >/dev/null 2>&1 || true
    ${masAppIndexing}
  '';
}
