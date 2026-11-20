# Sites served next to their backend and through an entry host by the real
# nginx module, the checks it makes and the access rules Authelia derives
# from the sites.
{
  lib,
  pkgs,
  inputs,
  outputs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  staticFiles = pkgs.writeTextDir "static/hello.txt" "static-content\n";
  nixos-lib = import (pkgs.path + "/nixos/lib") { inherit lib; };

  # Ends in a zone the acme module knows.
  zone = "fixture.${lib.codgician.zone}";
  domain = name: "${name}.${zone}";
  domains = map domain [
    "auth"
    "routing"
    "members"
    "remote"
    "appliance"
  ];

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

  test = nixos-lib.runTest {
    name = "reverse-proxy-routing";
    hostPkgs = pkgs;
    defaults = {
      imports = lib.codgician.nixosModules;
      nixpkgs.pkgs = pkgs;
      _module.args = {
        inherit inputs outputs system;
      };
    };

    nodes.machine =
      { lib, ... }:
      {
        imports = [
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
        ];

        users.users.root = {
          initialPassword = "root";
          hashedPasswordFile = lib.mkForce null;
        };
        environment.systemPackages = [ pkgs.curl ];

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

              # A stand-in for the portal, at the address its site gives
              # every vhost that asks Authelia.
              authelia-main = {
                domains = lib.mkForce [ (domain "auth") ];
                proxyPass = lib.mkForce "http://127.0.0.1:8083";
              };
            };
          };
        };

        networking.hosts."127.0.0.1" = [ (domain "auth") ];

        services.nginx.virtualHosts = {
          backend-one = {
            listen = [
              {
                addr = "127.0.0.1";
                port = 8081;
              }
            ];
            locations."/".return = ''200 "backend-one:$request_uri"'';
          };
          backend-two = {
            listen = [
              {
                addr = "127.0.0.1";
                port = 8082;
              }
            ];
            locations."/".return = ''200 "backend-two:$request_uri"'';
          };
          auth-backend = {
            listen = [
              {
                addr = "127.0.0.1";
                port = 8083;
              }
            ];
            # A stand-in for the portal: it admits the session cookie
            # `signed-in` and nothing else.
            locations."/".extraConfig = ''
              if ($cookie_session = signed-in) {
                return 200;
              }
              return 403;
            '';
          };
        };

        # Keep the generated useACMEHost path and the self-signed bootstrap,
        # without requesting production certificates or loading DNS secrets.
        codgician.secrets = {
          enable = false;
          files.cloudflare-credential = { };
        };
        security.acme = {
          defaults.email = "reverse-proxy@example.invalid";
          certs = lib.genAttrs domains (_: {
            dnsProvider = lib.mkForce null;
            environmentFile = lib.mkForce null;
            webroot = "/var/lib/acme/acme-challenge";
          });
        };
        systemd.services = lib.genAttrs (map (name: "acme-order-renew-${name}") domains) (_: {
          enable = lib.mkForce false;
        });
        systemd.timers = lib.genAttrs (map (name: "acme-renew-${name}") domains) (_: {
          enable = lib.mkForce false;
        });
      };

    testScript = ''
      machine.start()
      machine.wait_for_unit("nginx.service")
      machine.wait_for_open_port(80)
      machine.wait_for_open_port(443)

      def curl(host, path, flags):
          return machine.succeed(
              f"curl --noproxy '*' --silent --show-error --insecure "
              f"--resolve {host}:443:127.0.0.1 {flags} https://{host}{path}"
          )

      def request(host, path="/", flags=""):
          return curl(host, path, f"--fail {flags}")

      def status(host, path="/"):
          return curl(host, path, "--output /dev/null --write-out '%{http_code}'")

      with subtest("a site is served where its module is enabled"):
          assert request("${domain "routing"}") == "backend-one:/"

      with subtest("locations go to the site's upstream unless they say otherwise"):
          assert request("${domain "routing"}", "/inherited/item") == "backend-one:/inherited/item"
          assert request("${domain "routing"}", "/custom/item") == "backend-two:/mapped/item"
          assert request("${domain "routing"}", "/static/hello.txt") == "static-content\n"

      with subtest("settings of the root location keep the upstream"):
          assert "x-location-extra: preserved" in request("${domain "routing"}", flags="--head").lower()

      signed_in = "--cookie session=signed-in"

      with subtest("a site reached through an entry host goes to the host that serves it"):
          assert request("${domain "remote"}", "/item", signed_in) == "backend-two:/item"

      with subtest("the locations of a site reach the host that serves it and the entry host"):
          assert "x-shared: routing" in request("${domain "routing"}", "/shared/item", "--head").lower()
          assert "x-shared: remote" in request("${domain "remote"}", "/shared/item", f"--head {signed_in}").lower()

      with subtest("every host that proxies a site with a policy asks the portal"):
          assert status("${domain "auth"}") == "403"
          assert status("${domain "members"}") == "403"
          assert status("${domain "appliance"}") == "403"
          assert status("${domain "remote"}") == "403"
          assert request("${domain "members"}", "/", signed_in) == "backend-two:/"

      with subtest("plain HTTP redirects to HTTPS"):
          redirect = machine.succeed(
              "curl --noproxy '*' --silent --show-error --head -H 'Host: ${domain "routing"}' http://127.0.0.1/"
          ).lower()
          assert "location: https://${domain "routing"}/" in redirect
    '';
  };

  # The node with `module` added to it.
  nodeWith = module: (test.extendNixOS { inherit module; }).nodes.machine;

  # What the nginx module rejects, by the first line of its message.
  rejected =
    module:
    lib.sort lib.lessThan (
      map (failed: lib.head (lib.splitString "\n" failed.message)) (
        lib.filter (check: !check.assertion && lib.hasPrefix "nginx:" check.message)
          (nodeWith module).assertions
      )
    );

  expectations = {
    # Besides the catch-all, the status page and the stand-in backends.
    "vhosts of the node" = {
      actual =
        lib.mapAttrs
          (_: vhost: {
            inherit (vhost) serverName;
            root = vhost.locations."/".proxyPass;
            asksAuthelia = vhost.locations ? "/internal/authelia/authz";
            shared = vhost.locations ? "/shared/";
          })
          (
            removeAttrs test.nodes.machine.services.nginx.virtualHosts [
              "_"
              "localhost"
              "backend-one"
              "backend-two"
              "auth-backend"
            ]
          );
      expected = {
        appliance = {
          serverName = domain "appliance";
          root = "http://127.0.0.1:8082";
          asksAuthelia = true;
          shared = false;
        };
        authelia-main = {
          serverName = domain "auth";
          root = "http://127.0.0.1:8083";
          asksAuthelia = false;
          shared = false;
        };
        members = {
          serverName = domain "members";
          root = "http://127.0.0.1:8082";
          asksAuthelia = true;
          shared = true;
        };
        remote = {
          serverName = domain "remote";
          root = "http://127.0.0.1:8082";
          asksAuthelia = true;
          shared = true;
        };
        routing = {
          serverName = domain "routing";
          root = "http://127.0.0.1:8081";
          asksAuthelia = false;
          shared = true;
        };
      };
    };

    "Authelia portal" = {
      actual = test.nodes.machine.codgician.services.authelia.instances.main.url;
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
assert lib.assertMsg (failures == { }) "reverse-proxy: ${builtins.toJSON failures}";
{
  reverseProxyRouting = test;
}
