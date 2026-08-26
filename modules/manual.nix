{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.manual;

  hmLib = import "${inputs.home-manager}/modules/lib/stdlib-extended.nix" pkgs.lib;

  hmOptions =
    (hmLib.evalModules {
      modules =
        import "${inputs.home-manager}/modules/modules.nix" {
          lib = hmLib;
          inherit pkgs;
          check = false;
        }
        ++ [
          {
            home.stateVersion = "25.05";
          }
        ];
      class = "homeManager";
    }).options;

  optionsDoc = pkgs.buildPackages.nixosOptionsDoc {
    options = removeAttrs hmOptions [ "_module" ];
    transformOptions = opt: opt // { declarations = [ ]; };
  };

  json = pkgs.runCommand "home-manager-options.json" { } ''
    mkdir -p $out/share/doc/home-manager
    cp ${optionsDoc.optionsJSON}/share/doc/nixos/options.json \
      $out/share/doc/home-manager/options.json
  '';
in
{
  disabledModules = [ "manual.nix" ];

  options = {
    manual.html.enable = lib.mkEnableOption "the HTML Home Manager manual";

    manual.manpages.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = "Whether to install the Home Manager configuration manual page.";
    };

    manual.json.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = "Whether to install a JSON formatted list of all Home Manager options.";
    };
  };

  config = {
    assertions = [
      {
        assertion = !cfg.html.enable;
        message = "manual.html.enable is disabled by this configuration's warning-free manual module.";
      }
      {
        assertion = !cfg.manpages.enable;
        message = "manual.manpages.enable is disabled by this configuration's warning-free manual module.";
      }
    ];

    home.packages = lib.mkIf cfg.json.enable [ json ];
  };
}
