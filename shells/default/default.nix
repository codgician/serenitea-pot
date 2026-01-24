{ pkgs, ... }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    agenix
    direnv
    git
    nixd
    opencode
  ];
  shellHook = ''
    echo "Welcome to serenitea pot!"
  '';
}
