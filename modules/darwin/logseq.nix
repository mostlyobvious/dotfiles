{ config, ... }:

{
  # Logseq loads custom.css from the graph's own logseq/ dir; the sole graph
  # lives at ~/Documents/CM. Out-of-store so the app can rewrite it in place.
  home.file."Documents/CM/logseq/custom.css".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesDir}/config/logseq/custom.css";
}
