{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.nginx;
  types = lib.types;

  # Make location configuration
  mkLocationConfig = serverName: locationName: locationCfg: {
    inherit (locationCfg)
      proxyPass
      return
      root
      alias
      ;
    proxyWebsockets = true;
    extraConfig =
      locationCfg.extraConfig
      # Enhance https reverse proxy security
      + (
        with locationCfg;
        lib.optionalString (sslVerify.enable && proxyPass != null && lib.hasPrefix "https://" proxyPass) ''
          proxy_ssl_server_name on;
          proxy_ssl_name ${if sslVerify.sslName == null then serverName else sslVerify.sslName};
          proxy_ssl_verify on;
          proxy_ssl_trusted_certificate ${sslVerify.trustedCertificate};
        ''
      )
      # If only allow connections from lan
      + (lib.optionalString locationCfg.lanOnly ''
        allow 10.0.0.0/8;
        allow 172.16.0.0/12;
        allow 192.168.0.0/16;
        allow fc00::/7;
        deny all;
      '');
  };

  # Make virtual host configuration
  mkVirtualHostConfig = _: hostCfg: rec {
    serverName = builtins.head hostCfg.domains;
    serverAliases = builtins.tail hostCfg.domains;
    locations =
      (builtins.mapAttrs (mkLocationConfig serverName) hostCfg.locations)
      // lib.optionalAttrs (hostCfg.robots != null) {
        "/robots.txt".return = ''200 "${lib.replaceStrings [ "\n" ] [ "\\n" ] hostCfg.robots}"'';
      };
    forceSSL = hostCfg.https;
    useACMEHost = lib.mkIf hostCfg.https serverName;
    http2 = true;
    http3 = true;
    http3_hq = true;
    quic = true;
    kTLS = true;
    acmeRoot = null;
  };
in
{
  options.codgician.services.nginx = {
    enable = lib.mkEnableOption ''
      Enable nginx service.
    '';

    openFirewall = lib.mkEnableOption "Open port 80 and 443 in firewall configuration.";

    reverseProxies = lib.mkOption {
      type = types.attrsOf (types.submodule (import ./reverse-proxy-options.nix { inherit lib pkgs; }));
      default = { };
      example = lib.literalExpression ''
        {
          "myService" = {
            enable = true;
            https = true;
            domains = [ "myservice.example.org" ];
            locations."/".proxyPass = "http://127.0.0.1:8000";
          };
        }
      '';
      description = "Reverse proxy configurations.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Nginx configurations
    services.nginx = {
      enable = true;
      package = pkgs.nginxQuic;
      recommendedProxySettings = true;
      statusPage = true;

      resolver = {
        valid = "30s";
        ipv6 = true;
        addresses = [
          "1.1.1.1"
          "1.0.0.1"
          "[2606:4700:4700::1111]"
          "[2606:4700:4700::1001]"
        ];
      };

      virtualHosts = (builtins.mapAttrs mkVirtualHostConfig cfg.reverseProxies) // {
        _ = {
          default = true;
          locations."~ .*".return = "404";
          rejectSSL = true;
        };
      };
    };

    # Open firewall
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [
        80
        443
      ];
      allowedUDPPorts = [
        80
        443
      ];
    };

    # Monitoring
    services.prometheus.exporters = {
      nginx.enable = true;
      nginxlog.enable = true;
    };

    # ACME settings
    codgician.acme =
      with lib;
      mapAttrs' (
        _: hostCfg:
        nameValuePair (builtins.head hostCfg.domains) {
          enable = true;
          extraDomainNames = builtins.tail hostCfg.domains;
        }
      ) cfg.reverseProxies;

    # Add nginx user to www-data group
    users.groups."www-data".members = [ "nginx" ];

    # Assertions
    assertions = lib.mapAttrsToList (hostName: hostCfg: {
      assertion = !hostCfg.enable || hostCfg.domains != [ ];
      message = ''
        nginx: You have to provide at least one domain for nginx reverse proxy virtual host "${hostName}".
      '';
    }) cfg.reverseProxies;
  };
}
