# Always use open-webui from unstable

{ inputs, ... }:

self: super:
let
  unstablePkgs = import inputs.nixpkgs-nixos-unstable {
    inherit (super) system;
    config.allowUnfree = true;
  };
in
{
  inherit (unstablePkgs) open-webui;
}
