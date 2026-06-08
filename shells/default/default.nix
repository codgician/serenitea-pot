{ pkgs, ... }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    sops
    ssh-to-age
    direnv
    git
    nixd
  ];
  shellHook = ''
    echo "Welcome to serenitea pot!"
  '';
}
