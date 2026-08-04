{ pkgs, ... }:

let
  volume = "elasticsearch";
  sectors = "131072";
  ensureRamdisk = pkgs.writeShellScript "ensure-elasticsearch-volume" ''
    set -euo pipefail

    if [ ! -d "/Volumes/${volume}" ]; then
      device=$(/usr/bin/hdiutil attach -nomount ram://${sectors} | tr -d '[:space:]')
      /usr/sbin/diskutil erasevolume APFS "${volume}" "$device"
    fi

    /bin/mkdir -p "/Volumes/${volume}"
    /usr/sbin/chown mostlyobvious:staff "/Volumes/${volume}"
    /bin/chmod 755 "/Volumes/${volume}"
  '';
in
{
  launchd.daemons.elasticsearch-volume = {
    command = "${ensureRamdisk}";
    serviceConfig.RunAtLoad = true;
  };
}
