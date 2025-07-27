{ pkgs, ... }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    agenix
    direnv
    git
    nixd
  ];
  shellHook = ''
    echo "Welcome to serenitea pot!"
  '';
}
