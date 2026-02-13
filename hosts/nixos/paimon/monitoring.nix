# Monitoring configuration for paimon
# - Prometheus scrape configs for nginx and nginxlog exporters
# - Grafana provisioned datasources and dashboards
# - Nginxlog exporter configuration
{ config, ... }:
let
  # Nginx log path
  nginxAccessLogPath = "/var/log/nginx/access.log";

  # Nginxlog exporter log format matching our nginx config
  # IMPORTANT: We use mapped variables that convert "-" to "0" for numeric fields
  # because nginx outputs "-" when there's no upstream (e.g., static files, errors)
  # Format: $remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent" $request_time $upstream_time_or_zero $request_length
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
    listenAddress = "127.0.0.1"; # Security: bind to localhost only
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

  # Security: bind nginx exporter to localhost only
  services.prometheus.exporters.nginx.listenAddress = "127.0.0.1";

  # Configure nginx to write access logs with the appropriate format
  # Note: commonHttpConfig is evaluated BEFORE appendHttpConfig in nginx config generation
  # So map directives and log_format must be in commonHttpConfig, and access_log in appendHttpConfig
  services.nginx = {
    # Define map directive to convert "-" to "0" for upstream_response_time
    # This is needed because nginx outputs "-" when there's no upstream (static files, errors, etc.)
    # The nginxlog exporter parser expects numeric values and fails on "-"
    # Also define log format here (commonHttpConfig comes before appendHttpConfig)
    commonHttpConfig = ''
      # Map upstream_response_time: convert "-" to "0" for metrics parsing
      map $upstream_response_time $upstream_time_or_zero {
        "-" 0;
        default $upstream_response_time;
      }

      log_format metrics '$remote_addr - $remote_user [$time_local] '
                        '"$request" $status $body_bytes_sent '
                        '"$http_referer" "$http_user_agent" '
                        '$request_time $upstream_time_or_zero $request_length';
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
