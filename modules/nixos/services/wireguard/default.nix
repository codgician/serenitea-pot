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

  inherit (lib.codgician) zone;

  # Members of the mesh: hosts of this flake and routers it does not build.
  # `domain` and `port` are where a member listens (a member without them
  # only dials out), `routes` the networks behind it.
  members =
    lib.mapAttrs
      (
        _: member:
        {
          domain = null;
          port = null;
          routes = [ ];
        }
        // member
      )
      {
        furina = {
          ipv4 = "192.168.254.254";
          ipv6 = "fd00:c0d9:1cff::254";
          publicKey = "90o8pyE8uvb+MAjCvHzxgQKu+yMtbie5cXtSnldoJSk=";
        };
        lumidouce = {
          ipv4 = "192.168.254.1";
          ipv6 = "fd00:c0d9:1cff::1";
          publicKey = "1QYPFw1YL0Px4+41YvBLX4qgXH4KTz9JOqzNbMnlgR8=";
          domain = "sz.${zone}";
          port = 51821;
          routes = [
            "192.168.0.0/24"
            "fd00:c0d9:1c00::/48"
          ];
        };
        lumine = {
          ipv4 = "192.168.254.64";
          ipv6 = "fd00:c0d9:1cff::64";
          publicKey = "bbtSDKEOb2Odofwwv215lllLckAOkdI0Mh9ZxuiQQUw=";
          domain = "lumine.${zone}";
          port = 51820;
          routes = [
            "192.168.64.0/24"
            "fd00:c0d9:1c64::/48"
          ];
        };
        qiaoying = {
          ipv4 = "192.168.254.6";
          ipv6 = "fd00:c0d9:1cff::6";
          publicKey = "suqw1v+IDCnupiBU0pHex25qQtb1En2DwofDKoZQrU0=";
          domain = "cd.${zone}";
          port = 51821;
          routes = [
            "192.168.6.0/24"
            "fd00:c0d9:1c06::/48"
          ];
        };
        xianyun = {
          ipv4 = "192.168.254.72";
          ipv6 = "fd00:c0d9:1cff::72";
          publicKey = "Uw99L+A6C9/cEzPmowLT8vC+cELdhcXAs61rjHb1hyY=";
          domain = "xianyun.${zone}";
          port = 51820;
          routes = [
            "192.168.72.0/24"
            "fd00:c0d9:1c72::/48"
          ];
        };
      };

  # This host is the member named after it and peers with all the others.
  self = members.${hostName};
in
{
  options.codgician.services.wireguard = {
    enable = lib.mkEnableOption "WireGuard mesh membership.";

    openFirewall = lib.mkEnableOption "Open firewall for WireGuard ports.";

    allowedIPsAsRoutes = lib.mkEnableOption ''
      Whether to add allowed IPs as routes or not.
    '';
  };

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
          inherit (cfg) allowedIPsAsRoutes;
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

      firewall.allowedUDPPorts = lib.mkIf cfg.openFirewall [ self.port ];
    };

    # A member routes between the mesh and its other networks and answers
    # ARP and NDP for the peers behind it.
    boot.kernel.sysctl = {
      "net.ipv4.conf.all.forwarding" = "1";
      "net.ipv4.conf.all.proxy_arp" = "1";
      "net.ipv6.conf.all.forwarding" = "1";
      "net.ipv6.conf.all.proxy_ndp" = "1";
    };
  };
}
