{ config, ... }:

let
  # Out-of-store so the app can rewrite it in place; Logseq has no global
  # custom.css, so it is linked into each graph's own logseq/ dir.
  css = config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesDir}/config/logseq/custom.css";
in
{
  home.file = builtins.listToAttrs (
    map (graph: {
      name = "${graph}/logseq/custom.css";
      value.source = css;
    }) config.my.logseqGraphs
  );
}
