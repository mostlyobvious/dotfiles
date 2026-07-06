{ ... }:

{
  # System-side provisioning for the sudo-less cm account (see the standalone
  # homeConfigurations.cm). These need root, so cm-switch can't do them.
  # Declaring cm here does not manage the account itself — only users.knownUsers
  # entries are created/modified.

  # Authorize mostlyobvious's key via nix-darwin's AuthorizedKeysCommand
  # (/etc/ssh/nix_authorized_keys.d/cm, root-owned). A home-manager-symlinked
  # authorized_keys would fail sshd StrictModes: it resolves into the
  # group-writable /nix/store.
  users.users.cm.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFai8QY2psbXCIconVn7fLRxtWmIpsasY03qgBVA8NdS mostlyobvious@pro"
  ];

  system.activationScripts.postActivation.text = ''
    # sshd's PAM stack (/etc/pam.d/sshd) gates access on the com.apple.access_ssh
    # Service ACL via pam_sacl. That group is normally populated by the System
    # Settings "Remote Login" toggle, which the loopback daemon bypasses — so
    # without this cm authenticates but the account phase denies it.
    if ! dseditgroup -o checkmember -m cm com.apple.access_ssh > /dev/null 2>&1; then
      dseditgroup -o edit -a cm -t user com.apple.access_ssh
    fi

    # Login shell. cm-switch configures fish but can't change the account's
    # UserShell — that needs root. Match mostlyobvious's stable, /etc/shells
    # listed fish path.
    if [ "$(dscl . -read /Users/cm UserShell 2>/dev/null)" != "UserShell: /run/current-system/sw/bin/fish" ]; then
      dscl . -create /Users/cm UserShell /run/current-system/sw/bin/fish
    fi
  '';
}
