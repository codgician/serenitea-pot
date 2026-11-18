# Derive vhosts, DNS names and Authelia rules from a fixture inventory, then
# serve the vhosts of one of its hosts through the real nginx module.
{
  lib,
  pkgs,
  inputs,
  outputs,
  ...
}:
let
  nixos-lib = import (pkgs.path + "/nixos/lib") { inherit lib; };
  system = pkgs.stdenv.hostPlatform.system;
  staticFiles = pkgs.writeTextDir "static/hello.txt" "static-content\n";

  published = lib.codgician.mkPublished {
    zone = "test";
    hosts = {
      machine.lan = "192.0.2.20";
      elsewhere.lan = "192.0.2.10";
    };
    services = {
      authelia-main = {
        subdomain = "auth";
        host = "elsewhere";
        edge = "front";
        anubis = true;
      };
      routing = {
        host = "machine";
        port = 8081;
        edge = "front";
      };
      authenticated = {
        host = "machine";
        port = 8082;
        edge = "front";
        authelia.users = [ "alice" ];
      };
      external = {
        upstream = "http://127.0.0.1:8082";
        edge = "machine";
        authelia = { };
      };
      private = {
        subdomain = "lan";
        host = "machine";
        port = 8081;
        edge = "front";
        lanOnly = true;
      };
      parked.edge = "front";
    };
  };

  expectations = {
    "vhosts of the backend host" = {
      actual = published.vhostsFor "machine";
      expected = {
        routing = {
          enable = true;
          domains = [ "routing.test" ];
          proxyPass = "http://127.0.0.1:8081";
          authelia.enable = false;
          anubis.enable = false;
        };
        authenticated = {
          enable = true;
          domains = [ "authenticated.test" ];
          proxyPass = "http://127.0.0.1:8082";
          authelia.enable = true;
          anubis.enable = false;
        };
        external = {
          enable = true;
          domains = [ "external.test" ];
          proxyPass = "http://127.0.0.1:8082";
          authelia.enable = true;
          anubis.enable = false;
        };
        private = {
          enable = true;
          domains = [ "lan.test" ];
          proxyPass = "http://127.0.0.1:8081";
          authelia.enable = false;
          anubis.enable = false;
        };
      };
    };

    # The edge leaves authentication to the backend's vhost, proxies nothing
    # for LAN-only and parked names, and puts Anubis in front where asked.
    "vhosts of the edge host" = {
      actual = published.vhostsFor "front";
      expected = {
        authelia-main = {
          enable = true;
          domains = [ "auth.test" ];
          proxyPass = "https://192.0.2.10";
          authelia.enable = false;
          anubis.enable = true;
        };
        routing = {
          enable = true;
          domains = [ "routing.test" ];
          proxyPass = "https://192.0.2.20";
          authelia.enable = false;
          anubis.enable = false;
        };
        authenticated = {
          enable = true;
          domains = [ "authenticated.test" ];
          proxyPass = "https://192.0.2.20";
          authelia.enable = false;
          anubis.enable = false;
        };
      };
    };

    "vhosts of the unix-socket backend" = {
      actual = published.vhostsFor "elsewhere";
      expected.authelia-main = {
        enable = true;
        domains = [ "auth.test" ];
        authelia.enable = false;
        anubis.enable = false;
      };
    };

    "Authelia rules" = {
      actual = published.autheliaRules;
      expected = [
        {
          domain = [ "authenticated.test" ];
          policy = "two_factor";
          subject = [ "user:alice" ];
        }
        {
          domain = [ "authenticated.test" ];
          policy = "deny";
        }
      ];
    };

    "DNS names" = {
      actual = published.edgeNames;
      expected = {
        auth = "front";
        routing = "front";
        authenticated = "front";
        external = "machine";
        lan = "front";
        parked = "front";
      };
    };
  };

  failures = lib.filterAttrs (_: e: e.actual != e.expected) expectations;
in
assert lib.assertMsg (failures == { }) "reverse-proxy: ${builtins.toJSON failures}";
{
  reverseProxyRouting = nixos-lib.runTest {
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
        users.users.root = {
          initialPassword = "root";
          hashedPasswordFile = lib.mkForce null;
        };
        environment.systemPackages = [ pkgs.curl ];

        codgician.services.nginx.reverseProxies = lib.mkMerge [
          (lib.mapAttrs (_: vhost: vhost // { https = false; }) (published.vhostsFor "machine"))
          {
            # What a service module adds to the vhost the inventory gives it.
            routing.locations = {
              "/".extraConfig = ''
                add_header X-Fragment preserved always;
              '';
              "/custom/".proxyPass = "http://127.0.0.1:8082/mapped/";
              "/static/" = {
                root = staticFiles;
                tryFiles = "$uri =404";
              };
            };
            authenticated.authelia.url = "http://127.0.0.1:8083";
            external.authelia.url = "http://127.0.0.1:8083";
            external.locations."/public/".proxyPass = "http://127.0.0.1:8082";

            # A vhost outside the service table, with the default HTTPS setup.
            tls = {
              enable = true;
              domains = [ "codgician.me" ];
              proxyPass = "http://127.0.0.1:8081";
            };
          }
        ];

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
            locations."/".return = "403";
          };
        };

        # Keep the generated useACMEHost path and real self-signed bootstrap,
        # without requesting a production certificate or loading DNS secrets.
        codgician.acme."codgician.me".enable = lib.mkForce false;
        security.acme = {
          defaults.email = "reverse-proxy@example.invalid";
          certs."codgician.me" = {
            group = "nginx";
            webroot = "/var/lib/acme/acme-challenge";
          };
        };
        systemd.services."acme-order-renew-codgician.me".enable = lib.mkForce false;
        systemd.timers."acme-renew-codgician.me".enable = lib.mkForce false;
      };

    testScript = ''
      machine.start()
      machine.wait_for_unit("nginx.service")
      machine.wait_for_open_port(80)
      machine.wait_for_open_port(443)

      def request(host, path="/", flags=""):
          return machine.succeed(
              f"curl --noproxy '*' --fail --silent --show-error {flags} "
              f"-H 'Host: {host}' http://127.0.0.1{path}"
          )

      def status(host, path="/"):
          return machine.succeed(
              f"curl --noproxy '*' --silent --show-error --output /dev/null "
              f"--write-out '%{{http_code}}' -H 'Host: {host}' http://127.0.0.1{path}"
          )

      with subtest("the inventory port is the root upstream; added locations keep theirs"):
          assert request("routing.test") == "backend-one:/"
          assert request("routing.test", "/custom/item") == "backend-two:/mapped/item"
          assert request("routing.test", "/static/hello.txt") == "static-content\n"
          assert request("lan.test") == "backend-one:/"

      with subtest("a fragment on the root location merges with the derived upstream"):
          headers = request("routing.test", flags="--head").lower()
          assert "x-fragment: preserved" in headers

      with subtest("an Authelia vhost checks the session on every location"):
          assert status("authenticated.test") == "403"
          assert status("external.test") == "403"
          assert status("external.test", "/public/item") == "403"

      with subtest("default HTTPS redirect and ACME certificate bootstrap still serve the root"):
          assert status("codgician.me") == "301"
          redirect = request("codgician.me", flags="--head").lower()
          assert "location: https://codgician.me/" in redirect
          content = machine.succeed(
              "curl --noproxy '*' --fail --silent --show-error --insecure "
              "--resolve codgician.me:443:127.0.0.1 https://codgician.me/"
          )
          assert content == "backend-one:/"
    '';
  };
}
