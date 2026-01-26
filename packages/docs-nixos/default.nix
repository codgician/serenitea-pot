{
  lib,
  stdenv,
  nixosOptionsDoc,
  options ?
    (lib.codgician.mkNixosSystem {
      hostName = "nixos";
      inherit (stdenv.hostPlatform) system;
    }).options,
  ...
}:

let
  # Generate options documentation
  optionsDoc = nixosOptionsDoc {
    inherit options;
    # Only document our custom options
    transformOptions =
      opt: if lib.hasPrefix "codgician" opt.name then opt else opt // { visible = false; };
  };
in
optionsDoc.optionsCommonMark // {
  meta = with lib; {
    description = "Documentation for serenitea-pot on NixOS";
    maintainers = with maintainers; [ codgician ];
    platforms = platforms.linux ++ [ "aarch64-darwin" ];
  };
}
