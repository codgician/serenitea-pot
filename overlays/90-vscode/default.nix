{ inputs, ... }:

self: super:
let
  unstablePkgs = import inputs.nixpkgs-unstable {
    inherit (super) system;
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
