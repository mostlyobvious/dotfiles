{ lib, ... }:

{
  home.activation.stopHomebrewContainerService = lib.hm.dag.entryBefore [ "setupLaunchAgents" ] ''
    if /bin/launchctl print "user/$UID/homebrew.mxcl.container" >/dev/null 2>&1; then
      run /bin/launchctl bootout "user/$UID/homebrew.mxcl.container"
    fi
    if /bin/launchctl print "gui/$UID/homebrew.mxcl.container" >/dev/null 2>&1; then
      run /bin/launchctl bootout "gui/$UID/homebrew.mxcl.container"
    fi
    run rm -f "$HOME/Library/LaunchAgents/homebrew.mxcl.container.plist"
  '';

  launchd.agents.container-system-start = {
    enable = true;
    domain = "user";
    config = {
      ProgramArguments = [
        "/opt/homebrew/bin/container"
        "system"
        "start"
      ];
      RunAtLoad = true;
      StandardOutPath = "/opt/homebrew/var/log/container.log";
      StandardErrorPath = "/opt/homebrew/var/log/container.log";
    };
  };
}
