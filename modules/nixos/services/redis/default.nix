{ pkgs, ... }:
{
  config = {
    services.redis.package = pkgs.valkey;
  };
}
