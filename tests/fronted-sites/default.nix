# A host that fronts a site and the host that serves it are configured in
# different places, and no host evaluates another. Whether the two agree is
# checked here, over all hosts at once.
{
  lib,
  pkgs,
  outputs,
  ...
}:
let
  nginxOf = lib.mapAttrs (_: host: host.config.codgician.services.nginx) outputs.nixosConfigurations;

  servedElsewhere =
    host: site:
    lib.any (nginx: (nginx.reverseProxies.${site}.proxyPass or null) != null) (
      lib.attrValues (removeAttrs nginxOf [ host ])
    );

  unserved = lib.concatLists (
    lib.mapAttrsToList (
      host: nginx:
      map (site: "${host} fronts ${site}") (
        lib.filter (site: !servedElsewhere host site) (lib.attrNames nginx.fronts)
      )
    ) nginxOf
  );
in
{
  frontedSitesServed =
    assert lib.assertMsg (unserved == [ ]) ''
      A fronted site has no host that serves it: ${lib.concatStringsSep ", " unserved}.
      Enable the service on a host, or remove the entry from `codgician.services.nginx.fronts`.
    '';
    pkgs.runCommand "fronted-sites-served" { } "touch $out";
}
