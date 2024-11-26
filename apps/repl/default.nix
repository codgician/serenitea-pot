{ lib, inputs, ... }:

# nix repl for debugging
lib.codgician.forAllSystems (pkgs: inputs.flake-utils.lib.mkApp {
  drv = pkgs.writeShellApplication {
    name = builtins.baseNameOf ./.;
    runtimeInputs = with pkgs; [ git ];
    text = ''
      nix repl --expr "builtins.getFlake (builtins.toString $(git rev-parse --show-toplevel))"
    '';
  };
})
