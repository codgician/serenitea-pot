{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.wireguard;
  types = lib.types;
  hosts = lib.codgician.getNixFileNamesWithoutExt ./peers;
  hostOptions = lib.pipe hosts [
    (builtins.map (name: {
      inherit name;
      value = import (./peers + "/${name}.nix") { inherit config lib; };
    }))
    builtins.listToAttrs
  ];
  ports = lib.pipe hostOptions [
    builtins.attrValues
    (builtins.map (x: x.listenPort))
    lib.unique
  ];
in
{
  options.codgician.services.wireguard = {
    enable = lib.mkEnableOption "WireGuard.";

    openFirewall = lib.mkEnableOption "Open firewall for WireGuard ports.";

    interfaces = lib.mkOption {
      type =
        with types;
        attrsOf (submodule {
          options = {
            host = lib.mkOption {
              type = types.enum hosts;
              description = "Name of host configuration file to use.";
            };

            peers = lib.mkOption {
              type = with types; listOf (enum hosts);
              description = "List of enabled peer configuration names.";
            };

            mtu = lib.mkOption {
              type = types.int;
              default = 1412;
              description = "MTU for the interface.";
            };

            allowedIPsAsRoutes = lib.mkEnableOption ''
              Whether to add allowed IPs as routes or not.
            '';
          };
        });
      default = { };
      description = "WireGuard interface configurations.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # WireGuard configuration
      {
        environment.systemPackages = with pkgs; [
          wireguard-tools
        ];

        networking = {
          wireguard.interfaces = builtins.mapAttrs (name: value: {
            inherit (hostOptions.${value.host}) privateKeyFile ips listenPort;
            inherit (value) mtu allowedIPsAsRoutes;
            peers = builtins.map (name: {
              inherit (hostOptions.${name})
                name
                endpoint
                publicKey
                presharedKeyFile
                allowedIPs
                ;
              dynamicEndpointRefreshSeconds = 10;
              dynamicEndpointRefreshRestartSeconds = 60;
            }) value.peers;
          }) cfg.interfaces;

          interfaces = builtins.mapAttrs (name: value: {
            proxyARP = true;
          }) cfg.interfaces;

          # Open firewall
          firewall.allowedUDPPorts = lib.mkIf cfg.openFirewall ports;
        };
      }

      # Agenix credentials
      (
        let
          hosts = builtins.map (x: x.host) (builtins.attrValues (cfg.interfaces));
          peers = builtins.concatMap (x: x.peers) (builtins.attrValues (cfg.interfaces));
          secrets = builtins.concatMap (x: hostOptions.${x}.ageFilePaths) (lib.lists.unique (hosts ++ peers));
        in
        lib.codgician.mkAgenixConfigs { } secrets
      )
    ]
  );
}
