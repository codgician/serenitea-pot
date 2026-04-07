{ config, lib, ... }:
let
  cfg = config.codgician.services.sing-box;
  tunCfg = cfg.tun;
  inherit (lib) types;
in
{
  options.codgician.services.sing-box.tun = {
    enable = lib.mkEnableOption "TUN-based split routing for sing-box";

    tag = lib.mkOption {
      type = types.str;
      default = "tun-in";
      description = "Tag name for the TUN inbound.";
    };

    interfaceName = lib.mkOption {
      type = types.str;
      default = "tun0";
      description = "Name of the TUN interface.";
    };

    mtu = lib.mkOption {
      type = types.int;
      default = 9000;
      description = "MTU for the TUN interface.";
    };

    address = lib.mkOption {
      type = with types; listOf str;
      default = [
        "172.19.0.1/30"
        "fdfe:dcba:9876::1/126"
      ];
      description = "Addresses assigned to the TUN interface (CIDR notation).";
    };

    stack = lib.mkOption {
      type = types.enum [
        "system"
        "gvisor"
        "mixed"
      ];
      default = "system";
      description = "Network stack for TUN. 'system' is most performant on Linux with capabilities.";
    };

    outbound = lib.mkOption {
      type = types.str;
      description = "Tag of the outbound to route matched traffic through.";
      example = "outbound-hysteria2";
    };

    routedRanges = lib.mkOption {
      type = with types; listOf str;
      default = [ ];
      description = "IP CIDR ranges to route through the proxy outbound.";
      example = [
        "192.168.0.0/16"
        "fd00:c0d9:1c00::/48"
      ];
    };
  };

  config = lib.mkIf tunCfg.enable {
    services.sing-box.settings = {
      # TUN inbound
      inbounds = [
        {
          type = "tun";
          tag = tunCfg.tag;
          interface_name = tunCfg.interfaceName;
          address = tunCfg.address;
          mtu = tunCfg.mtu;
          stack = tunCfg.stack;
          auto_route = true;
          strict_route = true;
          route_address = tunCfg.routedRanges;
        }
      ];

      # Route rules
      route = {
        default_domain_resolver.server = "local";
        rules = lib.optional (tunCfg.routedRanges != [ ]) {
          ip_cidr = tunCfg.routedRanges;
          outbound = tunCfg.outbound;
        };
        auto_detect_interface = true;
      };
    };

    # Prevent auto_route from hijacking system DNS via systemd-resolved.
    # sing-box registers the TUN as default DNS route; this networkd unit
    # overrides that so only explicitly configured domains use TUN DNS.
    systemd.network.networks."50-sing-box-tun" = {
      matchConfig.Name = tunCfg.interfaceName;
      networkConfig = {
        DNSDefaultRoute = false;
        KeepConfiguration = "yes";
      };
    };

    # Systemd capabilities for TUN
    systemd.services.sing-box.serviceConfig = {
      AmbientCapabilities = [
        "CAP_NET_ADMIN"
        "CAP_NET_RAW"
        "CAP_NET_BIND_SERVICE"
      ];
      CapabilityBoundingSet = [
        "CAP_NET_ADMIN"
        "CAP_NET_RAW"
        "CAP_NET_BIND_SERVICE"
      ];
    };

    assertions = [
      {
        assertion = tunCfg.enable -> tunCfg.outbound != "";
        message = "An outbound tag must be specified for TUN routing.";
      }
    ];
  };
}
