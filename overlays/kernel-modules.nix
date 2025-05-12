# Use version from unstable for specified kernel modules

{ inputs, lib, ... }:

self: super:
let
  unstablePkgs = import inputs.nixpkgs-unstable {
    inherit (super) system;
    config.allowUnfree = true;
  };

  linuxPackageNames = builtins.filter (name: builtins.match "linuxPackages.*" name != null) (
    builtins.attrNames super
  );

  mkLinuxPackageOverride =
    name:
    super.${name}.extend (
      lpself: lpsuper:
      lib.genAttrs [
        "mstflint_access"
        "prl-tools"
      ] (pkgName: unstablePkgs.linuxPackages.${pkgName}.override { inherit (lpsuper) kernel; })
    );
in
{
  inherit (unstablePkgs) mstflint;
}
// builtins.listToAttrs (
  builtins.map (name: {
    inherit name;
    value = mkLinuxPackageOverride name;
  }) linuxPackageNames
)
