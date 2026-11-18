{ lib, ... }:
{
  codgician = {
    system = {
      auto-upgrade.enable = true;
      impermanence.enable = lib.mkDefault true;
    };

    users.codgi.hashedPasswordSecret = "codgi-hashed-password";
  };

  services.vscode-server.enable = true;
}
