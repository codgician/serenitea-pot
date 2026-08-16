{ ref }:
{
  content = ''
    CODGI_PASS=${ref "wireless-codgi-pass"}
    GRASSLAND_PASS=${ref "wireless-grassland-pass"}
  '';
}
