{ ref, pubkeys, ... }:
{
  publicKeys = pubkeys.someHosts [ pubkeys.hosts.zibai ];
  # Consumed by wpa_supplicant via networking.wireless.secretsFile; each KEY is
  # referenced from network config as `ext:<KEY>` (e.g. pskRaw = "ext:GRASSLAND_PASS").
  content = ''
    CODGI_PASS=${ref "wireless-codgi-pass"}
    GRASSLAND_PASS=${ref "wireless-grassland-pass"}
  '';
}
