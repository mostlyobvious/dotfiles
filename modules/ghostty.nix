{ ... }:

{
  programs.ghostty = {
    enable = true;
    package = null; # installed as a cask
    settings = {
      theme = "dark:Duskfox, light:Dawnfox";
      window-colorspace = "display-p3";
      window-padding-x = 16;
      window-padding-y = 12;
      font-size = 16;
      font-family = "Berkeley Mono";
      copy-on-select = "clipboard";
      macos-titlebar-proxy-icon = "hidden";
      window-height = 50;
      window-width = 170;
      working-directory = "/Users/mostlyobvious/Code";
      tab-inherit-working-directory = false;
      quick-terminal-position = "top";
      quick-terminal-size = "67%";
      quick-terminal-screen = "mouse";
      quick-terminal-animation-duration = 0.15;
      quick-terminal-autohide = true;
      keybind = [
        "global:super+backquote=toggle_quick_terminal"
        "global:super+§=toggle_quick_terminal"
      ];
    };
  };
}
