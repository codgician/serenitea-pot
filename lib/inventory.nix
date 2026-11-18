{ lib, ... }:
let
  check = condition: message: lib.assertMsg condition "inventory: ${message}";

  # Value kinds of the schema below
  str = {
    check = builtins.isString;
    what = "a string";
  };
  bool = {
    check = builtins.isBool;
    what = "true or false";
  };
  port = {
    check = v: builtins.isInt v && v > 0 && v < 65536;
    what = "a port number";
  };
  strings = {
    check = v: builtins.isList v && lib.all builtins.isString v;
    what = "a list of strings";
  };
  oneOf = values: {
    check = v: lib.elem v values;
    what = "one of ${toString values}";
  };
  # A key that may be left out; `kind` is a value kind or a nested schema.
  optional = kind: default: { inherit kind default; };

  # The keys `inventory.nix` may use and what they mean.
  hostSchema = {
    lan = optional str null; # address on the home LAN
    pve = optional str null; # address of the Proxmox VE management bridge
  };
  serviceSchema = name: {
    # Label under the zone
    subdomain = optional str name;
    # Inventory host the service runs on; its module is enabled there by
    # default and serves the vhost
    host = optional str null;
    # Loopback port of the backend on `host`; services behind a unix socket omit it
    port = optional port null;
    # Which address of `host` the edge connects to
    address = optional (oneOf (lib.attrNames hostSchema)) "lan";
    # URL of a backend that is not an inventory host, instead of `host`.
    # With neither, the entry only reserves the name.
    upstream = optional str null;
    # The name resolves to the edge, but the edge does not proxy it
    dnsOnly = optional bool false;
    # The vhost next to the backend asks Authelia first
    authelia = optional {
      users = optional strings [ ]; # only these users may pass
      groups = optional strings [ ]; # only members of these groups may pass
      anyone = optional bool false; # every signed-in user may pass
    } null;
    # The edge puts Anubis in front
    anubis = optional bool false;
    # Name of the edge's vhost if it is not the attribute name
    edgeVhost = optional str name;
  };

  # `value` with the schema's defaults filled in; unknown keys and values of
  # the wrong kind are errors naming the path.
  conform =
    path: schema: value:
    assert check (builtins.isAttrs value) "${path} must be an attribute set";
    assert check (removeAttrs value (lib.attrNames schema) == { })
      "${path} has unknown keys: ${toString (lib.attrNames (removeAttrs value (lib.attrNames schema)))}";
    lib.mapAttrs (
      key:
      { kind, default }:
      let
        v = value.${key} or default;
      in
      if v == default then
        v
      else if kind ? check then
        assert check (kind.check v) "${path}.${key} must be ${kind.what}";
        v
      else
        conform "${path}.${key}" kind v
    ) schema;

  # Everything derived from an inventory. A function of the data so tests can
  # derive from a fixture.
  mkPublished =
    data:
    let
      inherit (data) edge zone;
      hosts = lib.mapAttrs (name: conform "hosts.${name}" hostSchema) data.hosts;

      services =
        assert builtins.deepSeq hosts true;
        assert check (hosts ? ${edge}) "edge names unknown host ${edge}";
        assert check (data.services ? ${data.authelia}) "authelia names unknown service ${data.authelia}";
        lib.mapAttrs (
          name: service:
          let
            s = conform "services.${name}" (serviceSchema name) service;
          in
          assert builtins.deepSeq s true;
          # What the schema cannot say: how entries refer to each other.
          assert check (
            s.host == null || hosts ? ${s.host}
          ) "services.${name} runs on unknown host ${s.host}";
          assert check (s.host == null || s.upstream == null) "services.${name} sets both host and upstream";
          assert check (
            s.host == null || s.host == edge || s.dnsOnly || hosts.${s.host}.${s.address} != null
          ) "services.${name}: host ${s.host} has no ${s.address} address for ${edge} to reach";
          assert check (
            s.authelia == null || (s.authelia.users ++ s.authelia.groups != [ ]) != s.authelia.anyone
          ) "services.${name}.authelia needs users or groups, or anyone = true, and not both";
          s
          // {
            domain = "${s.subdomain}.${zone}";
            # Where the service's own host finds the backend; null without a port
            localUpstream = if s.port == null then null else "http://127.0.0.1:${toString s.port}";
            # Whether the edge proxies the name to a backend elsewhere
            fronted = !s.dnsOnly && (s.upstream != null || s.host != null && s.host != edge);
          }
        ) data.services;
    in
    {
      inherit services;

      autheliaUrl = "https://${services.${data.authelia}.domain}";

      # Whether the inventory places service `name` on `hostName`.
      runsOn = hostName: name: (services.${name}.host or null) == hostName;

      # Whether `hostName` is the edge in front of service `name`.
      fronts = hostName: name: hostName == edge && (services.${name}.fronted or false);

      # Domain of the service whose backend or edge vhost is called `vhost`.
      domainOf =
        vhost:
        (services.${vhost} or (lib.findFirst (s: s.edgeVhost == vhost) { } (lib.attrValues services)))
        .domain or null;

      # `codgician.services.nginx.reverseProxies` the table gives `hostName`:
      # on the edge, one vhost for each service whose backend is elsewhere.
      # Authelia stays with the backend's own vhost unless the backend is
      # outside the inventory.
      edgeVhostsFor =
        hostName:
        lib.optionalAttrs (hostName == edge) (
          lib.mapAttrs' (
            _: s:
            lib.nameValuePair s.edgeVhost {
              proxyPass = if s.host == null then s.upstream else "https://${hosts.${s.host}.${s.address}}";
              authelia = s.authelia != null && s.host == null;
              inherit (s) anubis;
            }
          ) (lib.filterAttrs (_: s: s.fronted) services)
        );

      # Authelia access-control rules for services restricted to some users or
      # groups; `anyone` is left to Authelia's default policy.
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

      # Subdomains of the zone that resolve to the edge.
      dnsNames = lib.mapAttrsToList (_: s: s.subdomain) services;
    };
in
{
  inherit mkPublished;
  inventory = import ../inventory.nix;
  published = mkPublished lib.codgician.inventory;

  # `enable` of the module of a published service: on by default on the host
  # the inventory places the service on.
  mkPublishedEnableOption =
    config: name:
    lib.mkOption {
      type = lib.types.bool;
      default = lib.codgician.published.runsOn config.networking.hostName name;
      defaultText = lib.literalMD "true on the `host` of service `${name}` in `inventory.nix`";
      description = "Whether to run ${name} on this host.";
    };
}
