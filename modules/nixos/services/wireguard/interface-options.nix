{ lib, ... }:
let
  types = lib.types;
  hosts = builtins.map (lib.removeSuffix ".nix")
    (builtins.filter (lib.hasSuffix ".nix") (lib.codgician.getRegularFileNames ./peers));
in
{
  options = {
    host = lib.mkOption {
      type = types.enum hosts;
      description = "Name of host configuration file to use.";
    };

    peers = lib.mkOption {
      type = types.listOf (types.enum hosts);
      description = "List of enabled peer configuration names.";
    };

    allowedIPsAsRoutes = lib.mkEnableOption "Whether to add allowed IPs as routes or not.";
  };
}
