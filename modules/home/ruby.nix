{ ... }:

{
  # No Ruby toolchain here: per-project Ruby comes from nix devshells via direnv.
  home.file.".gemrc".source = ../../config/ruby/gemrc;
  home.file.".irbrc".source = ../../config/ruby/irbrc;
}
