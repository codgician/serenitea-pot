{ pkgs, ... }:

pkgs.mkShell {
  buildInputs = with pkgs; [ git ];
  shellHook = ''
    nix repl --expr "builtins.getFlake (builtins.toString $(git rev-parse --show-toplevel))"
  '';
}
