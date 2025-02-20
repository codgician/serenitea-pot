{ lib, pkgs, ... }:
{
  type = "app";
  meta = {
    description = "REPL environment for debugging this flake";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ codgician ];
  };

  program = lib.getExe (
    pkgs.writeShellApplication {
      name = builtins.baseNameOf ./.;
      runtimeInputs = with pkgs; [ git ];

      text = ''
        nix repl --expr "builtins.getFlake (builtins.toString $(git rev-parse --show-toplevel))"
      '';
    }
  );
}
