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

  # Logseq loads custom.css per graph, hence a list rather than one path.
  options.my.logseqGraphs = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Home-relative Logseq graph directories to theme.";
  };

  config = {
    home.username = username;
    home.homeDirectory = lib.mkDefault (
      if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}"
    );
    home.stateVersion = "25.05";

    programs.home-manager.enable = true;

    # Empty file; its mere existence suppresses the login banner.
    home.file.".hushlogin".text = "";

    # Install the machine-readable option index for local search/completion tools,
    # but skip the human manpage to keep the profile lean.
    manual.json.enable = true;
    manual.manpages.enable = false;
  };
}
