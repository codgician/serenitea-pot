{ config, lib, ... }:
let
  cfg = config.codgician.services.wireguard;
  types = lib.types;
  systemCfg = config.codgician.system;
  agenixEnabled = (systemCfg?agenix && systemCfg.agenix.enable);
  hosts = builtins.map (lib.removeSuffix ".nix")
    (builtins.filter (lib.hasSuffix ".nix") (lib.codgician.getRegularFileNames ./peers));
  hostOptions = builtins.listToAttrs
    (builtins.map (name: { inherit name; value = import (./peers + "/${name}.nix") { inherit config lib; }; }) hosts);
  ports = lib.unique (builtins.map (x: x.listenPort) (builtins.attrValues hostOptions));
in
{
  options.codgician.services.wireguard = {
    enable = lib.mkEnableOption "Enable WireGuard.";

    openFirewall = lib.mkEnableOption "Open firewall for WireGuard ports.";

    interfaces = lib.mkOption {
      type = types.attrsOf (types.submodule (import ./interface-options.nix { inherit lib; }));
      default = { };
      description = "WireGuard interface configurations.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # WireGuard configuration
    {
      networking = {
        wireguard.interfaces = builtins.mapAttrs
          (name: value: {
            inherit (hostOptions.${value.host}) privateKeyFile ips listenPort;
            inherit (value) allowedIPsAsRoutes;
            peers = builtins.map
              (name: {
                inherit (hostOptions.${name}) name endpoint publicKey presharedKeyFile allowedIPs;
                dynamicEndpointRefreshSeconds = 10;
                dynamicEndpointRefreshRestartSeconds = 60;
              })
              value.peers;
          })
          cfg.interfaces;

          # Open firewall
          firewall.allowedUDPPorts = lib.mkIf cfg.openFirewall ports;
      };
    }

    # Agenix credentials
    (lib.mkIf agenixEnabled (
      let
        hosts = builtins.map (x: x.host) (builtins.attrValues (cfg.interfaces));
        peers = builtins.concatMap (x: x.peers) (builtins.attrValues (cfg.interfaces));
        secrets = builtins.concatMap (x: hostOptions.${x}.ageFilePaths) (lib.lists.unique (hosts ++ peers));
      in
      lib.codgician.mkAgenixConfigs "root" secrets
    ))
  ]);
}
