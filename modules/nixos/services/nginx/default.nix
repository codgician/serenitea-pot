{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.nginx;
  types = lib.types;
  inherit (config.codgician) inventory;
  inherit (config.networking) hostName;
  autheliaApiPath = "/internal/authelia/authz";

  anubisSocket =
    name: "http://unix:/run/anubis/anubis-${builtins.replaceStrings [ "." ] [ "-" ] name}/anubis.sock";

  # A location that says what it serves keeps that; any other one goes to
  # the vhost's upstream.
  servesItself =
    location: location ? proxyPass || location ? root || location ? alias || location ? return;
  locationsOf = vhost: { "/" = { }; } // vhost.locations;

  # What this host answers for: the sites it has an upstream for, the sites
  # it fronts, and its landing page.
  served = lib.mapAttrs (_: site: {
    inherit (site) domains proxyPass locations;
    authelia = site.authelia != null;
    anubis = false;
  }) (lib.filterAttrs (_: site: site.proxyPass != null) cfg.reverseProxies);

  fronted = lib.mapAttrs (name: front: {
    domains = cfg.reverseProxies.${name}.domains or [ ];
    locations = cfg.reverseProxies.${name}.locations or { };
    inherit (front) proxyPass anubis;
    # The vhost next to the backend asks Authelia.
    authelia = false;
  }) cfg.fronts;

  landing = lib.optionalAttrs (cfg.landingPage != null) {
    ${cfg.landingPage.domain} = {
      domains = [
        cfg.landingPage.domain
        "*.${cfg.landingPage.domain}"
      ];
      proxyPass = null;
      locations."/".root = import ./landing-page.nix {
        inherit lib pkgs;
        inherit (cfg.landingPage) footer;
        name = "${hostName}-web";
      };
      authelia = false;
      anubis = false;
    };
  };

  # A vhost without a domain or without anything to serve at `/` is reported
  # by an assertion below instead of failing somewhere in its consumers.
  hasRoot = vhost: vhost.proxyPass != null || servesItself (vhost.locations."/" or { });
  declared = landing // served // fronted;
  vhosts = lib.filterAttrs (_: vhost: vhost.domains != [ ] && hasRoot vhost) declared;

  siteModule =
    { name, ... }:
    let
      service = inventory.services.${name} or null;
    in
    {
      options = {
        domains = lib.mkOption {
          type = types.listOf types.str;
          default = lib.optional (inventory.vhostDomains ? ${name}) inventory.vhostDomains.${name};
          example = [
            "example.com"
            "example.org"
          ];
          description = "Server names; the first one names the certificate.";
        };

        authelia = lib.mkOption {
          type = types.nullOr (
            types.submodule {
              options = {
                users = lib.mkOption {
                  type = types.listOf types.str;
                  default = [ ];
                  description = "Only these users.";
                };
                groups = lib.mkOption {
                  type = types.listOf types.str;
                  default = [ ];
                  description = "Only members of these groups.";
                };
                anyone = lib.mkOption {
                  type = types.bool;
                  default = false;
                  description = "Every signed-in user.";
                };
              };
            }
          );
          default = if service == null then null else service.authelia;
          example = {
            groups = [ "staff" ];
          };
          description = ''
            Who may pass. Null for no login. Otherwise the host that serves
            the site asks Authelia for a session before every location, and
            Authelia admits `users` and `groups` only, or `anyone` who is
            signed in. Either subjects or `anyone`.
          '';
        };

        proxyPass = lib.mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "http://127.0.0.1:8000";
          description = ''
            Upstream of every location that does not say what else it serves.
            The host that sets it serves the site.
          '';
        };

        locations = lib.mkOption {
          type = with types; attrsOf (attrsOf anything);
          default = { };
          example = lib.literalExpression ''
            {
              "/api/".extraConfig = "proxy_buffering off;";
              "= /favicon.ico".root = ./static;
            }
          '';
          description = ''
            Settings of `services.nginx.virtualHosts.<name>.locations`. A
            location goes to the upstream unless it sets `proxyPass` (`null`
            for none), `root`, `alias` or `return`.
          '';
        };
      };
    };

  frontModule.options = {
    proxyPass = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "https://192.0.2.10";
      description = "Where the host that serves the site is reached.";
    };

    anubis = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Put Anubis in front of the upstream.";
    };
  };

  mkLocationConfig =
    name: vhost: location:
    let
      proxyPass =
        if vhost.anubis then
          anubisSocket name
        else if servesItself location then
          location.proxyPass or null
        else
          vhost.proxyPass;
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
          + (lib.optionalString vhost.authelia ''
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
        (builtins.mapAttrs (_: mkLocationConfig name vhost) (locationsOf vhost))
        { "/robots.txt".return = ''200 ""''; }
      ]
      # Anubis static assets - must be proxied to Anubis
      ++ (lib.optional vhost.anubis {
        "/.within.website/" = {
          proxyPass = anubisSocket name;
          proxyWebsockets = true;
        };
      })
      ++ (lib.optional vhost.authelia {
        "${autheliaApiPath}" = {
          proxyPass = inventory.autheliaUrl + "/api/authz/auth-request"; # Use auth-request endpoint
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
            proxy_ssl_server_name on;
            proxy_ssl_name $proxy_host;
          '';
        };
      })
    );
    forceSSL = true;
    useACMEHost = serverName;
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

    landingPage = lib.mkOption {
      type = types.nullOr (
        types.submodule {
          options = {
            domain = lib.mkOption {
              type = types.str;
              description = "Apex domain; the page is also the fallback for its subdomains.";
            };
            footer = lib.mkOption {
              type = types.str;
              description = "HTML shown below the artwork.";
            };
          };
        }
      );
      default = null;
      description = "Static landing page of a public host.";
    };

    reverseProxies = lib.mkOption {
      type = types.attrsOf (types.submodule siteModule);
      default = { };
      example = lib.literalExpression ''
        {
          jellyfin = {
            domains = [ "fin.example.org" ];
            proxyPass = "http://127.0.0.1:8096";
          };
        }
      '';
      description = ''
        Sites, by name. The module that owns a site says what it is
        (`domains`, `authelia`, the locations every hop needs) outside its
        `enable`, so that every host knows it. The site is an HTTPS virtual
        host on the host that sets `proxyPass`: the module does where the
        service is enabled, a host does for something without a module.
        NGINX, its firewall ports and the certificates follow.
      '';
    };

    fronts = lib.mkOption {
      type = types.attrsOf (types.submodule frontModule);
      default = { };
      example = lib.literalExpression ''
        {
          jellyfin.proxyPass = "https://192.0.2.10";
        }
      '';
      description = ''
        Sites of `reverseProxies` that another host serves and this host is
        the public entry of, by the site's name. The virtual host takes its
        domains and locations from the site and does not ask Authelia: the
        host that serves the site does.
      '';
    };
  };

  config = lib.mkMerge [
    {
      # Until every module declares its own site.
      codgician.services.nginx.reverseProxies = lib.mapAttrs (_: _: { }) inventory.services;

      assertions =
        lib.mapAttrsToList (name: site: {
          assertion =
            site.authelia == null
            || (site.authelia.users ++ site.authelia.groups != [ ]) != site.authelia.anyone;
          message = ''
            nginx: reverseProxies.${name}.authelia needs `users` or `groups`, or `anyone = true`, and not both.
          '';
        }) cfg.reverseProxies
        ++ lib.mapAttrsToList (name: _: {
          assertion = !served ? ${name};
          message = ''
            nginx: this host fronts "${name}" and serves it as well.
          '';
        }) cfg.fronts
        ++ lib.concatLists (
          lib.mapAttrsToList (name: vhost: [
            {
              assertion = vhost.domains != [ ];
              message = ''
                nginx: "${name}" has no domain. The module or host that owns the site sets `reverseProxies.${name}.domains`; check the spelling of the name.
              '';
            }
            {
              assertion = hasRoot vhost;
              message = ''
                nginx: "${name}" has nothing to serve at "/". Set `proxyPass`, or make the "/" location serve something.
              '';
            }
          ]) declared
        );
    }

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
      ) vhosts;

      # Add nginx user to www-data group
      users.groups."www-data".members = [ "nginx" ];
    })
  ];
}
