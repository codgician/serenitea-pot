{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.wireguard;
  inherit (config.networking) hostName;
  secret = name: config.codgician.secrets.files.${name}.path;
  # The key a pair shares is named after both, in alphabetical order.
  pair = a: b: if a < b then "${a}-${b}" else "${b}-${a}";

  # This host is the member named after it and peers with all the others.
  members = lib.codgician.published.wireguard;
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
          privateKeyFile = secret "wg-private-key-${hostName}";
          ips = [
            "${self.ipv4}/23"
            "${self.ipv6}/48"
          ];
          mtu = 1380;
          allowedIPsAsRoutes = true;
          listenPort = self.port;
          peers = lib.mapAttrsToList (name: peer: {
            inherit name;
            inherit (peer) publicKey;
            allowedIPs = [
              "${peer.ipv4}/32"
              "${peer.ipv6}/128"
            ]
            ++ peer.routes;
            endpoint =
              if peer.domain == null || peer.port == null then null else "${peer.domain}:${toString peer.port}";
            presharedKeyFile = secret "wg-preshared-key-${pair hostName name}";
            persistentKeepalive = 25;
            dynamicEndpointRefreshSeconds = 5;
          }) (removeAttrs members [ hostName ]);
        };
        useNetworkd = false; # See: https://github.com/systemd/systemd/issues/9911
      };

      firewall.allowedUDPPorts = [ self.port ];
    };
  };
}
