{
  lib,
  allAccounts ? [ ],
  nonAdminAccounts ? [ ],
  adminKeys ? [ ],
  ...
}:

{
  # System-side provisioning for each non-admin account (see the standalone
  # per-account home-manager configs). These need root, so an account's own
  # home activation can't do them. Declaring an account here does not manage
  # the account itself — only users.knownUsers entries are created/modified.

  # Authorize the admin key(s) via nix-darwin's AuthorizedKeysCommand
  # (/etc/ssh/nix_authorized_keys.d/<account>, root-owned). A home-manager-symlinked
  # authorized_keys would fail sshd StrictModes: it resolves into the
  # group-writable /nix/store.
  users.users = lib.genAttrs nonAdminAccounts (_: {
    openssh.authorizedKeys.keys = adminKeys;
  });

  system.activationScripts.postActivation.text =
    lib.concatMapStrings (name: ''
      # sshd's PAM stack (/etc/pam.d/sshd) gates access on the com.apple.access_ssh
      # Service ACL via pam_sacl. That group is normally populated by the System
      # Settings "Remote Login" toggle, which the loopback daemon bypasses — so
      # without this ${name} authenticates but the account phase denies it.
      if ! dseditgroup -o checkmember -m ${name} com.apple.access_ssh > /dev/null 2>&1; then
        dseditgroup -o edit -a ${name} -t user com.apple.access_ssh
      fi
    '') nonAdminAccounts
    + lib.concatMapStrings (name: ''
      # Login shell. users.users.*.shell only applies to accounts nix-darwin
      # manages via users.knownUsers; every account here pre-exists, so set
      # UserShell directly to the stable, /etc/shells listed fish path.
      if [ "$(dscl . -read /Users/${name} UserShell 2>/dev/null)" != "UserShell: /run/current-system/sw/bin/fish" ]; then
        dscl . -create /Users/${name} UserShell /run/current-system/sw/bin/fish
      fi
    '') allAccounts;
}
