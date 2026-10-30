{
  stdenv,
  fetchurl,
  gnumake,
  ruby_3_4,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "spinel";
  version = "2026.10.25";

  src = fetchurl {
    url = "https://github.com/matz/spinel/releases/download/${finalAttrs.version}/spinel-${finalAttrs.version}.tar.xz";
    hash = "sha256-4TxzYOT4RbSmufNKgPtrgn+VCkgNGqM55ssl5ctho7A=";
  };

  nativeBuildInputs = [
    gnumake
    ruby_3_4
  ];

  enableParallelBuilding = true;
  makeFlags = [ "PREFIX=$(out)" ];
})
