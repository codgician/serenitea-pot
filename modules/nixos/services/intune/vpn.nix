{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.intune;
  connectionUuid = "b77a07c7-41b1-4932-b47e-c0d8fdd84c1e";
  plugin = pkgs.nur.repos.codgician.networkmanager-gpclient;
  singBoxTun = config.codgician.services.sing-box.tun;
  edge = pkgs.writeShellScript "msftvpn-edge" ''
    exec ${pkgs.microsoft-edge}/bin/microsoft-edge-stable --profile-directory='Profile 1' "$@"
  '';
  # External gateways offered by the msftvpn-alt portal, in portal order.
  gateways = [
    "Redmond-WA"
    "Beijing-CN"
    "London-GB"
    "Hyderabad-IN"
    "Sydney-AU"
    "Singapore-SG"
    "Cheyenne-WY"
    "Shanghai-CN"
    "Herzelia-IS"
    "Munich-DE"
    "Dublin-IR"
    "Irving-TX"
    "Bay-CA"
    "SaoPaulo-BR"
    "Tokyo-JP"
    "Boydton-VA"
  ];
  # Entry format the plugin caches: "<name> (<address>)".
  gatewayEntry =
    name:
    let
      city = lib.toLower (lib.head (lib.splitString "-" name));
    in
    "${name} (${city}.msftvpn-alt.ras.microsoft.com)";
in
{
  options.codgician.services.intune.vpn = {
    enable = lib.mkEnableOption "NetworkManager GlobalProtect VPN with Microsoft Edge authentication";

    gateway = lib.mkOption {
      type = lib.types.enum gateways;
      default = "Shanghai-CN";
      description = "GlobalProtect gateway to connect through.";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.vpn.enable) {
    networking.networkmanager = {
      enable = true;
      plugins = [ plugin ];
      ensureProfiles.profiles.msftvpn = {
        connection = {
          id = "msftvpn";
          uuid = connectionUuid;
          type = "vpn";
          autoconnect = false;
        };
        vpn = {
          service-type = "org.freedesktop.NetworkManager.gpclient";
          gateway = "https://msftvpn-alt.ras.microsoft.com";
          auth-mode = "saml";
          browser = toString edge;
          fix-openssl = "true";
          hip = "false";
          # A declared list lets the plugin pass --gateway directly instead of
          # answering gpclient's gateway prompt, and feeds the editor drop-down.
          preferred-gateway = gatewayEntry cfg.vpn.gateway;
          gateway-list = lib.concatMapStringsSep ";" gatewayEntry gateways;
          gateway-list-count = toString (lib.length gateways);
        };
        ipv4.method = "auto";
        ipv6.method = "auto";
      };

      # The VPN is a full tunnel, but sing-box's TUN policy rules take precedence
      # over its default route and DNS. Stop sing-box while the VPN is up, and
      # restart it afterwards only if it was running.
      dispatcherScripts = lib.optional singBoxTun.enable {
        source = lib.getExe (
          pkgs.writeShellApplication {
            name = "msftvpn-sing-box";
            runtimeInputs = [
              pkgs.coreutils
              config.systemd.package
            ];
            text = ''
              [ "''${CONNECTION_UUID:-}" = ${connectionUuid} ] || exit 0
              marker=/run/msftvpn-stopped-sing-box
              case "$2" in
                vpn-up)
                  if systemctl is-active --quiet sing-box.service; then
                    touch "$marker"
                    systemctl stop sing-box.service
                  fi
                  ;;
                vpn-down)
                  if [ -e "$marker" ]; then
                    rm "$marker"
                    systemctl start sing-box.service
                  fi
                  ;;
              esac
            '';
          }
        );
      };
    };

    # Start through systemd rather than inheriting NetworkManager's read-only
    # home namespace: Edge must use the existing signed-in work profile.
    systemd.services.nm-gpclient.wantedBy = [ "multi-user.target" ];

    # vpnc-script hooks: routing edits the split lists on connect and disconnect;
    # notify reports the configured tunnel to the plugin, which tells NetworkManager.
    environment.etc = {
      "vpnc/connect.d/90-gpclient-routing".source = "${plugin}/${plugin.routingHook}";
      "vpnc/disconnect.d/90-gpclient-routing".source = "${plugin}/${plugin.routingHook}";
      "vpnc/post-connect.d/90-gpclient-notify".source = "${plugin}/${plugin.notifyHook}";
      "vpnc/reconnect.d/90-gpclient-notify".source = "${plugin}/${plugin.notifyHook}";
    };

    # The plugin's gpclient supplies the globalprotectcallback desktop handler.
    environment.systemPackages = [ plugin.gpclient ];
    # Connection profiles and the user's existing Edge profile are already
    # persisted by the common impermanence configuration. VPN state is ephemeral.
  };
}
