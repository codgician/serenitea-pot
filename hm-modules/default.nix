# Export home manager modules for each user

{ lib, ... }:
let
  names = lib.codgician.getFolderNames ./.;
  mkModule =
    paths:
    (
      { ... }:
      {
        imports = paths;
      }
    );
  hmPaths = user: rec {
    generic = lib.codgician.getFolderPaths ./${user}/generic;
    darwin = generic ++ (lib.codgician.getFolderPaths ./${user}/darwin);
    nixos = generic ++ (lib.codgician.getFolderPaths ./${user}/nixos);
  };
in
lib.pipe names [
  (builtins.map (user: {
    name = user;
    value = builtins.mapAttrs (_: v: mkModule v) (hmPaths user);
  }))
  builtins.listToAttrs
]
