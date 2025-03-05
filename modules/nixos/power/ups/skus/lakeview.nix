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
  description = if description == null then "Lakeview UPS" else description;
  port = if port == null then "auto" else port;
  directives =
    [
      "vendorid = 0925"
      "productid = 1234"
      "ondelay = ${toString onDelay}"
      "offdelay = ${toString offDelay}"
    ]
    ++ (lib.optional (product != null) "product = \"${product}\"")
    ++ (lib.optional (serial != null) "serial = \"${serial}\"");
}
