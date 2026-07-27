{ ... }:

let
  # Duskfox palette, to match ghostty/nvim.
  fg = "#e0def4";
  fg3 = "#6e6a86";
  comment = "#817c9c";
  red = "#eb6f92";
  yellow = "#f6c177";
  orange = "#ea9a97";
  blue = "#569fba";
  cyan = "#9ccfd8";
  magenta = "#c4a7e7";
  c = colour: { foreground = colour; };
in
{
  programs.eza.enable = true;

  # Preserve the long-form tree alias; Home Manager provides ls/ll/la/lt/lla.
  programs.fish.shellAliases.tree = "eza --tree";

  programs.eza.theme = {
    colourful = true;

    filekinds = {
      normal = c fg;
      directory = c cyan;
      symlink = c magenta;
      pipe = c comment;
      block_device = c yellow;
      char_device = c yellow;
      socket = c red;
      special = c yellow;
      executable = c orange;
      mount_point = c cyan;
    };

    perms = {
      user_read = c yellow;
      user_write = c red;
      user_execute_file = c blue;
      user_execute_other = c blue;
      group_read = c yellow;
      group_write = c red;
      group_execute = c blue;
      other_read = c yellow;
      other_write = c red;
      other_execute = c blue;
      special_user_file = c magenta;
      special_other = c magenta;
      attribute = c fg3;
    };

    size = {
      major = c fg;
      minor = c comment;
      number_byte = c fg;
      number_kilo = c fg;
      number_mega = c fg;
      number_giga = c fg;
      number_huge = c fg;
      unit_byte = c comment;
      unit_kilo = c comment;
      unit_mega = c comment;
      unit_giga = c comment;
      unit_huge = c comment;
    };

    users = {
      user_you = c fg;
      user_other = c comment;
      user_root = c red;
    };

    links = {
      normal = c cyan;
      multi_link_file = c yellow;
    };

    git = {
      new = c cyan;
      modified = c yellow;
      deleted = c red;
      renamed = c magenta;
      typechange = c orange;
      ignored = c fg3;
      conflicted = c red;
    };

    file_type = {
      image = c yellow;
      video = c red;
      music = c cyan;
      lossless = c cyan;
      crypto = c fg3;
      document = c fg;
      compressed = c magenta;
      temp = c fg3;
      compiled = c comment;
      build = c comment;
      source = c blue;
    };

    punctuation = c fg3;
    date = c blue;
    inode = c fg3;
    blocks = c fg3;
    header = (c comment) // {
      is_bold = true;
    };
    symlink_path = c magenta;
    control_char = c red;
    broken_symlink = c red;
    broken_path_overlay = c red;
  };
}
