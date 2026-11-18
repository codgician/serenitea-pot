{
  config,
  pkgs,
  outputs,
  ...
}:
let
  dnsRecords =
    outputs.packages.${pkgs.stdenv.hostPlatform.system}.terraform-config.config.resource.cloudflare_dns_record;
  # Tencent's stable DHCP address, mapped 1:1 to the public IPv4 address.
  privateIPv4 = "10.6.4.16";
in
{
  codgician = {
    services = {
      coturn = {
        relay-ips = [
          privateIPv4
          dnsRecords."${config.networking.hostName}-aaaa".content
        ];
        external-ips = [ "${dnsRecords."${config.networking.hostName}-a".content}/${privateIPv4}" ];
      };

      nginx.landingPage = {
        domain = "codgi.cn";
        footer = ''
          Coming Soon...
          <footer>
            <a href="https://beian.miit.gov.cn/">蜀ICP备2026006850号</a>
          </footer>'';
      };

      sing-box = {
        users = [
          "codgi"
          "lxm75"
          "itscd"
        ];
        servers.shadowsocks = {
          enable = true;
          port = 8444;
        };
      };
    };

    system.common.inChina = true;
  };

  home-manager.users.codgi.codgician.codgi.oh-my-pi.enable = true;

  networking.hostId = "f52ce96f";

  # Use grub bootloader
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    zfsSupport = true;
  };

  system.stateVersion = "26.05";
}
