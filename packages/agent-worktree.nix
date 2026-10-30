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
      ../agent-hooks/bin/agent-worktree
      ../agent-hooks/lib/agent_hooks/worktree.rb
    ];
  };
in
stdenv.mkDerivation {
  pname = "agent-worktree";
  version = "0.1.0";
  src = source;

  nativeBuildInputs = [ spinel ];

  buildPhase = ''
    runHook preBuild
    spinel -I lib bin/agent-worktree -o agent-worktree
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 agent-worktree $out/bin/agent-worktree
    runHook postInstall
  '';

  meta.mainProgram = "agent-worktree";
}
