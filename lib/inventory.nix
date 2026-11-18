{ lib, ... }:
let
  # Everything derived from an inventory's service table. A function of the
  # inventory so tests can derive from a fixture.
  mkPublished =
    inventory:
    let
      defaults = name: {
        subdomain = name;
        host = null;
        port = null;
        address = "lan";
        upstream = null;
        edge = null;
        edgeVhost = name;
        lanOnly = false;
        authelia = null;
        anubis = false;
      };

      services = lib.mapAttrs (
        name: service:
        let
          s = defaults name // service;
          unknown = lib.attrNames (removeAttrs service (lib.attrNames (defaults name)));
        in
        assert lib.assertMsg (
          unknown == [ ]
        ) "inventory: service ${name} has unknown attributes: ${toString unknown}";
        assert lib.assertMsg (
          s.host == null || inventory.hosts ? ${s.host}
        ) "inventory: service ${name} runs on unknown host ${toString s.host}";
        s // { domain = "${s.subdomain}.${inventory.zone}"; }
      ) inventory.services;

      # How `hostName` reaches the backend of service `s`; null when the
      # service's module has to say (unix sockets).
      upstreamFrom =
        hostName: s:
        if s.host == hostName then
          if s.port == null then null else "http://127.0.0.1:${toString s.port}"
        else if s.host != null then
          "https://${inventory.hosts.${s.host}.${s.address}}"
        else
          s.upstream;
    in
    {
      inherit services;

      autheliaUrl = "https://${services.authelia-main.domain}";

      # `codgician.services.nginx.reverseProxies` of one host: a vhost for each
      # service it runs and each service it fronts.
      vhostsFor =
        hostName:
        lib.concatMapAttrs (
          name: s:
          let
            isBackend = s.host == hostName;
            isEdge = s.edge == hostName && !s.lanOnly && (s.host != null || s.upstream != null);
            upstream = upstreamFrom hostName s;
          in
          lib.optionalAttrs (isBackend || isEdge) {
            ${if isBackend then name else s.edgeVhost} = {
              enable = true;
              domains = [ s.domain ];
              authelia.enable = s.authelia != null && (isBackend || s.host == null);
              anubis.enable = s.anubis && isEdge;
            }
            // lib.optionalAttrs (upstream != null) { proxyPass = upstream; };
          }
        ) services;

      # Authelia access-control rules for services restricted to some users or groups.
      autheliaRules = lib.concatLists (
        lib.mapAttrsToList (
          _: s:
          let
            subject =
              map (user: "user:${user}") (s.authelia.users or [ ])
              ++ map (group: "group:${group}") (s.authelia.groups or [ ]);
          in
          lib.optionals (s.authelia != null && subject != [ ]) [
            {
              domain = [ s.domain ];
              policy = "two_factor";
              inherit subject;
            }
            {
              domain = [ s.domain ];
              policy = "deny";
            }
          ]
        ) services
      );

      # Public DNS names and the edge host each one points at.
      edgeNames = lib.mapAttrs' (_: s: lib.nameValuePair s.subdomain s.edge) (
        lib.filterAttrs (_: s: s.edge != null) services
      );
    };

  inventory = import ../inventory.nix;
in
{
  inherit inventory mkPublished;
  published = mkPublished inventory;
}
