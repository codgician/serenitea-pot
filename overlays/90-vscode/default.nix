{ ... }:

final: prev: {
  inherit (prev.unstable)
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
