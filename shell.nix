{ pkgs ? import <nixpkgs> {} }: 
pkgs.mkShell {
  nativeBuildInputs = with pkgs; [ rnix-lsp ];
}