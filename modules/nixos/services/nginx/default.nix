{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.nginx;
  types = lib.types;
  reverseProxyNames = builtins.attrNames cfg.reverseProxies;

  # Make location configuration
  mkLocationConfig =
    host: location:
    let
      locationCfg = cfg.reverseProxies.${host}.locations.${location};
    in
    {
      inherit (locationCfg)
        proxyPass
        return
        root
        alias
        ;
      proxyWebsockets = true;
      extraConfig =
        locationCfg.extraConfig
        + (lib.optionalString locationCfg.lanOnly ''
          allow 10.0.0.0/8;
          allow 172.16.0.0/12;
          allow 192.168.0.0/16;
          allow fc00::/7;
          deny all;
        '');
    };

  # Make virtual host configuration
  mkVirtualHostConfig =
    host:
    let
      hostCfg = cfg.reverseProxies.${host};
    in
    {
      "${host}" = rec {
        inherit (hostCfg) default;
        serverName = builtins.head hostCfg.domains;
        serverAliases = builtins.tail hostCfg.domains;
        locations =
          (builtins.mapAttrs (k: _: mkLocationConfig host k) hostCfg.locations)
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
    };

  # Make ACME configurations
  mkAcmeConfig =
    host:
    let
      hostCfg = cfg.reverseProxies.${host};
    in
    lib.optionalAttrs hostCfg.https {
      "${builtins.head hostCfg.domains}" = {
        enable = true;
        extraDomainNames = builtins.tail hostCfg.domains;
      };
    };

  # Make reverse proxy assertions
  mkAssertions =
    host:
    let
      hostCfg = cfg.reverseProxies.${host};
    in
    [
      {
        assertion = !hostCfg.enable || hostCfg.domains != [ ];
        message = ''
          You have to provide at least one domain for nginx reverse proxy virtual host "${hostCfg}".
        '';
      }
    ];
in
{
  options.codgician.services.nginx = {
    enable = lib.mkEnableOption ''
      Enable nginx service.
    '';

    openFirewall = lib.mkEnableOption "Open port 80 and 443 in firewall configuration.";

    reverseProxies = lib.mkOption {
      type = types.attrsOf (types.submodule (import ./reverse-proxy-options.nix { inherit lib; }));
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

      virtualHosts =
        (lib.pipe reverseProxyNames [
          (builtins.map mkVirtualHostConfig)
          lib.codgician.concatAttrs
        ])
        // {
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
    codgician.acme = lib.pipe reverseProxyNames [
      (builtins.map mkAcmeConfig)
      lib.codgician.concatAttrs
    ];

    # Assertions
    assertions = lib.pipe reverseProxyNames [
      (builtins.map mkAssertions)
      builtins.concatLists
    ];
  };
}
