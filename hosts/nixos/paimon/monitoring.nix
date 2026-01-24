# Monitoring configuration for paimon
# - Prometheus scrape configs for nginx and nginxlog exporters
# - Grafana provisioned datasources and dashboards
# - Nginxlog exporter configuration
{ config, ... }:
let
  # Nginx log path
  nginxAccessLogPath = "/var/log/nginx/access.log";

  # Nginxlog exporter log format matching our nginx config
  # Format: $remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent" $request_time $upstream_response_time $request_length
  nginxlogFormat = "$remote_addr - $remote_user [$time_local] \"$request\" $status $body_bytes_sent \"$http_referer\" \"$http_user_agent\" $request_time $upstream_response_time $request_length";
in
{
  # Prometheus scrape configuration
  codgician.services.prometheus.scrapeConfigs = {
    prometheus = true;
    nginx = true;
    nginxlog = true;
  };

  # Grafana provisioning
  codgician.services.grafana.provision = {
    prometheus.enable = true;
    dashboards = [
      ../../../modules/nixos/services/grafana/dashboards/nginx.json
    ];
  };

  # Enable and configure nginxlog exporter
  services.prometheus.exporters.nginxlog = {
    enable = true;
    group = "nginx";
    settings = {
      namespaces = [
        {
          name = "nginxlog";
          format = nginxlogFormat;
          source = {
            files = [ nginxAccessLogPath ];
          };
          histogram_buckets = [
            0.005
            0.01
            0.025
            0.05
            0.1
            0.25
            0.5
            1
            2.5
            5
            10
          ];
        }
      ];
    };
  };

  # Configure nginx to write access logs with the appropriate format
  # Note: commonHttpConfig is evaluated BEFORE appendHttpConfig in nginx config generation
  # So log_format must be in commonHttpConfig, and access_log in appendHttpConfig
  services.nginx = {
    # Define log format first (commonHttpConfig comes before appendHttpConfig)
    commonHttpConfig = ''
      log_format metrics '$remote_addr - $remote_user [$time_local] '
                        '"$request" $status $body_bytes_sent '
                        '"$http_referer" "$http_user_agent" '
                        '$request_time $upstream_response_time $request_length';
    '';

    # Then use the log format (appendHttpConfig comes after commonHttpConfig)
    appendHttpConfig = ''
      access_log ${nginxAccessLogPath} metrics;
    '';
  };

  # Persist nginx logs
  codgician.system.impermanence.extraItems = [
    {
      type = "directory";
      path = "/var/log/nginx";
      user = "nginx";
      group = "nginx";
    }
  ];

  # Ensure log directory exists with correct permissions
  systemd.tmpfiles.rules = [
    "d /var/log/nginx 0755 nginx nginx -"
  ];
}
