{ config, ... }: {
  resource = {
    cloudflare_zone.codgician = {
      account_id = "1a47d32e456a0ce6486a8d63173cee77";
      zone = "codgician.me";
      plan = "free";
    };
  };
}