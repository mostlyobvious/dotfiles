{
  config,
  lib,
  pkgs,
  username,
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

  fileSystems."/mnt/dotfiles" = {
    device = "lima-a8135cdc1ccc6d1e";
    fsType = "virtiofs";
    options = [
      "ro"
      "nofail"
    ];
  };

  environment.systemPackages = with pkgs; [
    devenv
    fish
  ];

  environment.etc."gitconfig".text = ''
    [safe]
      directory = /mnt/dotfiles
  '';

  programs.fish.enable = true;
  programs.starship.enable = lib.mkForce false;

  # switch's VM step builds the guest home with a bare `nix build …#…`, which
  # needs these enabled; nixos-rebuild --flake injects them for itself.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

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
