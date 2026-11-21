# Sites served next to their backend and through an entry host by the real
# nginx module: the vhosts it generates, the checks it makes and the access
# rules Authelia derives from the sites. Nginx itself is not run.
{ lib, pkgs, ... }:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  staticFiles = pkgs.writeTextDir "static/hello.txt" "static-content\n";

  # Ends in a zone the acme module knows.
  zone = "fixture.${lib.codgician.zone}";
  domain = name: "${name}.${zone}";

  # The shape of a service module: the site outside `enable`, with a location
  # every hop gets; the upstream inside.
  serviceModule =
    name:
    {
      port,
      authelia ? null,
    }:
    { config, lib, ... }:
    {
      options.codgician.services.${name}.enable = lib.mkEnableOption name;

      config = lib.mkMerge [
        {
          codgician.services.nginx.reverseProxies.${name} = {
            domains = [ (domain name) ];
            inherit authelia;
            locations."/shared/".extraConfig = ''
              add_header X-Shared ${name} always;
            '';
          };
        }

        (lib.mkIf config.codgician.services.${name}.enable {
          codgician.services.nginx.reverseProxies.${name}.proxyPass = "http://127.0.0.1:${toString port}";
        })
      ];
    };

  node = lib.codgician.mkNixosSystem {
    hostName = "reverse-proxy";
    inherit system;
    modules = [
      (serviceModule "routing" { port = 8081; })
      (serviceModule "members" {
        port = 8082;
        authelia.users = [ "alice" ];
      })
      # Served by another host; this one is its public entry.
      (serviceModule "remote" {
        port = 8082;
        authelia.groups = [ "staff" ];
      })
      {
        boot.loader.grub.device = "nodev";
        fileSystems."/" = {
          device = "/dev/vda";
          fsType = "ext4";
        };
        system.stateVersion = "26.05";
        codgician.secrets = {
          enable = false;
          files.cloudflare-credential = { };
        };
        security.acme.defaults.email = "reverse-proxy@example.invalid";

        codgician.services = {
          routing.enable = true;
          members.enable = true;

          nginx = {
            enable = true;
            openFirewall = true;

            reverseProxies = {
              # This host is the public entry of a site another host serves.
              remote.proxyPass = "http://127.0.0.1:8082";

              # What a host adds to a site.
              routing.locations = {
                "/".extraConfig = ''
                  add_header X-Location-Extra preserved always;
                '';
                "/inherited/" = { };
                "/custom/".proxyPass = "http://127.0.0.1:8082/mapped/";
                "/static/" = {
                  root = staticFiles;
                  tryFiles = "$uri =404";
                };
              };

              # A site without a module.
              appliance = {
                domains = [ (domain "appliance") ];
                authelia.anyone = true;
                proxyPass = "http://127.0.0.1:8082";
              };

              # The portal's site, here at a fixture domain.
              authelia-main = {
                domains = lib.mkForce [ (domain "auth") ];
                proxyPass = lib.mkForce "http://127.0.0.1:8083";
              };
            };
          };
        };
      }
    ];
  };

  nodeWith = module: (node.extendModules { modules = [ module ]; }).config;
  inherit (node.config.services.nginx) virtualHosts;
  sites = removeAttrs virtualHosts [
    "_"
    "localhost"
  ];

  # What the nginx module rejects, by the first line of its message.
  rejected =
    module:
    lib.sort lib.lessThan (
      map (failed: lib.head (lib.splitString "\n" failed.message)) (
        lib.filter (check: !check.assertion && lib.hasPrefix "nginx:" check.message)
          (nodeWith module).assertions
      )
    );

  hasLine = line: location: lib.hasInfix line (location.extraConfig or "");

  expectations = {
    "vhosts of the node" = {
      actual = lib.mapAttrs (_: vhost: {
        inherit (vhost) serverName forceSSL;
        root = vhost.locations."/".proxyPass;
        asksAuthelia = vhost.locations ? "/internal/authelia/authz";
        shared = vhost.locations ? "/shared/";
      }) sites;
      expected =
        let
          vhost = name: root: asksAuthelia: shared: {
            serverName = domain name;
            forceSSL = true;
            inherit root asksAuthelia shared;
          };
        in
        {
          appliance = vhost "appliance" "http://127.0.0.1:8082" true false;
          authelia-main = vhost "auth" "http://127.0.0.1:8083" false false;
          members = vhost "members" "http://127.0.0.1:8082" true true;
          remote = vhost "remote" "http://127.0.0.1:8082" true true;
          routing = vhost "routing" "http://127.0.0.1:8081" false true;
        };
    };

    # Locations go to the site's upstream unless they say otherwise; the
    # settings of "/" keep the upstream.
    "locations of routing" = {
      actual = lib.mapAttrs (_: location: {
        inherit (location) proxyPass root;
      }) (removeAttrs virtualHosts.routing.locations [ "/robots.txt" ]);
      expected = {
        "/" = {
          proxyPass = "http://127.0.0.1:8081";
          root = null;
        };
        "/inherited/" = {
          proxyPass = "http://127.0.0.1:8081";
          root = null;
        };
        "/custom/" = {
          proxyPass = "http://127.0.0.1:8082/mapped/";
          root = null;
        };
        "/static/" = {
          proxyPass = null;
          root = staticFiles;
        };
        "/shared/" = {
          proxyPass = "http://127.0.0.1:8081";
          root = null;
        };
      };
    };

    "settings of a location" = {
      actual = {
        rootExtra = hasLine "X-Location-Extra preserved" virtualHosts.routing.locations."/";
        sharedHere = hasLine "X-Shared routing" virtualHosts.routing.locations."/shared/";
        sharedAtEntry = hasLine "X-Shared remote" virtualHosts.remote.locations."/shared/";
        sharedAtEntryUpstream = virtualHosts.remote.locations."/shared/".proxyPass;
      };
      expected = {
        rootExtra = true;
        sharedHere = true;
        sharedAtEntry = true;
        sharedAtEntryUpstream = "http://127.0.0.1:8082";
      };
    };

    # Every host that proxies a site with a policy asks the portal before
    # every location of the site.
    "locations that do not ask Authelia" = {
      actual = lib.genAttrs [ "appliance" "members" "remote" ] (
        name:
        lib.attrNames (
          lib.filterAttrs (
            _: location: !hasLine "auth_request /internal/authelia/authz;" location
          ) virtualHosts.${name}.locations
        )
      );
      expected = lib.genAttrs [ "appliance" "members" "remote" ] (_: [
        "/internal/authelia/authz"
        "/robots.txt"
      ]);
    };

    "Authelia portal" = {
      actual = node.config.codgician.services.authelia.instances.main.url;
      expected = "https://${domain "auth"}";
    };

    # A rule for every site with subjects, served here or not; `anyone` is
    # left to Authelia's default policy. Sites of the fleet's own modules
    # are left out of the comparison.
    "Authelia rules" = {
      actual =
        lib.filter (rule: lib.any (lib.hasSuffix ".${zone}") (rule.domain or [ ]))
          (nodeWith { codgician.services.authelia.instances.main.enable = true; })
          .services.authelia.instances.main.settings.access_control.rules;
      expected = [
        {
          domain = [ (domain "members") ];
          policy = "two_factor";
          subject = [ "user:alice" ];
        }
        {
          domain = [ (domain "members") ];
          policy = "deny";
        }
        {
          domain = [ (domain "remote") ];
          policy = "two_factor";
          subject = [ "group:staff" ];
        }
        {
          domain = [ (domain "remote") ];
          policy = "deny";
        }
      ];
    };

    "what nginx rejects" = {
      actual = rejected {
        codgician.services.nginx = {
          # A misspelt name: no site declares a domain for it.
          reverseProxies.remot.proxyPass = "http://127.0.0.1:8082";

          # A "/" that says it goes nowhere.
          reverseProxies.remote.locations."/".proxyPass = null;

          # Neither subjects nor `anyone`, and both.
          reverseProxies.open.authelia = { };
          reverseProxies.both.authelia = {
            users = [ "alice" ];
            anyone = true;
          };
        };
      };
      expected = [
        ''nginx: "remot" has no domain. The module that owns the site, or `sites.nix` in the nginx module for a site without one, sets `reverseProxies.remot.domains`; check the spelling of the name.''
        ''nginx: "remote" has nothing to serve at "/". Set `proxyPass`, or make the "/" location serve something.''
        "nginx: reverseProxies.both.authelia needs `users` or `groups`, or `anyone = true`, and not both."
        "nginx: reverseProxies.open.authelia needs `users` or `groups`, or `anyone = true`, and not both."
      ];
    };
  };

  failures = lib.filterAttrs (_: e: e.actual != e.expected) expectations;
in
{
  checks.reverseProxyRouting =
    assert lib.assertMsg (failures == { }) "reverse-proxy: ${builtins.toJSON failures}";
    pkgs.runCommand "reverse-proxy-routing" { } "touch $out";
}
