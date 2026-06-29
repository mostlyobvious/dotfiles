{ ... }:

{
  # No Ruby toolchain here: per-project Ruby comes from nix devshells via direnv.
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
