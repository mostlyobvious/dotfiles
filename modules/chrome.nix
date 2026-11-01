{
  config,
  lib,
  pkgs,
  ...
}:

let
  disableChromeGlassFrame = pkgs.writeShellScript "disable-chrome-glass-frame" ''
    stateFile=''${CHROME_LOCAL_STATE:-"$HOME/Library/Application Support/Google/Chrome/Local State"}

    [ -f "$stateFile" ] || exit 0
    /usr/bin/pgrep -x "Google Chrome" >/dev/null && exit 0

    tmp="$(/usr/bin/mktemp "$stateFile.XXXXXX")"
    ${pkgs.jq}/bin/jq '
      .browser = (.browser // {})
      | .browser.enabled_labs_experiments = (
          ((.browser.enabled_labs_experiments // [])
            | map(select(test("^glass-frame@") | not)))
          + ["glass-frame@2"]
        )
    ' "$stateFile" > "$tmp" && /bin/mv "$tmp" "$stateFile" || {
      rc=$?
      /bin/rm -f "$tmp"
      exit "$rc"
    }
  '';
in
{
  home.activation.disableChromeGlassFrame = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${disableChromeGlassFrame}
  '';

  launchd.agents.disable-chrome-glass-frame = {
    enable = true;
    config = {
      ProgramArguments = [ "${disableChromeGlassFrame}" ];
      RunAtLoad = true;
      StartInterval = 60;
      WatchPaths = [
        "${config.home.homeDirectory}/Library/Application Support/Google/Chrome/Local State"
      ];
    };
  };
}
