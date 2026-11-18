{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.wireguard;
  inherit (config.networking) hostName;

  getPresharedKeyName = x: y: "wg-preshared-key-${if x < y then "${x}-${y}" else "${y}-${x}"}";

  # Every file under ./peers is a mesh member; this host is the one named
  # after it and peers with all the others.
  members = lib.genAttrs (lib.codgician.getNixFileNamesWithoutExt ./peers) (
    name: import (./peers + "/${name}.nix") { inherit config; }
  );
  self = members.${hostName};
in
{
  options.codgician.services.wireguard.enable = lib.mkEnableOption "WireGuard mesh membership.";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      wireguard-tools
    ];

    networking = {
      wireguard = {
        interfaces.wg0 = {
          inherit (self) privateKeyFile ips;
          mtu = 1380;
          allowedIPsAsRoutes = true;
          listenPort = self.port;
          peers = lib.mapAttrsToList (name: peer: {
            inherit (peer)
              name
              publicKey
              allowedIPs
              persistentKeepalive
              ;
            endpoint =
              if (peer.domain == null || peer.port == null) then
                null
              else
                "${peer.domain}:${builtins.toString peer.port}";
            presharedKeyFile = config.codgician.secrets.files.${getPresharedKeyName hostName name}.path;
            dynamicEndpointRefreshSeconds = 5;
          }) (removeAttrs members [ hostName ]);
        };
        useNetworkd = false; # See: https://github.com/systemd/systemd/issues/9911
      };

      firewall.allowedUDPPorts = [ self.port ];
    };
  };
}
