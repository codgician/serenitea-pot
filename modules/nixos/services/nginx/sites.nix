# Sites no module owns: appliances, Proxmox VE.
# Declared here so that every host, and Authelia's, knows what they are.
{ lib, ... }:
let
  inherit (lib.codgician) zone;
in
{
  codgician.services.nginx.reverseProxies = {
    bubbles.domains = [ "bubbles.${zone}" ];

    hass.domains = [ "hass.${zone}" ];

    saw = {
      domains = [ "saw.${zone}" ];
      authelia.groups = [ "saw" ];
    };

    simulanka.domains = [ "simulanka.${zone}" ];
  };
}
