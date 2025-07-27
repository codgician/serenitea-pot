{ pkgs, ... }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    agenix
    disko
    direnv
    git
    nixd
  ];
  shellHook = ''
    echo "Welcome to serenitea pot!"
  '';
}
