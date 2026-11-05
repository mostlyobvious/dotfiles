{ pkgs, ... }:

let
  rubyEnv = pkgs.bundlerEnv {
    name = "agent-hooks-ruby-env";
    gemdir = ./agent-hooks;
    ruby = pkgs.ruby_3_4;
  };
in
{
  packages = [
    pkgs.git
    pkgs.shfmt
    rubyEnv
    rubyEnv.wrappedRuby
  ];
}
