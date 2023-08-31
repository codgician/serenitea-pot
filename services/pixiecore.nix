{ config, ... }: {

  services.pixiecore = rec {
    enable = true;
    openFirewall = true;
    mode = "quick";
    quick = "xyz";
    dhcpNoBind = true;
    port = 8088;
    statusPort = port;
  };
}
