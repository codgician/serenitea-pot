{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.intune;
  connectionUuid = "b77a07c7-41b1-4932-b47e-c0d8fdd84c1e";
  edge = pkgs.writeShellScript "msftvpn-edge" ''
    exec ${pkgs.microsoft-edge}/bin/microsoft-edge-stable --profile-directory='Profile 1' "$@"
  '';
in
{
  options.codgician.services.intune.vpn.enable =
    lib.mkEnableOption "NetworkManager GlobalProtect VPN with Microsoft Edge authentication";

  config = lib.mkIf (cfg.enable && cfg.vpn.enable) {
    networking.networkmanager = {
      enable = true;
      plugins = [ pkgs.nur.repos.codgician.networkmanager-gpclient ];
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
        };
        ipv4.method = "auto";
        ipv6.method = "auto";
      };
    };

    # Start through systemd rather than inheriting NetworkManager's read-only
    # home namespace: Edge must use the existing signed-in work profile.
    systemd.services.nm-gpclient.wantedBy = [ "multi-user.target" ];

    environment.etc."vpnc/connect.d/90-gpclient-routing".source =
      "${pkgs.nur.repos.codgician.networkmanager-gpclient}/libexec/gpclient/90-gpclient-routing";

    # gpclient supplies the existing globalprotectcallback desktop handler.
    environment.systemPackages = [
      pkgs.gpclient
    ];
    # Connection profiles and the user's existing Edge profile are already
    # persisted by the common impermanence configuration. VPN state is ephemeral.
  };
}
