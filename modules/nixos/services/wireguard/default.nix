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

  memberNames = builtins.attrNames members;
  interfaces = builtins.attrValues cfg.interfaces;

  ports = lib.unique (
    builtins.filter (port: port != null) (map (intCfg: members.${intCfg.host}.port) interfaces)
  );

  # Secrets an interface reads that this host is not a recipient of.
  missingSecrets =
    intCfg:
    builtins.filter (name: !(config.codgician.secrets.files ? ${name})) (
      [ "wg-private-key-${intCfg.host}" ]
      ++ map (peer: "wg-preshared-key-${pair intCfg.host peer}") intCfg.peers
    );
in
{
  options.codgician.services.wireguard = {
    enable = lib.mkEnableOption "WireGuard.";

    openFirewall = lib.mkEnableOption "Open firewall for WireGuard ports.";

    interfaces = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            host = lib.mkOption {
              type = lib.types.enum memberNames;
              description = "Member of the mesh this interface acts as.";
            };

            peers = lib.mkOption {
              type = lib.types.listOf (lib.types.enum memberNames);
              description = "Members of the mesh this interface peers with.";
            };

            mtu = lib.mkOption {
              type = lib.types.int;
              default = 1380;
              description = "MTU for the interface.";
            };

            allowedIPsAsRoutes = lib.mkEnableOption "adding the allowed IPs of peers as routes";
          };
        }
      );
      default = { };
      description = "WireGuard interface configurations.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      wireguard-tools
    ];

    networking = {
      wireguard = {
        # An interface lacking its secrets is left out; the assertion below reports it.
        interfaces = builtins.mapAttrs (
          _: intCfg:
          let
            self = members.${intCfg.host};
          in
          {
            privateKeyFile = secret "wg-private-key-${intCfg.host}";
            ips = [
              "${self.ipv4}/23"
              "${self.ipv6}/48"
            ];
            inherit (intCfg) mtu allowedIPsAsRoutes;
            listenPort = self.port;
            peers = map (
              name:
              let
                peer = members.${name};
              in
              {
                inherit name;
                inherit (peer) publicKey;
                allowedIPs = [
                  "${peer.ipv4}/32"
                  "${peer.ipv6}/128"
                ]
                ++ peer.routes;
                endpoint =
                  if peer.domain == null || peer.port == null then null else "${peer.domain}:${toString peer.port}";
                presharedKeyFile = secret "wg-preshared-key-${pair intCfg.host name}";
                persistentKeepalive = 25;
                dynamicEndpointRefreshSeconds = 5;
              }
            ) intCfg.peers;
          }
        ) (lib.filterAttrs (_: intCfg: missingSecrets intCfg == [ ]) cfg.interfaces);
        useNetworkd = false; # See: https://github.com/systemd/systemd/issues/9911
      };

      firewall.allowedUDPPorts = lib.mkIf cfg.openFirewall ports;
    };

    # A member with networks behind it routes between them and the mesh and
    # answers ARP and NDP for the peers behind it.
    boot.kernel.sysctl = lib.mkIf (lib.any (intCfg: members.${intCfg.host}.routes != [ ]) interfaces) {
      "net.ipv4.conf.all.forwarding" = "1";
      "net.ipv4.conf.all.proxy_arp" = "1";
      "net.ipv6.conf.all.forwarding" = "1";
      "net.ipv6.conf.all.proxy_ndp" = "1";
    };

    assertions = [
      {
        assertion = cfg.interfaces != { };
        message = "WireGuard: ${hostName} enables WireGuard without interfaces; set codgician.services.wireguard.interfaces.<name>.host to one of the members (${lib.concatStringsSep ", " memberNames}).";
      }
    ]
    ++ lib.concatLists (
      lib.mapAttrsToList (
        name: intCfg:
        let
          missing = missingSecrets intCfg;
        in
        [
          {
            assertion = !(lib.elem intCfg.host intCfg.peers);
            message = "WireGuard: ${name} acts as ${intCfg.host}, which must not be in its own peers list.";
          }
          {
            assertion = missing == [ ];
            message = "WireGuard: ${name} acts as ${intCfg.host}, but ${hostName} is not a recipient of ${lib.concatStringsSep ", " missing} in secrets/secrets.nix.";
          }
        ]
      ) cfg.interfaces
    );
  };
}
