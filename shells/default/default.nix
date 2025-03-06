{ pkgs, ... }:

pkgs.mkShell {
  buildInputs = with pkgs; [ agenix ];
  shellHook = ''
    echo "Welcome back to serenitea pot!"
  '';
}
