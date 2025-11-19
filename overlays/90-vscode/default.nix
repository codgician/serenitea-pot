{ inputs, ... }:

final: prev:
let
  unstablePkgs = import inputs.nixpkgs-unstable {
    inherit (prev) system;
    config.allowUnfree = true;
  };
in
{
  inherit (unstablePkgs)
    code-server
    openvscode-server
    vscode
    vscode-extensions
    vscode-fhs
    vscode-with-extensions
    vscodium
    vscodium-fhs
    ;
}
