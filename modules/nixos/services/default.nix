{ lib, ... }: {
  imports = [
    ./nixos-vscode-server.nix
  ] ++ (lib.optionals (lib.version >= "24.05") [
    ./plasma.nix
  ]);
}
