{
  pkgs,
  lib,
  inputs,
  ...
}:

let
  # Purchased zips live in the private `fonts` flake input, never in this repo.
  # find-based install so the packaging survives whatever layout the zip uses.
  fontPkg =
    { pname, zip }:
    pkgs.stdenvNoCC.mkDerivation {
      inherit pname;
      version = inputs.fonts.shortRev or "unstable";
      src = "${inputs.fonts}/${zip}";
      nativeBuildInputs = [ pkgs.unzip ];
      sourceRoot = ".";
      installPhase = ''
        runHook preInstall
        # -not -name '._*' drops the AppleDouble sidecars macOS zips carry.
        find . -iname '*.otf' -not -name '._*' -exec install -Dm444 -t $out/share/fonts/opentype {} +
        find . -iname '*.ttf' -not -name '._*' -exec install -Dm444 -t $out/share/fonts/truetype {} +
        runHook postInstall
      '';
      meta.license = lib.licenses.unfree;
    };
in
{
  # Per-user, not system-wide: home-manager rsyncs share/fonts from home.packages
  # into ~/Library/Fonts/HomeManager, so each account keeps its own copy.
  home.packages = [
    (fontPkg {
      pname = "berkeley-mono";
      zip = "BerkeleyMono.zip";
    })
    (fontPkg {
      pname = "pragmatapro";
      zip = "PragmataPro.zip";
    })
  ];
}
