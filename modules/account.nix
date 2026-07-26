{
  lib,
  allAccounts ? [ ],
  ...
}:

{
  # System-side provisioning for each account (see the standalone per-account
  # home-manager configs). These need root, so an account's own home activation
  # can't do them. Declaring an account here does not manage the account itself
  # — only users.knownUsers entries are created/modified.

  system.activationScripts.postActivation.text = lib.concatMapStrings (name: ''
    # Login shell. users.users.*.shell only applies to accounts nix-darwin
    # manages via users.knownUsers; every account here pre-exists, so set
    # UserShell directly to the stable, /etc/shells listed fish path.
    if [ "$(dscl . -read /Users/${name} UserShell 2>/dev/null)" != "UserShell: /run/current-system/sw/bin/fish" ]; then
      dscl . -create /Users/${name} UserShell /run/current-system/sw/bin/fish
    fi
  '') allAccounts;
}
