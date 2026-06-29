{ ... }:

{
  # Host-only by design: no credentials/identity in the shared layer, so the VM
  # uses its own keys. Public-safe hosts live here as settings blocks; private
  # hosts (real IPs, internal users) go in ~/.ssh/config.local, pulled in via
  # Include below. That file is outside the repo and never committed.
  programs.ssh = {
    enable = true;

    # home-manager's implicit Host * defaults are deprecated and will be removed,
    # so opt out and pin the ones worth keeping explicitly below.
    enableDefaultConfig = false;

    includes = [ "config.local" ];

    settings = {
      "*" = {
        AddKeysToAgent = "yes";
        ForwardAgent = true;
        ServerAliveInterval = 60;
        ServerAliveCountMax = 3;
        ControlMaster = "auto";
        ControlPath = "/tmp/ssh-%r@%h:%p";
        ControlPersist = "600";
        UseKeychain = "yes";
        Compression = "no";
        HashKnownHosts = "no";
        UserKnownHostsFile = "~/.ssh/known_hosts";
      };
    };
  };
}
