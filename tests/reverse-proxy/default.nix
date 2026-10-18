# Exercise the service adapter through the real nginx consumer, not copied attrs.
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
  serviceNames = [
    "routing"
    "overridden"
    "private"
    "private-default"
    "extra-root"
    "authenticated"
    "tls"
  ];
  staticFiles = pkgs.writeTextDir "static/hello.txt" "static-content\n";

  fixtureModule =
    { config, lib, ... }:
    {
      options.codgician.services.proxyFixture = lib.genAttrs serviceNames (serviceName: {
        # Deliberately left disabled: proxy-only service profiles must still work.
        enable = lib.mkEnableOption "reverse proxy test backend";
        reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
          inherit serviceName;
          defaultDomains = [ "${serviceName}.test" ];
          defaultProxyPass = "http://127.0.0.1:8081";
        };
      });

      config.codgician.services.nginx = lib.mkMerge (
        map (
          serviceName:
          lib.codgician.mkServiceReverseProxyConfig {
            inherit serviceName;
            cfg = config.codgician.services.proxyFixture.${serviceName};
            extraVhostConfig =
              if serviceName == "overridden" then
                {
                  # Same merge shape as the NATS websocket directives.
                  locations."/".passthru.extraConfig = ''
                    proxy_buffering off;
                    proxy_read_timeout 1h;
                    proxy_send_timeout 1h;
                    add_header X-Adapter-Extra preserved always;
                  '';
                }
              else if serviceName == "extra-root" then
                {
                  locations."/" = {
                    lanOnly = false;
                    passthru.proxyPass = "http://127.0.0.1:8082";
                  };
                }
              else
                { };
          }
        ) serviceNames
      );
    };
in
{
  reverseProxyRouting = nixos-lib.runTest {
    name = "reverse-proxy-routing";
    hostPkgs = pkgs;
    defaults = {
      imports = lib.codgician.mkNixosModules system { };
      nixpkgs.overlays = pkgs.overlays;
      _module.args = {
        inherit inputs outputs system;
      };
    };

    nodes.machine =
      { lib, ... }:
      {
        imports = [ fixtureModule ];
        nixpkgs.config.allowUnfree = true;
        users.users.root = {
          initialPassword = "root";
          hashedPasswordFile = lib.mkForce null;
        };
        environment.systemPackages = [ pkgs.curl ];

        codgician.services.proxyFixture = {
          routing.reverseProxy = {
            enable = true;
            https = false;
            locations = {
              "/custom/".passthru.proxyPass = "http://127.0.0.1:8082/mapped/";
              "/static/".passthru = {
                root = staticFiles;
                tryFiles = "$uri =404";
              };
            };
            robots = ''
              User-agent: *
              Disallow: /custom/
            '';
          };
          overridden.reverseProxy = {
            enable = true;
            https = false;
            locations."/".passthru.proxyPass = "http://127.0.0.1:8082";
          };
          private.reverseProxy = {
            enable = true;
            https = false;
            lanOnly = true;
            locations = {
              # Changing only the upstream must not silently remove the ACL.
              "/".passthru.proxyPass = "http://127.0.0.1:8082";
              "/custom/".passthru.proxyPass = "http://127.0.0.1:8082";
              "/public/" = {
                lanOnly = false;
                passthru.proxyPass = "http://127.0.0.1:8082";
              };
            };
          };
          private-default.reverseProxy = {
            enable = true;
            https = false;
            lanOnly = true;
          };
          extra-root.reverseProxy = {
            enable = true;
            https = false;
            lanOnly = true;
          };
          authenticated.reverseProxy = {
            enable = true;
            https = false;
            authelia = {
              enable = true;
              url = "http://127.0.0.1:8083";
            };
            locations = {
              "/".passthru.proxyPass = "http://127.0.0.1:8082";
              "/custom/".passthru.proxyPass = "http://127.0.0.1:8082";
              "/public/" = {
                authelia.enable = false;
                passthru.proxyPass = "http://127.0.0.1:8082";
              };
            };
          };
          tls.reverseProxy = {
            enable = true;
            # Exercise the unchanged default HTTPS/ACME-host integration.
            domains = [ "codgician.me" ];
          };
        };

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

      with subtest("default root, custom proxy URI, static content and robots"):
          assert request("routing.test") == "backend-one:/"
          assert request("routing.test", "/custom/item") == "backend-two:/mapped/item"
          assert request("routing.test", "/static/hello.txt") == "static-content\n"
          assert request("routing.test", "/robots.txt") == "User-agent: *\nDisallow: /custom/\n"

      with subtest("root override merges with existing websocket extras"):
          assert request("overridden.test", "/item") == "backend-two:/item"
          headers = request("overridden.test", flags="--head").lower()
          assert "x-adapter-extra: preserved" in headers
          assert request("extra-root.test") == "backend-two:/"

      with subtest("root and added paths inherit LAN restrictions, with explicit exceptions"):
          assert status("private-default.test") == "403"
          assert status("private.test") == "403"
          assert status("private.test", "/custom/item") == "403"
          assert request("private.test", "/public/item") == "backend-two:/public/item"
          machine.succeed("ip address add 192.168.1.2/32 dev lo")
          assert request("private-default.test", flags="--interface 192.168.1.2") == "backend-one:/"
          assert request("private.test", flags="--interface 192.168.1.2") == "backend-two:/"
          assert request("private.test", "/custom/item", "--interface 192.168.1.2") == "backend-two:/custom/item"

      with subtest("root and added paths inherit Authelia, with explicit exceptions"):
          assert status("authenticated.test") == "403"
          assert status("authenticated.test", "/custom/item") == "403"
          assert request("authenticated.test", "/public/item") == "backend-two:/public/item"

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
