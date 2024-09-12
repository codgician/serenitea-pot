# Always use prl-tools from unstable

{ inputs }:

self: super:
let
  unstablePkgs = import inputs.nixpkgs-nixos-unstable {
    inherit (super) system;
    config.allowUnfree = true;
  };
in
{
  linuxPackages = super.linuxPackages.extend (lpself: lpsuper: {
    prl-tools = (unstablePkgs.linuxPackages.prl-tools.override {
      inherit (lpsuper) kernel;
    }).overrideAttrs (oldAttrs: rec {
      version = "20.0.0-55653";
      src = super.fetchurl {
        url = "https://download.parallels.com/desktop/v${super.lib.versions.major version}/${version}/ParallelsDesktop-${version}.dmg";
        hash = "sha256-ohGhaLVzXuR/mQ6ToeGbTixKy01F14JSgTs128vGZXM=";
      };
      buildInputs = oldAttrs.buildInputs ++ [ super.fuse ];
    });
  });
}
