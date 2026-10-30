{
  lib,
  stdenv,
  callPackage,
}:

let
  spinel = callPackage ./spinel.nix { };
  source = lib.fileset.toSource {
    root = ../agent-hooks;
    fileset = lib.fileset.unions [
      ../agent-hooks/bin/agent-guard
      ../agent-hooks/lib/agent_hooks/guard.rb
    ];
  };
in
stdenv.mkDerivation {
  pname = "agent-guard";
  version = "0.1.0";
  src = source;

  nativeBuildInputs = [ spinel ];

  buildPhase = ''
    runHook preBuild
    spinel -I lib bin/agent-guard -o agent-guard
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 agent-guard $out/bin/agent-guard
    runHook postInstall
  '';

  meta.mainProgram = "agent-guard";
}
