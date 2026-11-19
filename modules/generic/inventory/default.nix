# The inventory: facts about the fleet that more than one host, module or
# flake output reads. This file declares what may be said and what follows
# from it; `inventory.nix` at the root says it.
{ lib, ... }:
let
  inherit (lib) mkOption types;

  flag =
    description:
    mkOption {
      type = types.bool;
      default = false;
      inherit description;
    };
  derived =
    type: description:
    mkOption {
      inherit type description;
      readOnly = true;
    };

  wireguardType = types.submodule {
    options = {
      ipv4 = mkOption {
        type = types.str;
        description = "IPv4 address inside the mesh.";
      };
      ipv6 = mkOption {
        type = types.str;
        description = "IPv6 address inside the mesh.";
      };
      publicKey = mkOption {
        type = types.str;
        description = "WireGuard public key.";
      };
      port = mkOption {
        type = types.nullOr types.port;
        default = null;
        description = "Port the member listens on; null for a member that only dials out.";
      };
      routes = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Networks behind the member that the mesh routes to it.";
      };
    };
  };

  inventoryModule =
    { config, ... }:
    let
      inherit (config)
        zone
        edge
        hosts
        peers
        services
        ;
    in
    {
      options = {
        zone = mkOption {
          type = types.str;
          description = "DNS zone of every public name.";
        };

        mail = mkOption {
          type = types.str;
          description = "Address all services send mail from.";
        };

        edge = mkOption {
          type = types.enum (lib.attrNames hosts);
          description = ''
            Host that owns the public names of `services`, unless they are
            `direct`, and proxies them to their backends.
          '';
        };

        authelia = mkOption {
          type = types.enum (lib.attrNames services);
          description = "Service that is the Authelia portal.";
        };

        hosts = mkOption {
          default = { };
          description = ''
            Hosts of this flake that other machines refer to: the edge, hosts
            that services run on, members of the WireGuard mesh. What makes a
            host is its folder under `hosts/`, not an entry here.
          '';
          type = types.attrsOf (
            types.submodule (
              { name, config, ... }:
              {
                options = {
                  lan = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = "Address on the home LAN.";
                  };
                  pve = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = "Address of the Proxmox VE management bridge.";
                  };
                  public = flag "The internet reaches the host at `<name>.<zone>`.";
                  ipv4 = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = "Public IPv4 address, when it is fixed.";
                  };
                  ipv6 = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = "Public IPv6 address, when it is fixed.";
                  };
                  wireguard = mkOption {
                    type = types.nullOr wireguardType;
                    default = null;
                    description = "Membership of the WireGuard mesh.";
                  };
                  domain = derived (types.nullOr types.str) "Public name of the host; null unless it is `public`.";
                };

                config.domain = if config.public then "${name}.${zone}" else null;
              }
            )
          );
        };

        peers = mkOption {
          default = { };
          description = "Machines this flake does not build that its hosts connect to.";
          type = types.attrsOf (
            types.submodule (
              { config, ... }:
              {
                options = {
                  subdomain = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = "Label under the zone the peer is reached at.";
                  };
                  wireguard = mkOption {
                    type = wireguardType;
                    description = "Membership of the WireGuard mesh.";
                  };
                  domain = derived (types.nullOr types.str) "Public name of the peer; null without a `subdomain`.";
                };

                config.domain = if config.subdomain == null then null else "${config.subdomain}.${zone}";
              }
            )
          );
        };

        services = mkOption {
          default = { };
          description = ''
            Everything with a public name `<subdomain>.<zone>`; the attribute
            name is the name of the service's module and vhost. The name
            resolves to the edge unless the entry is `direct`.
          '';
          type = types.attrsOf (
            types.submodule (
              { name, config, ... }:
              {
                options = {
                  subdomain = mkOption {
                    type = types.str;
                    default = name;
                    description = "Label under the zone.";
                  };
                  host = mkOption {
                    type = types.nullOr (types.enum (lib.attrNames hosts));
                    default = null;
                    description = ''
                      Inventory host the service runs on; its module is enabled
                      there by default and serves the vhost.
                    '';
                  };
                  port = mkOption {
                    type = types.nullOr types.port;
                    default = null;
                    description = "Loopback port of the backend on `host`; null behind a unix socket.";
                  };
                  address = mkOption {
                    type = types.enum [
                      "lan"
                      "pve"
                    ];
                    default = "lan";
                    description = "Which address of `host` the edge connects to.";
                  };
                  upstream = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = ''
                      URL of a backend that no host here runs, instead of `host`;
                      the edge proxies straight to it. With neither, the entry
                      only reserves the name.
                    '';
                  };
                  direct = flag ''
                    The name resolves to `host` itself, which must be `public`;
                    the edge has no part in it.
                  '';
                  dnsOnly = flag "The name resolves to the edge, but the edge does not proxy it.";
                  authelia = mkOption {
                    default = null;
                    description = ''
                      Who may pass the vhost next to the backend (on `host`; on
                      the edge for `upstream`), which asks Authelia first. Null
                      for no login. Either subjects or `anyone`.
                    '';
                    type = types.nullOr (
                      types.submodule {
                        options = {
                          users = mkOption {
                            type = types.listOf types.str;
                            default = [ ];
                            description = "Only these users.";
                          };
                          groups = mkOption {
                            type = types.listOf types.str;
                            default = [ ];
                            description = "Only members of these groups.";
                          };
                          anyone = flag "Every signed-in user.";
                        };
                      }
                    );
                  };
                  anubis = flag "The edge puts Anubis in front.";
                  edgeVhost = mkOption {
                    type = types.str;
                    default = name;
                    description = "Name of the edge's vhost when it is not the attribute name.";
                  };

                  domain = derived types.str "Public name of the service.";
                  localUpstream = derived (types.nullOr types.str) "Where the service's own host finds the backend; null without a `port`.";
                  fronted = derived types.bool "Whether the edge proxies the name to a backend elsewhere.";
                };

                config = {
                  domain = "${config.subdomain}.${zone}";
                  localUpstream = if config.port == null then null else "http://127.0.0.1:${toString config.port}";
                  fronted =
                    !config.dnsOnly
                    && !config.direct
                    && (config.upstream != null || config.host != null && config.host != edge);
                };
              }
            )
          );
        };

        autheliaUrl = derived types.str "URL of the Authelia portal.";

        autheliaRules = derived (types.listOf types.attrs) ''
          Authelia access-control rules for the services restricted to some
          users or groups; `anyone` is left to Authelia's default policy.
        '';

        dnsNames = derived (types.listOf types.str) "Labels under the zone that resolve to the edge.";

        vhostDomains = derived (types.attrsOf types.str) ''
          Public name behind each vhost name a service can have: its own name
          and the name of its edge vhost.
        '';

        edgeVhosts = derived (types.attrsOf types.attrs) ''
          `codgician.services.nginx.reverseProxies` of the edge: one vhost for
          each service whose backend is elsewhere. Authelia stays with the
          backend's own vhost unless the backend is outside the inventory.
        '';

        wireguard = derived (types.attrsOf types.attrs) ''
          Members of the WireGuard mesh by name, hosts and peers alike, each
          with the `domain` it is reached at.
        '';
      };

      config = {
        autheliaUrl = "https://${services.${config.authelia}.domain}";

        autheliaRules = lib.concatLists (
          lib.mapAttrsToList (
            _: s:
            lib.optionals (s.authelia != null && !s.authelia.anyone) [
              {
                domain = [ s.domain ];
                policy = "two_factor";
                subject =
                  map (user: "user:${user}") s.authelia.users ++ map (group: "group:${group}") s.authelia.groups;
              }
              {
                domain = [ s.domain ];
                policy = "deny";
              }
            ]
          ) services
        );

        dnsNames = lib.mapAttrsToList (_: s: s.subdomain) (lib.filterAttrs (_: s: !s.direct) services);

        vhostDomains =
          lib.mapAttrs' (_: s: lib.nameValuePair s.edgeVhost s.domain) services
          // lib.mapAttrs (_: s: s.domain) services;

        edgeVhosts = lib.mapAttrs' (
          _: s:
          lib.nameValuePair s.edgeVhost {
            proxyPass = if s.host == null then s.upstream else "https://${hosts.${s.host}.${s.address}}";
            authelia = s.authelia != null && s.host == null;
            inherit (s) anubis;
          }
        ) (lib.filterAttrs (_: s: s.fronted) services);

        wireguard = lib.mapAttrs (_: member: member.wireguard // { inherit (member) domain; }) (
          lib.filterAttrs (_: member: member.wireguard != null) (hosts // peers)
        );
      };
    };

  # What the types cannot say: how entries refer to each other.
  assertions =
    {
      edge,
      hosts,
      peers,
      services,
      ...
    }:
    lib.mapAttrsToList (name: _: {
      assertion = !hosts ? ${name};
      message = "peers.${name} is also a host";
    }) peers
    ++ lib.concatLists (
      lib.mapAttrsToList (name: s: [
        {
          assertion = s.host == null || s.upstream == null;
          message = "services.${name} sets both `host` and `upstream`";
        }
        {
          assertion =
            s.host == null || s.host == edge || s.dnsOnly || s.direct || hosts.${s.host}.${s.address} != null;
          message = "services.${name}: host ${s.host} has no `${s.address}` address for ${edge} to reach";
        }
        {
          assertion = !s.direct || s.host != null && hosts.${s.host}.public;
          message = "services.${name} is `direct`, so it needs a `public` host";
        }
        {
          assertion =
            s.authelia == null || (s.authelia.users ++ s.authelia.groups != [ ]) != s.authelia.anyone;
          message = "services.${name}.authelia needs `users` or `groups`, or `anyone = true`, and not both";
        }
      ]) services
    );
in
{
  options.codgician.inventory = mkOption {
    type = types.submodule inventoryModule;
    description = "Facts about the fleet that more than one host, module or flake output reads.";
    # `assertions` are only checked when a system is built, but Terranix and
    # Home Manager read the inventory without building one, so the checks
    # across entries run on every read.
    apply =
      inventory:
      let
        failed = lib.filter (check: !check.assertion) (assertions inventory);
      in
      if failed != [ ] then
        throw "codgician.inventory:${lib.concatMapStrings (check: "\n- ${check.message}") failed}"
      else
        inventory;
  };

  config.codgician.inventory = ../../../inventory.nix;
}
