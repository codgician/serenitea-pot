{ ... }:

final: prev: {
  inherit (prev.unstable)
    vscode
    vscode-extensions
    vscode-fhs
    vscode-with-extensions
    vscodium
    vscodium-fhs
    ;
}
