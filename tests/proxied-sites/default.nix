# A host that proxies a site to another host and the host that serves it
# are configured in different places, and no host evaluates another.
# Whether they agree is checked here, over all hosts at once: a site some
# host proxies to a remote upstream is served next to its backend by some
# host. Sites without a module may have their backend outside the fleet.
{
  lib,
  pkgs,
  outputs,
  ...
}:
let
  outsideFleet =
    lib.attrNames
      (import ../../modules/nixos/services/nginx/sites.nix { inherit lib; })
      .codgician.services.nginx.reverseProxies;

  # `http://127.0.0.1:8096` -> `127.0.0.1:8096`; `http://unix:/run/x.sock` -> `unix:`
  authorityOf = url: lib.head (lib.splitString "/" (lib.last (lib.splitString "://" url)));
  isLocal =
    url:
    let
      authority = authorityOf url;
    in
    lib.hasPrefix "unix:" authority
    || lib.elem (lib.head (lib.splitString ":" authority)) [
      "127.0.0.1"
      "localhost"
    ];

  proxied = lib.mapAttrs (
    _: host:
    lib.filterAttrs (
      _: site: site.proxyPass != null
    ) host.config.codgician.services.nginx.reverseProxies
  ) outputs.nixosConfigurations;

  servedLocally =
    site: lib.any (sites: sites ? ${site} && isLocal sites.${site}.proxyPass) (lib.attrValues proxied);

  unserved = lib.concatLists (
    lib.mapAttrsToList (
      host: sites:
      lib.mapAttrsToList (site: { proxyPass, ... }: "${host} proxies ${site} to ${proxyPass}") (
        lib.filterAttrs (
          site: { proxyPass, ... }: !isLocal proxyPass && !lib.elem site outsideFleet && !servedLocally site
        ) sites
      )
    ) proxied
  );
in
{
  checks.proxiedSitesServed =
    assert lib.assertMsg (unserved == [ ]) ''
      A site proxied to another host is served next to its backend by no host: ${lib.concatStringsSep ", " unserved}.
      Enable the service on a host, or remove its `codgician.services.nginx.reverseProxies.<name>.proxyPass` from the host that proxies it.
    '';
    pkgs.runCommand "proxied-sites-served" { } "touch $out";
}
