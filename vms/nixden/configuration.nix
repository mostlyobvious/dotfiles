{
  config,
  lib,
  pkgs,
  username,
  inputs,
  ...
}:

{
  system.stateVersion = "25.11";

  networking.hostName = "nixden";
  networking.useDHCP = lib.mkDefault true;
  time.timeZone = "Europe/Warsaw";

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 3;
  boot.loader.efi.canTouchEfiVariables = false;

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    options = [
      "x-systemd.growfs"
      "x-initrd.mount"
      "noatime"
      "nodiratime"
      "discard"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/vda1";
    fsType = "vfat";
  };

  fileSystems."/mnt/lima-cidata" = {
    device = "/dev/disk/by-label/cidata";
    fsType = "auto";
    options = [
      "ro"
      "mode=0700"
      "dmode=0700"
      "overriderockperm"
      "exec"
      "uid=0"
    ];
  };

  fileSystems."/run/rosetta" = lib.mkIf pkgs.stdenv.hostPlatform.isAarch64 {
    device = "vz-rosetta";
    fsType = "virtiofs";
  };

  fileSystems."/mnt/lima-rosetta" = lib.mkIf pkgs.stdenv.hostPlatform.isAarch64 {
    device = "vz-rosetta";
    fsType = "virtiofs";
  };

  fileSystems."/tmp/lima-nixden" = {
    device = "lima-dd882cae3d472735";
    fsType = "virtiofs";
    options = [
      "rw"
      "nofail"
    ];
  };

  environment.systemPackages = with pkgs; [
    devenv
    fish
  ];

  programs.fish.enable = true;
  programs.starship.enable = lib.mkForce false;

  users.users.${username} = {
    isSystemUser = true;
    uid = 501;
    group = "users";
    home = "/home/${username}.guest";
    createHome = true;
    description = "Paweł Pacana";
    extraGroups = [
      "docker"
      "wheel"
    ];
    shell = pkgs.fish;
  };

  virtualisation.docker.enable = true;

  security.sudo.wheelNeedsPassword = false;

  services.openssh.enable = true;
  services.dbus.implementation = "dbus";

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "hm-bak";
  home-manager.extraSpecialArgs = { inherit username inputs; };
  home-manager.users.${username}.imports = [
    inputs.agent-skills.homeManagerModules.default
    ../../modules/home/common.nix
    {
      my.dotfilesDir = "/tmp/lima-nixden/dotfiles";
      home.homeDirectory = "/home/${username}.guest";
      programs.zed-editor = {
        enable = true;
        installRemoteServer = true;
      };
    }
  ];

  assertions = [
    {
      assertion =
        !(
          config.environment.systemPackages or [ ] != [ ]
          && builtins.elem pkgs.just config.environment.systemPackages
        );
      message = "nixden should not install just in the system profile.";
    }
  ];
}
