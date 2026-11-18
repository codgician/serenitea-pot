{ lib, ... }:
{
  codgician = {
    services.nixos-vscode-server.enable = true;

    system = {
      auto-upgrade.enable = true;
      impermanence.enable = lib.mkDefault true;
    };

    users.codgi.hashedPasswordAgeFile = lib.codgician.getAgeSecretPathFromName "codgi-hashed-password";
  };
}
