# Evaluate the inventory module on fixture tables, then serve one fixture
# through the real nginx module.
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

  # `codgician.inventory` when `table` takes the place of `inventory.nix`.
  inventoryOf =
    table:
    (lib.evalModules {
      modules = [
        ../../modules/generic/inventory
        { codgician.inventory = lib.mkForce table; }
      ];
    }).config.codgician.inventory;

  # Derivation only: an edge with backends elsewhere.
  table = {
    zone = "example.org";
    mail = "bot@example.org";
    edge = "front";
    authelia = "portal";
    hosts = {
      front = { };
      backend = {
        lan = "192.0.2.10";
        pve = "192.0.2.11";
      };
    };
    services = {
      portal = {
        subdomain = "auth";
        host = "backend";
        anubis = true;
      };
      wiki = {
        host = "backend";
        port = 8081;
        authelia.users = [ "alice" ];
      };
      console = {
        host = "backend";
        address = "pve";
        authelia.groups = [ "staff" ];
        edgeVhost = "console.example.org";
      };
      notes = {
        host = "backend";
        port = 8082;
        authelia.anyone = true;
      };
      appliance = {
        upstream = "http://192.0.2.20:8080";
        authelia.anyone = true;
      };
      local = {
        host = "front";
        port = 8083;
        anubis = true;
      };
      printer = {
        host = "backend";
        dnsOnly = true;
      };
      parked = { };
    };
  };
  derived = inventoryOf table;

  withService =
    service:
    table
    // {
      services = table.services // {
        broken = service;
      };
    };
  # Reading one value is enough: whoever reads the inventory checks all of it.
  rejected = lib.mapAttrs (_: data: !(builtins.tryEval (inventoryOf data).zone).success) {
    "unknown key" = withService { hots = "backend"; };
    "unknown key inside authelia" = withService {
      host = "backend";
      authelia.group = [ "staff" ];
    };
    "authelia that is not a set" = withService {
      host = "backend";
      authelia = false;
    };
    "authelia without subjects" = withService {
      host = "backend";
      authelia = { };
    };
    "authelia with subjects and anyone" = withService {
      host = "backend";
      authelia = {
        users = [ "alice" ];
        anyone = true;
      };
    };
    "port that is not a number" = withService {
      host = "backend";
      port = "8096x";
    };
    "unknown backend host" = withService { host = "backnd"; };
    "host and upstream together" = withService {
      host = "backend";
      upstream = "http://192.0.2.20";
    };
    "backend without the address the edge needs" = withService { host = "front"; } // {
      edge = "backend";
    };
    "unknown edge" = table // {
      edge = "frnt";
    };
    "unknown Authelia service" = table // {
      authelia = "portl";
    };
    "unknown host key" = table // {
      hosts = table.hosts // {
        front.lna = "192.0.2.1";
      };
    };
    "mesh member without a key" = table // {
      hosts = table.hosts // {
        front.wireguard = {
          ipv4 = "192.0.2.1";
          ipv6 = "2001:db8::1";
        };
      };
    };
    "peer that is also a host" = table // {
      peers.front.wireguard = {
        ipv4 = "192.0.2.1";
        ipv6 = "2001:db8::1";
        publicKey = "key";
      };
    };
    "direct name on a host that is not public" = withService {
      host = "backend";
      direct = true;
    };
  };

  expectations = {
    # Authentication stays with the backend's own vhost unless the backend is
    # outside the inventory; names the edge only resolves, parked names and
    # services on the edge itself get no vhost from the table.
    "vhosts the table gives the edge" = {
      actual = derived.edgeVhosts;
      expected = {
        portal = {
          proxyPass = "https://192.0.2.10";
          authelia = false;
          anubis = true;
        };
        wiki = {
          proxyPass = "https://192.0.2.10";
          authelia = false;
          anubis = false;
        };
        "console.example.org" = {
          proxyPass = "https://192.0.2.11";
          authelia = false;
          anubis = false;
        };
        notes = {
          proxyPass = "https://192.0.2.10";
          authelia = false;
          anubis = false;
        };
        appliance = {
          proxyPass = "http://192.0.2.20:8080";
          authelia = true;
          anubis = false;
        };
      };
    };

    # Only the edge gets them: the node under a table whose edge is elsewhere.
    "vhosts the table gives another host" = {
      actual =
        (test.extendNixOS {
          module.codgician.inventory = lib.mkOverride 40 (
            vmTable
            // {
              edge = "elsewhere";
              hosts = {
                machine.lan = "192.0.2.1";
                elsewhere = { };
              };
            }
          );
        }).nodes.machine.codgician.services.nginx.fronts;
      expected = { };
    };

    "placement" = {
      actual =
        map
          (
            name:
            (lib.codgician.mkPublishedEnableOption {
              networking.hostName = "backend";
              codgician.inventory = derived;
            } name).default
          )
          [
            "wiki"
            "local"
            "appliance"
            "absent"
          ];
      expected = [
        true
        false
        false
        false
      ];
    };

    "fronted services" = {
      actual = lib.attrNames (lib.filterAttrs (_: service: service.fronted) derived.services);
      expected = [
        "appliance"
        "console"
        "notes"
        "portal"
        "wiki"
      ];
    };

    "domains by vhost name" = {
      actual = map (vhost: derived.vhostDomains.${vhost} or null) [
        "wiki"
        "console.example.org"
        "portal"
        "absent"
      ];
      expected = [
        "wiki.example.org"
        "console.example.org"
        "auth.example.org"
        null
      ];
    };

    "local upstreams" = {
      actual = [
        derived.services.wiki.localUpstream
        derived.services.portal.localUpstream
      ];
      expected = [
        "http://127.0.0.1:8081"
        null
      ];
    };

    "Authelia portal" = {
      actual = derived.autheliaUrl;
      expected = "https://auth.example.org";
    };

    # Only restricted services get rules; `anyone` is Authelia's default policy.
    "Authelia rules" = {
      actual = derived.autheliaRules;
      expected = [
        {
          domain = [ "console.example.org" ];
          policy = "two_factor";
          subject = [ "group:staff" ];
        }
        {
          domain = [ "console.example.org" ];
          policy = "deny";
        }
        {
          domain = [ "wiki.example.org" ];
          policy = "two_factor";
          subject = [ "user:alice" ];
        }
        {
          domain = [ "wiki.example.org" ];
          policy = "deny";
        }
      ];
    };

    "DNS names" = {
      actual = derived.dnsNames;
      expected = [
        "appliance"
        "console"
        "local"
        "notes"
        "parked"
        "auth"
        "printer"
        "wiki"
      ];
    };

    "tables that must be rejected" = {
      actual = lib.attrNames (lib.filterAttrs (_: isRejected: !isRejected) rejected);
      expected = [ ];
    };
  };

  failures = lib.filterAttrs (_: e: e.actual != e.expected) expectations;

  # Served by the VM: `machine` is the edge, runs three services itself and
  # fronts a backend outside the inventory. The zone ends in one the acme
  # module knows.
  vmTable = {
    zone = "fixture.codgician.me";
    mail = "bot@fixture.codgician.me";
    edge = "machine";
    authelia = "portal";
    hosts = {
      machine = { };
      elsewhere = { };
    };
    services = {
      portal = {
        subdomain = "auth";
        host = "machine";
        port = 8083;
      };
      routing = {
        host = "machine";
        port = 8081;
      };
      members = {
        host = "machine";
        port = 8082;
        authelia.users = [ "alice" ];
      };
      # Placed elsewhere; the node runs it anyway.
      moved = {
        host = "elsewhere";
        port = 8082;
        dnsOnly = true;
      };
      appliance.upstream = "http://127.0.0.1:8082";
      guarded = {
        upstream = "http://127.0.0.1:8081";
        authelia.anyone = true;
      };
    };
  };

  vmInventory = inventoryOf vmTable;
  domain = name: vmInventory.services.${name}.domain;
  domains = map domain (lib.attrNames vmTable.services);

  # The shape of a published service's module.
  serviceModule =
    name:
    { config, lib, ... }:
    {
      options.codgician.services.${name}.enable = lib.codgician.mkPublishedEnableOption config name;

      config = lib.mkIf config.codgician.services.${name}.enable {
        codgician.services.nginx.reverseProxies.${name}.proxyPass =
          config.codgician.inventory.services.${name}.localUpstream;
      };
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
        imports = map serviceModule [
          "portal"
          "routing"
          "members"
          "moved"
        ];

        users.users.root = {
          initialPassword = "root";
          hashedPasswordFile = lib.mkForce null;
        };
        environment.systemPackages = [ pkgs.curl ];

        codgician.services.moved.enable = true;
        codgician.inventory = lib.mkForce vmTable;

        # What a service module adds to its vhost.
        codgician.services.nginx.reverseProxies.routing.locations = {
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

        # The portal's vhost stands in for Authelia at the address every
        # protected vhost asks.
        networking.hosts."127.0.0.1" = [ (domain "portal") ];

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

      with subtest("a service module's vhost goes to the port the table gives it"):
          assert request("${domain "routing"}") == "backend-one:/"

      with subtest("locations go to the vhost's upstream unless they say otherwise"):
          assert request("${domain "routing"}", "/inherited/item") == "backend-one:/inherited/item"
          assert request("${domain "routing"}", "/custom/item") == "backend-two:/mapped/item"
          assert request("${domain "routing"}", "/static/hello.txt") == "static-content\n"

      with subtest("settings of the root location keep the upstream"):
          assert "x-location-extra: preserved" in request("${domain "routing"}", flags="--head").lower()

      with subtest("a host can run a service the table places elsewhere"):
          assert request("${domain "moved"}", "/item") == "backend-two:/item"

      with subtest("the edge fronts backends outside the inventory"):
          assert request("${domain "appliance"}", "/item") == "backend-two:/item"

      with subtest("a vhost behind Authelia asks the portal, next to the backend and on the edge"):
          assert status("${domain "portal"}") == "403"
          assert status("${domain "members"}") == "403"
          assert status("${domain "guarded"}") == "403"

      with subtest("plain HTTP redirects to HTTPS"):
          redirect = machine.succeed(
              "curl --noproxy '*' --silent --show-error --head -H 'Host: ${domain "routing"}' http://127.0.0.1/"
          ).lower()
          assert "location: https://${domain "routing"}/" in redirect
    '';
  };
in
assert lib.assertMsg (failures == { }) "reverse-proxy: ${builtins.toJSON failures}";
{
  reverseProxyRouting = test;
}
