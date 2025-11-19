{ inputs, ... }:

final: prev:
let
  unstablePkgs = import inputs.nixpkgs-unstable {
    inherit (prev) system;
    config = {
      allowUnfree = true;
    };
  };
in
{
  inherit (unstablePkgs)
    sing-box
    sing-geoip
    nexttrace
    codex
    claude-code
    ;
}
