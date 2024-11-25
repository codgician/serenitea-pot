{ lib, inputs, ... }:

# nix repl for debugging
lib.codgician.forAllSystems (pkgs: inputs.flake-utils.lib.mkApp {
  drv = pkgs.writeShellScriptBin "repl" ''
    nix repl --expr "builtins.getFlake (builtins.toString $(${pkgs.git}/bin/git rev-parse --show-toplevel))"
  '';
})
