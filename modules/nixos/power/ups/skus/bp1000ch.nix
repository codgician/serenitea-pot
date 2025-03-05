{
  lib,
  description ? null,
  port ? null,
  product ? null,
  serial ? null,
  onDelay,
  offDelay,
  ...
}:

{
  driver = "nutdrv_qx";
  description = if description == null then "APC Back-UPS BP 1000CH" else description;
  port = if port == null then "/dev/ttyS0" else port;
  directives =
    [
      "protocol = voltronic-qs"
      "ondelay = ${toString onDelay}"
      "offdelay = ${toString offDelay}"
    ]
    ++ (lib.optional (product != null) "product = \"${product}\"")
    ++ (lib.optional (serial != null) "serial = \"${serial}\"");
}
