{ pkgs, inputs, ... }:

# nix repl for debugging
inputs.flake-utils.lib.mkApp {
  drv = pkgs.writeShellScriptBin "repl" ''
    nix repl --expr "builtins.getFlake (builtins.toString $(${pkgs.git}/bin/git rev-parse --show-toplevel))"
  '';
}
