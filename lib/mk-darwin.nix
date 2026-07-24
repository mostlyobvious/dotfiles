{
  home-manager,
  nix-darwin,
  determinate,
  inputs,
  username,
  allowUnfreePred,
}:

# Per-host config (extra casks, host-only modules) goes in extraModules.
{
  hostname,
  system ? "aarch64-darwin",
  nonAdminAccounts ? [ ],
  adminKeys ? [ ],
  extraModules ? [ ],
}:
nix-darwin.lib.darwinSystem {
  inherit system;
  specialArgs = {
    inherit
      username
      hostname
      nonAdminAccounts
      adminKeys
      ;
  };
  modules = [
    determinate.darwinModules.default
    ../modules/darwin-core.nix
    ../modules/system.nix
    ../modules/sudo.nix
    ../modules/sshd.nix
    ../modules/homebrew.nix
    ../modules/account.nix
    home-manager.darwinModules.home-manager
    { nixpkgs.config.allowUnfreePredicate = allowUnfreePred; }
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      # Back up colliding files instead of aborting the switch.
      home-manager.backupFileExtension = "hm-bak";
      home-manager.extraSpecialArgs = { inherit username hostname inputs; };
      home-manager.users.${username}.imports = [
        inputs.agent-skills.homeManagerModules.default
        ../modules/core.nix
        ../modules/cli.nix
        ../modules/git.nix
        ../modules/fish.nix
        ../modules/neovim.nix
        ../modules/ruby.nix
        ../modules/claude.nix
        ../modules/pi.nix
        ../modules/eza.nix
        ../modules/skills.nix
        ../modules/ssh.nix
        ../modules/ghostty.nix
        ../modules/zed.nix
        ../modules/logseq.nix
        ../modules/fonts.nix
        ../modules/macos-defaults.nix
        # iCloud history sync — only the primary account has iCloud, so
        # keep it off the shared layer (cm) and the VMs.
        ../modules/history.nix
        (
          { pkgs, ... }:
          {
            home.packages = [
              pkgs.lima
              pkgs.rtl_433
            ];
          }
        )
        # Per-account Logseq graphs; the iCloud graph is left out to
        # avoid syncing a store symlink across devices.
        {
          my.logseqGraphs = [
            "Notes/mostlyobvious"
            "Notes/hraba.gs"
          ];
        }
      ];
    }
  ]
  ++ extraModules;
}
