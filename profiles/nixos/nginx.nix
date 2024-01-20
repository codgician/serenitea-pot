{ config, ... }: {

  # Nginx global configurations
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    statusPage = true;
  };

  # Enable promethus nginx exporter
  services.prometheus.exporters = {
    nginx.enable = true;
    nginxlog.enable = true;
  };
}
