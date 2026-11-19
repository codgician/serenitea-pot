# Sites no module owns: appliances, Proxmox VE, a Home Manager service.
# Declared here so that every host, and Authelia's, knows what they are.
{ lib, ... }:
let
  inherit (lib.codgician) zone;
in
{
  codgician.services.nginx.reverseProxies = {
    bubbles.domains = [ "bubbles.${zone}" ];

    docling-serve.domains = [ "vision.${zone}" ];

    # The dsh Web UI, a Home Manager service on nahida.
    dsh-web = {
      domains = [ "moongazer.${zone}" ];
      authelia.users = [ "codgi" ];
    };

    hass.domains = [ "hass.${zone}" ];

    saw = {
      domains = [ "saw.${zone}" ];
      authelia.groups = [ "saw" ];
    };

    simulanka.domains = [ "simulanka.${zone}" ];
  };
}
