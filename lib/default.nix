{ nixpkgs, ... }: rec {
  codgician =
    let
      lib = nixpkgs.lib // { inherit codgician; };
      concatAttrs = attrList: builtins.foldl' (x: y: x // y) { } attrList;
    in
    concatAttrs [
      (import ./misc.nix { inherit lib; })
      (import ./secrets.nix { inherit lib; })
    ];
}
