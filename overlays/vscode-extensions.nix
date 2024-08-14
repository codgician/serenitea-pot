{ inputs }:

self: super: with inputs.nix-vscode-extensions.extensions.${super.system}; {
  inherit vscode-marketplace vscode-marketplace-release open-vsx open-vsx-release;
}
