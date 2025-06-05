{
  lib,
  pkgs,
  options ?
    (lib.codgician.mkNixosSystem {
      hostName = "nixos";
      inherit (pkgs) system;
    }).options,
  ...
}:

let
  # Generate options documentation
  optionsDoc = pkgs.nixosOptionsDoc {
    inherit options;
    # Only document our custom options
    transformOptions =
      opt: if lib.hasPrefix "codgician" opt.name then opt else opt // { visible = false; };
  };
in
optionsDoc.optionsCommonMark
