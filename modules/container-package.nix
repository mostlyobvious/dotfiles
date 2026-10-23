{
  lib,
  pkgs,
  username,
  ...
}:

let
  version = "1.6.0";
  installer = pkgs.fetchurl {
    url = "https://github.com/apple/container/releases/download/${version}/container-${version}-installer-signed.pkg";
    hash = "sha256-oITWbfL7VzFy1/kj+oPJIp0X9sGrYfCcipDEPatmugI=";
  };
in
{
  system.activationScripts.preActivation.text = lib.mkAfter ''
    installed_version=$(/usr/sbin/pkgutil --pkg-info com.apple.container-installer 2>/dev/null | /usr/bin/sed -n 's/^version: //p' || true)
    if [ "$installed_version" != "${version}" ] || [ ! -x /usr/local/bin/container ]; then
      for cli in /usr/local/bin/container /opt/homebrew/bin/container; do
        if [ -x "$cli" ]; then
          /usr/bin/sudo -H -u ${username} "$cli" system stop
          break
        fi
      done
    fi
  '';

  system.activationScripts.postActivation.text = lib.mkAfter ''
    installed_version=$(/usr/sbin/pkgutil --pkg-info com.apple.container-installer 2>/dev/null | /usr/bin/sed -n 's/^version: //p' || true)
    if [ "$installed_version" != "${version}" ] || [ ! -x /usr/local/bin/container ]; then
      echo >&2 "Installing Apple container ${version}"
      /usr/sbin/installer -pkg ${installer} -target /
    fi
  '';
}
