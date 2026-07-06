{ ... }:

{
  # Authorize mostlyobvious's key for cm via nix-darwin's AuthorizedKeysCommand
  # (/etc/ssh/nix_authorized_keys.d/cm, root-owned). A home-manager-symlinked
  # authorized_keys would fail sshd StrictModes: it resolves into the
  # group-writable /nix/store. Declaring cm here does not manage the account —
  # only users.knownUsers entries are created/modified.
  users.users.cm.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFai8QY2psbXCIconVn7fLRxtWmIpsasY03qgBVA8NdS mostlyobvious@pro"
  ];

  # Loopback-only sshd for same-host access to other local accounts (e.g. cm).
  # Apple's sshd is socket-activated, so `ListenAddress` in sshd_config is
  # ignored — the launchd socket must be bound to loopback instead. This owns its
  # own socket rather than Apple's ssh.plist, so Remote Login (all interfaces)
  # stays off. Reuses /usr/sbin/sshd, /etc/ssh/sshd_config, and the host keys.
  launchd.daemons.sshd-loopback.serviceConfig = {
    ProgramArguments = [
      "/usr/sbin/sshd"
      "-i"
    ];
    inetdCompatibility.Wait = false;
    SessionCreate = true;
    StandardErrorPath = "/var/log/sshd-loopback.log";
    Sockets = {
      Loopback4 = {
        SockServiceName = "ssh";
        SockNodeName = "127.0.0.1";
        SockFamily = "IPv4";
      };
      Loopback6 = {
        SockServiceName = "ssh";
        SockNodeName = "::1";
        SockFamily = "IPv6";
      };
    };
  };
}
