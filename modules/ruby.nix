{ ... }:

{
  # No Ruby toolchain here: per-project Ruby comes from nix devshells via direnv.
  home.sessionVariables.DISABLE_SPRING = "true";

  # Exec the bundle binary directly, not `open -a`: LaunchServices would drop
  # the devenv shell environment RubyMine needs to resolve the Ruby toolchain.
  programs.fish.functions.rubymine = ''
    set --local bin /Applications/RubyMine.app/Contents/MacOS/rubymine

    if not test -x $bin
        echo "rubymine: $bin not found" >&2
        return 1
    end

    set --local target $argv
    test (count $target) -eq 0; and set target .

    $bin $target >/dev/null 2>&1 &
    disown
  '';

  home.file.".gemrc".text = "gem: --no-document\n";

  home.file.".irbrc".text = ''
    IRB.conf[:SAVE_HISTORY] = 1000

    def pbcopy(input)
      str = input.to_s
      IO.popen("pbcopy", "w") { |f| f << str }
      str
    end

    def pbpaste
      `pbpaste`
    end

    def event_store
      Rails.configuration.event_store
    end

    def command_bus
      Rails.configuration.command_bus
    end

    def sepuku
      Process.kill("KILL", Process.pid)
    end
  '';
}
