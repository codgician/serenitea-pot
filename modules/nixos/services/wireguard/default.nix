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

  # Get wireguard secret file names without extension
  getPrivateKeyName = x: "wg-private-key-${x}";
  getPresharedKeyName = x: y: "wg-preshared-key-${if x < y then "${x}-${y}" else "${y}-${x}"}";

  # All host options
  hostOptions = lib.pipe hosts [
    (builtins.map (name: {
      inherit name;
      value = import (./peers + "/${name}.nix") { inherit config; };
    }))
    builtins.listToAttrs
  ];

  # Ports of all wireguard interfaces
  ports = lib.pipe cfg.interfaces [
    builtins.attrValues
    (builtins.map (intCfg: hostOptions.${intCfg.host}.listenPort))
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
          wireguard = {
            interfaces = builtins.mapAttrs (_: intCfg: {
              inherit (hostOptions.${intCfg.host}) privateKeyFile ips listenPort;
              inherit (intCfg) mtu allowedIPsAsRoutes;
              peers = builtins.map (peer: {
                inherit (hostOptions.${peer})
                  name
                  endpoint
                  publicKey
                  allowedIPs
                  ;
                presharedKeyFile = config.age.secrets.${getPresharedKeyName intCfg.host peer}.path;
                dynamicEndpointRefreshSeconds = 5;
              }) intCfg.peers;
            }) cfg.interfaces;
          }
          // (lib.optionalAttrs (lib.versionAtLeast lib.version "25.05") {
            useNetworkd = false; # See: https://github.com/systemd/systemd/issues/9911
          });

          # Open firewall
          firewall.allowedUDPPorts = lib.mkIf cfg.openFirewall ports;
        };

        assertions = builtins.map (intCfg: {
          assertion = lib.all (x: x != intCfg.host) (intCfg.peers);
          message = "WireGuard: Host ${intCfg.host} should not be in peers list.";
        }) (builtins.attrValues cfg.interfaces);
      }
    ]
  );
}
