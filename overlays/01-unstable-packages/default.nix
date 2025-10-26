{ inputs, ... }:

self: super:
let
  unstablePkgs = import inputs.nixpkgs-unstable {
    inherit (super) system;
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
    ;
}
