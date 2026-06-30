{ ... }:

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
}
