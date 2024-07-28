{ config, lib, ... }: {
  imports = lib.codgician.getRegularFilePaths ./records;

  resource.cloudflare_zone.codgician-me = {
    account_id = "1a47d32e456a0ce6486a8d63173cee77";
    paused = false;
    zone = "codgician.me";
    plan = "free";
    type = "full";
  };
}
