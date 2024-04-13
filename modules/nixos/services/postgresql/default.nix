{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.services.postgresql;
in
{
  options.codgician.services.postgresql = {
    enable = lib.mkEnableOption "Enable PostgreSQL.";
  };

  config = lib.mkIf cfg.enable {
    services.postgresql.enable = true;
    environment.systemPackages = [ (import ./upgrade-pg-cluster.nix { inherit config lib pkgs; }) ];
  };
}
