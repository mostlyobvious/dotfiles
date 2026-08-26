{
  config,
  lib,
  pkgs,
  username,
  ...
}:

{
  options.my.dotfilesDir = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/Code/dotfiles";
    description = "Absolute path to the dotfiles working copy, the target of out-of-store symlinks.";
  };

  options.my.signingKey = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/.ssh/id_ed25519.pub";
    description = "Absolute path to the SSH public key used to sign commits.";
  };

  options.my.userEmail = lib.mkOption {
    type = lib.types.str;
    default = "pawel.pacana@gmail.com";
    description = "Email address used as the git commit author.";
  };

  options.my.limaVms = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Lima VM instance names to alias in SSH config; set by the host file that declares the VMs.";
  };

  config = {
    home.username = username;
    home.homeDirectory = lib.mkDefault (
      if pkgs.stdenv.hostPlatform.isDarwin then "/Users/${username}" else "/home/${username}"
    );
    home.stateVersion = "25.05";

    programs.home-manager.enable = true;

    # Empty file; its mere existence suppresses the login banner.
    home.file.".hushlogin".text = "";

    # Keep the local option index installed; modules/manual.nix strips declaration
    # locations to avoid Nix's context warning while Home Manager upstream catches up.
    manual.json.enable = true;
    manual.manpages.enable = false;
  };
}
