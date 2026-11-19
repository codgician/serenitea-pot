{
  codgician = {
    services = {
      sing-box = {
        enable = true;
        servers.hysteria2.enable = true;
      };

      wireguard.enable = true;
    };

    system.impermanence.wipeOnShutdown.zfs.enable = true;
  };

  services.zfs.autoSnapshot = {
    frequent = 4;
    hourly = 24;
    daily = 7;
    weekly = 0;
    monthly = 0;
    flags = "-k -p --utc";
  };

  boot.kernel.sysctl = {
    "net.core.default_qdisc" = "fq_pie";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };
}
