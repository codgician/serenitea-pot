{ config, pkgs, ... }: {

  services.vscode-server = {
    enable = true;
    extraRuntimeDependencies = with pkgs; [
      direnv
      rnix-lsp
    ];
  };
}
