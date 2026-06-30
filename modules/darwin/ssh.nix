{ lib, ... }:

let
  limaInstances = [ "nixden" ];
  limaHost = name: ''
    Host ${name}
      HostName 127.0.0.1
      Port 22
      User mostlyobvious
      IdentityFile ~/.lima/_config/user
      StrictHostKeyChecking no
      UserKnownHostsFile /dev/null
      NoHostAuthenticationForLocalhost yes
      PreferredAuthentications publickey
      IdentitiesOnly yes
      ProxyCommand ssh -F ~/.lima/${name}/ssh.config lima-${name} -W %h:%p
  '';
in
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

    includes = [
      "config.local"
      "config.d/lima"
    ];

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

  # Stable aliases for Lima VMs. The proxy reuses Lima's generated ssh.config,
  # so changing forwarded ports after a restart do not require regenerating this.
  home.file.".ssh/config.d/lima".text = lib.concatMapStrings limaHost limaInstances;
}
