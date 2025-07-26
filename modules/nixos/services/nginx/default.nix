{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.nginx;
  types = lib.types;
  autheliaApiPath = "/internal/authelia/authz";

  # Make location configuration
  mkLocationConfig =
    hostCfg: locationCfg:
    lib.mkMerge [
      locationCfg.passthru
      {
        proxyWebsockets = true;
        extraConfig =
          # Enhance https reverse proxy security
          (lib.optionalString
            (
              locationCfg.passthru.proxyPass or null != null
              && lib.hasPrefix "https://" locationCfg.passthru.proxyPass
            )
            (
              lib.optionalString locationCfg.ssl.proxySslName ''
                proxy_ssl_server_name on;
                proxy_ssl_name $host;
              ''
              + lib.optionalString locationCfg.ssl.verify ''
                proxy_ssl_verify on;
                proxy_ssl_trusted_certificate ${locationCfg.ssl.trustedCertificate};
                proxy_ssl_certificate_cache max=1000;
              ''
            )
          )
          # If only allow connections from lan
          + (lib.optionalString locationCfg.lanOnly ''
            allow 10.0.0.0/8;
            allow 172.16.0.0/12;
            allow 192.168.0.0/16;
            allow fc00::/7;
            deny all;
          '')
          # Authelia authentication
          + (lib.optionalString (hostCfg.authelia.enable && locationCfg.authelia.enable) ''
            auth_request ${autheliaApiPath};

            ## Save the upstream metadata response headers from Authelia to variables.
            auth_request_set $user $upstream_http_remote_user;
            auth_request_set $groups $upstream_http_remote_groups;
            auth_request_set $name $upstream_http_remote_name;
            auth_request_set $email $upstream_http_remote_email;

            ## Inject the metadata response headers from the variables into the request made to the backend.
            proxy_set_header Remote-User $user;
            proxy_set_header Remote-Groups $groups;
            proxy_set_header Remote-Email $email;
            proxy_set_header Remote-Name $name;

            ## Set the $redirection_url to the Location header of the response to the Authz endpoint.
            auth_request_set $redirection_url $upstream_http_location;

            ## Handle 401 errors - redirect to Authelia
            error_page 401 =302 $redirection_url;

            ## Set authelia policy
            auth_request_set $authelia_policy "${
              if locationCfg.authelia.policy == null then
                hostCfg.authelia.defaultPolicy
              else
                locationCfg.authelia.policy
            }";
          '');
      }
    ];

  # Make virtual host configuration
  mkVirtualHostConfig = _: hostCfg: rec {
    serverName = builtins.head hostCfg.domains;
    serverAliases = builtins.tail hostCfg.domains;
    locations = lib.mkMerge (
      [
        (builtins.mapAttrs (_: locationCfg: mkLocationConfig hostCfg locationCfg) hostCfg.locations)
      ]
      ++ (lib.optional (hostCfg.robots != null) {
        "/robots.txt".return = ''200 "${lib.replaceStrings [ "\n" ] [ "\\n" ] hostCfg.robots}"'';
      })
      ++ (lib.optional hostCfg.authelia.enable {
        "${autheliaApiPath}" = {
          proxyPass = hostCfg.authelia.url + "/api/authz/auth-request"; # Use auth-request endpoint
          recommendedProxySettings = false;
          extraConfig = ''
            internal;

            ## Headers
            proxy_set_header X-Original-Method $request_method;
            proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
            proxy_set_header X-Forwarded-For $remote_addr;
            proxy_set_header Content-Length "";
            proxy_set_header Connection "";

            ## Basic Proxy Configuration
            proxy_pass_request_body off;
            proxy_next_upstream error timeout invalid_header http_500 http_502 http_503; # Timeout if the real server is dead
            proxy_http_version 1.1;
            proxy_redirect http:// $scheme://;
            proxy_cache_bypass $cookie_session;
            proxy_no_cache $cookie_session;
            proxy_buffers 4 32k;
            client_body_buffer_size 128k;

            ## Trusted Proxies Configuration
            real_ip_header X-Forwarded-For;
            real_ip_recursive on;

            ## Advanced Proxy Configuration
            send_timeout 5m;
            proxy_read_timeout 240;
            proxy_send_timeout 240;
            proxy_connect_timeout 240;
          ''
          + (lib.optionalString (lib.hasPrefix "https://" hostCfg.authelia.url) ''
            proxy_ssl_server_name on;
            proxy_ssl_name $proxy_host;
          '');
        };
      })
    );
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
      type = types.attrsOf (types.submodule (import ./reverse-proxy-options.nix { inherit lib; }));
      default = { };
      example = lib.literalExpression ''
        {
          "myService" = {
            enable = true;
            https = true;
            domains = [ "myservice.example.org" ];
            locations."/".passthru.proxyPass = "http://127.0.0.1:8000";
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

      virtualHosts = lib.mkMerge [
        (builtins.mapAttrs mkVirtualHostConfig cfg.reverseProxies)
        {
          _ = {
            default = true;
            locations."/".return = "404";
            rejectSSL = true;
          };
        }
      ];
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
