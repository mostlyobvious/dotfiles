{
  config,
  lib,
  pkgs,
  username,
  ...
}:

{
  imports = [
    ./git.nix
    ./fish.nix
    ./neovim.nix
    ./ruby.nix
    ./claude.nix
    ./pi.nix
    ./eza.nix
    ./skills.nix
  ];

  # Working-copy path for out-of-store symlinks. Override if the repo lives elsewhere.
  options.my.dotfilesDir = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/Code/dotfiles";
    description = "Absolute path to the dotfiles working copy.";
  };

  # SSH public key used for commit signing. Override per account.
  options.my.signingKey = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/.ssh/id_ed25519.pub";
    description = "Absolute path to the SSH public key used to sign commits.";
  };

  # Git commit author email. Override per account.
  options.my.userEmail = lib.mkOption {
    type = lib.types.str;
    default = "pawel.pacana@gmail.com";
    description = "Email address used as the git commit author.";
  };

  config = {
    home.username = username;
    home.homeDirectory = lib.mkDefault (
      if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}"
    );
    home.stateVersion = "25.05";

    home.packages = with pkgs; [
      stylua
      lua-language-server
      secretspec
      devenv
      glab
    ];

    programs.home-manager.enable = true;

    # Empty file; its mere existence suppresses the login banner.
    home.file.".hushlogin".text = "";

    # Install the machine-readable option index for local search/completion tools,
    # but skip the human manpage to keep the profile lean.
    manual.json.enable = true;
    manual.manpages.enable = false;

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    programs.fd.enable = true;
    programs.gh.enable = true;
    programs.jq.enable = true;
    programs.ripgrep.enable = true;

    programs.fzf.enable = true;
  };
}
