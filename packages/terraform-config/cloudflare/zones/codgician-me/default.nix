{ lib, ... }:
{
  imports = lib.codgician.getRegularFilePaths ./records;

  resource = {
    cloudflare_zone.codgician-me = {
      account.id = "1a47d32e456a0ce6486a8d63173cee77";
      name = "codgician.me";
      type = "full";
    };
  };
}
