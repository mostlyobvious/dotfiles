{ inputs }:

{
  arch = "aarch64-darwin";

  system = {
    imports = [
      ../modules/profiles/darwin-system.nix
      inputs.chattermill.darwinModules.default
    ];

    homebrew.casks = [
      "ghostty"
      "display-pilot"
      "bambu-studio"
      "logseq"
      "zed"
      "google-chrome"
      "slack"
      "signal"
      "claude"
      "1password"
      "1password-cli"
    ];
  };

  users = {
    mostlyobvious = {
      admin = true;
      modules = [
        ../modules/profiles/darwin-home.nix
        inputs.chattermill.homeModules.default
      ];
    };
  };
}
