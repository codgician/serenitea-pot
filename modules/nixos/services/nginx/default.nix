{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.nginx;
  types = lib.types;
  inherit (lib.codgician) published;
  autheliaApiPath = "/internal/authelia/authz";
  vhosts = lib.filterAttrs (_: vhost: vhost.enable) cfg.reverseProxies;

  anubisSocket =
    name: "http://unix:/run/anubis/anubis-${builtins.replaceStrings [ "." ] [ "-" ] name}/anubis.sock";

  vhostModule =
    { config, ... }:
    {
      options = {
        enable = lib.mkEnableOption "this virtual host";

        domains = lib.mkOption {
          type = types.listOf types.str;
          example = [
            "example.com"
            "example.org"
          ];
          description = "Domains served; the first one names the certificate.";
        };

        https = lib.mkOption {
          type = types.bool;
          default = true;
          description = "Use https and auto-renew certificates.";
        };

        proxyPass = lib.mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "http://127.0.0.1:8000";
          description = "Upstream of the root location; other locations may refer to it.";
        };

        authelia = {
          enable = lib.mkEnableOption "an Authelia session check on every location";

          url = lib.mkOption {
            type = types.str;
            default = published.autheliaUrl;
            defaultText = lib.literalExpression "lib.codgician.published.autheliaUrl";
            description = "The URL of the Authelia.";
          };
        };

        anubis.enable = lib.mkEnableOption "Anubis bot protection in front of every location";

        locations = lib.mkOption {
          type = with types; attrsOf (attrsOf anything);
          default = { };
          example = lib.literalExpression ''
            {
              "/api/".extraConfig = "proxy_buffering off;";
            }
          '';
          description = "Passed to `services.nginx.virtualHosts.<name>.locations`.";
        };
      };

      config.locations = lib.mkIf (config.proxyPass != null) {
        "/".proxyPass = lib.mkDefault config.proxyPass;
      };
    };

  mkLocationConfig =
    name: vhost: location:
    let
      proxyPass = if vhost.anubis.enable then anubisSocket name else location.proxyPass or null;
    in
    lib.mkMerge [
      (location // { inherit proxyPass; })
      {
        proxyWebsockets = true;
        extraConfig =
          # Anubis is reached over a local socket, never over https
          (lib.optionalString (proxyPass != null && lib.hasPrefix "https://" proxyPass) ''
            proxy_ssl_server_name on;
            proxy_ssl_name $host;
            proxy_ssl_protocols TLSv1.3;
            proxy_ssl_verify on;
            proxy_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt;
            proxy_ssl_verify_depth 2;
            proxy_ssl_session_reuse off;
          '')
          + (lib.optionalString vhost.authelia.enable ''
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
          '');
      }
    ];

  mkVirtualHostConfig = name: vhost: rec {
    serverName = builtins.head vhost.domains;
    serverAliases = builtins.tail vhost.domains;
    locations = lib.mkMerge (
      [
        (builtins.mapAttrs (_: mkLocationConfig name vhost) vhost.locations)
        { "/robots.txt".return = ''200 ""''; }
      ]
      # Anubis static assets - must be proxied to Anubis
      ++ (lib.optional vhost.anubis.enable {
        "/.within.website/" = {
          proxyPass = anubisSocket name;
          proxyWebsockets = true;
        };
      })
      ++ (lib.optional vhost.authelia.enable {
        "${autheliaApiPath}" = {
          proxyPass = vhost.authelia.url + "/api/authz/auth-request"; # Use auth-request endpoint
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
          + (lib.optionalString (lib.hasPrefix "https://" vhost.authelia.url) ''
            proxy_ssl_server_name on;
            proxy_ssl_name $proxy_host;
          '');
        };
      })
    );
    forceSSL = vhost.https;
    useACMEHost = lib.mkIf vhost.https serverName;
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
    trustedProxies = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Addresses or CIDRs from which NGINX accepts X-Forwarded-For client addresses.";
    };

    reverseProxies = lib.mkOption {
      type = types.attrsOf (types.submodule vhostModule);
      default = { };
      example = lib.literalExpression ''
        {
          "example.org" = {
            enable = true;
            domains = [ "example.org" ];
            proxyPass = "http://127.0.0.1:8000";
          };
        }
      '';
      description = ''
        Virtual hosts. The inventory's service table enables one for every
        service this host runs or fronts; modules and hosts add locations to
        those, or declare vhosts of their own. NGINX runs when any is enabled.
      '';
    };
  };

  config = lib.mkMerge [
    { codgician.services.nginx.reverseProxies = published.vhostsFor config.networking.hostName; }

    (lib.mkIf (vhosts != { }) {
      services.nginx = {
        enable = true;
        package = pkgs.nginxMainlineEch;
        recommendedProxySettings = true;
        statusPage = true;

        commonHttpConfig = lib.mkAfter (
          lib.optionalString (cfg.trustedProxies != [ ]) ''
            ${lib.concatMapStringsSep "\n" (proxy: "set_real_ip_from ${proxy};") cfg.trustedProxies}
            real_ip_header X-Forwarded-For;
            real_ip_recursive on;
          ''
        );

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
          (builtins.mapAttrs mkVirtualHostConfig vhosts)
          {
            _ = {
              default = true;
              locations."/".return = "404";
              rejectSSL = true;
            };
          }
        ];
      };

      networking.firewall = {
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
      };

      codgician.acme = lib.mapAttrs' (
        _: vhost:
        lib.nameValuePair (builtins.head vhost.domains) {
          enable = true;
          extraDomainNames = builtins.tail vhost.domains;
        }
      ) (lib.filterAttrs (_: vhost: vhost.https) vhosts);

      # Add nginx user to www-data group
      users.groups."www-data".members = [ "nginx" ];
    })
  ];
}
