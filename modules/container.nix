{
  launchd.agents.container-system-start = {
    enable = true;
    domain = "user";
    config = {
      ProgramArguments = [
        "/usr/local/bin/container"
        "system"
        "start"
      ];
      RunAtLoad = true;
      StandardOutPath = "/opt/homebrew/var/log/container.log";
      StandardErrorPath = "/opt/homebrew/var/log/container.log";
    };
  };
}
