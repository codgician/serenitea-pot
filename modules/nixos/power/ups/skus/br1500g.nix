{
  lib,
  description ? "APC Back-UPS RS 1500G",
  port ? null,
  product ? null,
  serial ? null,
  onDelay,
  offDelay,
  batteryLow,
  ...
}:

{
  driver = "usbhid-ups";
  description = if description == null then "APC Back-UPS RS 1500G" else description;
  port = if port == null then "auto" else port;
  directives =
    [
      "vendorid = 051D"
      "productid = 0002"
      "vendor = \"American Power Conversion\""
      "ondelay = ${toString onDelay}"
      "offdelay = ${toString offDelay}"
      "override.battery.charge.low = ${toString batteryLow}"
    ]
    ++ (lib.optional (product != null) "product = \"${product}\"")
    ++ (lib.optional (serial != null) "serial = \"${serial}\"");
}
