{ basePkgs, pkgs, ... }:

pkgs.mkShell {
  buildInputs = basePkgs;
}