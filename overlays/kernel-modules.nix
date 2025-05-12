# Use version from unstable for specified kernel modules

{ inputs, ... }:

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
      lpself: lpsuper: {
        # Parallel tools kernel module
        prl-tools = unstablePkgs.linuxPackages.prl-tools.override {
          inherit (lpsuper) kernel;
        };

        # mstflint kernel module
        mstflint_access = unstablePkgs.linuxPackages.mstflint_access.override {
          inherit (lpsuper) kernel;
          inherit (unstablePkgs) mstflint;
        };
      }
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
