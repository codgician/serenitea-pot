{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.nginx;
  types = lib.types;
  inherit (config.networking) hostName;
  autheliaApiPath = "/internal/authelia/authz";

  anubisSocket =
    name: "http://unix:/run/anubis/anubis-${builtins.replaceStrings [ "." ] [ "-" ] name}/anubis.sock";

  # A location that says what it serves keeps that; any other one goes to
  # the vhost's upstream.
  servesItself =
    location: location ? proxyPass || location ? root || location ? alias || location ? return;
  locationsOf = vhost: { "/" = { }; } // vhost.locations;

  # What this host answers for: the sites it has an upstream for and its
  # landing page.
  served = lib.mapAttrs (_: site: {
    inherit (site)
      domains
      proxyPass
      locations
      anubis
      ;
    authelia = site.authelia != null;
  }) (lib.filterAttrs (_: site: site.proxyPass != null) cfg.reverseProxies);

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
  hasRoot =
    vhost:
    let
      root = vhost.locations."/" or { };
    in
    if vhost.anubis || !servesItself root then
      vhost.proxyPass != null
    else
      (root.proxyPass or null) != null || root ? root || root ? alias || root ? return;
  declared = landing // served;
  vhosts = lib.filterAttrs (_: vhost: vhost.domains != [ ] && hasRoot vhost) declared;

  siteModule = {
    options = {
      domains = lib.mkOption {
        type = types.listOf types.str;
        default = [ ];
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
        default = null;
        example = {
          groups = [ "staff" ];
        };
        description = ''
          Who may pass. Null for no login. Otherwise every host that proxies
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
          Upstream of every location that does not say what else it serves:
          the backend on the host next to it, or where that host is reached
          on a host that is the public entry of the site. The host that sets
          it has a virtual host for the site.
        '';
      };

      anubis = lib.mkOption {
        type = types.bool;
        default = false;
        description = "Put Anubis in front of the upstream on this host.";
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
          proxyPass = config.codgician.services.authelia.instances.main.url + "/api/authz/auth-request"; # Use auth-request endpoint
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
  imports = [ ./sites.nix ];

  options.codgician.services.nginx = {
    enable = lib.mkEnableOption "nginx";

    openFirewall = lib.mkEnableOption "Open port 80 and 443 in firewall configuration.";

    package = lib.mkPackageOption pkgs "nginx" { default = "nginxMainlineEch"; };

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
        `enable`, so that every host knows it; `sites.nix` does for sites
        without a module. The site is an HTTPS virtual host on every host
        that sets `proxyPass`: the module does where the service is enabled,
        a host does in its own files where it is the public entry of a site
        another host serves, or for something without a module. Such a host
        sets `enable` (and `openFirewall` to be reached); the certificates
        follow.
      '';
    };
  };

  config = lib.mkMerge [
    {
      assertions =
        lib.mapAttrsToList (name: site: {
          assertion =
            site.authelia == null
            || (site.authelia.users ++ site.authelia.groups != [ ]) != site.authelia.anyone;
          message = ''
            nginx: reverseProxies.${name}.authelia needs `users` or `groups`, or `anyone = true`, and not both.
          '';
        }) cfg.reverseProxies
        ++ lib.concatLists (
          lib.mapAttrsToList (name: vhost: [
            {
              assertion = vhost.domains != [ ];
              message = ''
                nginx: "${name}" has no domain. The module that owns the site, or `sites.nix` in the nginx module for a site without one, sets `reverseProxies.${name}.domains`; check the spelling of the name.
              '';
            }
            {
              assertion = hasRoot vhost;
              message = ''
                nginx: "${name}" has nothing to serve at "/". Set `proxyPass`, or make the "/" location serve something.
              '';
            }
          ]) declared
        )
        ++ lib.mapAttrsToList (name: _: {
          assertion = cfg.enable;
          message = ''
            nginx: this host serves "${name}" but does not enable NGINX. Set `codgician.services.nginx.enable = true`.
          '';
        }) vhosts;
    }

    (lib.mkIf cfg.enable {
      services.nginx = {
        enable = true;
        inherit (cfg) package;
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
      };

      codgician.services.grafana.provision.dashboards = [ ../grafana/dashboards/nginx.json ];

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
