{ ref }:
{
  owner = "sing-box";
  group = "sing-box";
  mode = "0600";
  content = "${ref "sing-ss-password"}:${ref "sing-lxm75-ss-password"}";
}
