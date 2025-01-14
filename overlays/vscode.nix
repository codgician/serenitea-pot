{ inputs, ... }:

self: super:
let
  unstablePkgs = import inputs.nixpkgs-unstable {
    inherit (super) system;
    config.allowUnfree = true;
  };
in
with inputs.nix-vscode-extensions.extensions.${super.system};
{
  inherit (unstablePkgs) vscode vscode-fhs vscode-with-extensions vscodium vscodium-fhs;
  inherit vscode-marketplace vscode-marketplace-release open-vsx open-vsx-release;
}
