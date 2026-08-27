# Monitoring configuration for paimon
# - Prometheus metrics from NGINX stub_status and access logs
# - Loki access-log storage with local GeoIP enrichment
# - Grafana provisioned data sources and dashboards
{ config, pkgs, ... }:
let
  # Nginx log path
  nginxAccessLogPath = "/var/log/nginx/access.log";
  nginxGeoAccessLogPath = "/var/log/nginx/access-geo.json";
  geoIpDatabase = "${pkgs.unstable.dbip-city-lite}/share/dbip/dbip-city-lite.mmdb";

  # Nginxlog exporter log format matching our nginx config
  # IMPORTANT: We use mapped variables that convert "-" to "0" for numeric fields
  # because nginx outputs "-" when there's no upstream (e.g., static files, errors)
  # Format: $remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent" $request_time $upstream_time_or_zero $request_length $server_name
  nginxlogFormat = "$remote_addr - $remote_user [$time_local] \"$request\" $status $body_bytes_sent \"$http_referer\" \"$http_user_agent\" $request_time $upstream_response_time $request_length $server_name";
in
{
  # RAS (Reliability, Availability, Serviceability) hardware error monitoring:
  # EDAC (DIMM ECC), PCIe AER (SERR), and CPU MCE events via rasdaemon.
  codgician.services.rasdaemon = {
    enable = true;
    prometheus = {
      enable = true;
      scrapeConfig = true;
    };
  };

  # Prometheus scrape configuration
  codgician.services.prometheus.scrapeConfigs = {
    prometheus = true;
    nginx = true;
    nginxlog = true;
    extraConfigs = [
      {
        job_name = "nvidia-gpu";
        scrape_interval = "5s";
        static_configs = [
          {
            targets = [
              "127.0.0.1:${toString config.services.prometheus.exporters.nvidia-gpu.port}"
            ];
            labels.instance = config.networking.hostName;
          }
        ];
      }
    ];
  };

  # nvidia-smi-based exporter supports consumer GeForce GPUs without DCGM.
  services.prometheus.exporters.nvidia-gpu = {
    enable = true;
    listenAddress = "127.0.0.1";
  };

  systemd.services.prometheus-nvidia-gpu-exporter = {
    after = [ "nvidia-gpu-config.service" ];
    wants = [ "nvidia-gpu-config.service" ];
  };

  # Grafana provisioning
  codgician.services.grafana.provision = {
    prometheus.enable = true;
    dashboards = [
      ../../../modules/nixos/services/grafana/dashboards/nginx.json
      ../../../modules/nixos/services/grafana/dashboards/rasdaemon.json
    ];
  };

  services.grafana.provision.datasources.settings.datasources = [
    {
      name = "Loki";
      uid = "Loki";
      type = "loki";
      access = "proxy";
      url = "http://127.0.0.1:3100";
      editable = false;
      jsonData.maxLines = 1000;
    }
  ];

  # Keep raw client addresses out of Prometheus labels. Loki stores the
  # structured access records and extracts per-client fields at query time.
  services.loki = {
    enable = true;
    configuration = {
      auth_enabled = false;
      analytics.reporting_enabled = false;
      server = {
        http_listen_address = "127.0.0.1";
        http_listen_port = 3100;
      };
      common = {
        instance_addr = "127.0.0.1";
        path_prefix = "/var/lib/loki";
        replication_factor = 1;
        ring.kvstore.store = "inmemory";
        storage.filesystem = {
          chunks_directory = "/var/lib/loki/chunks";
          rules_directory = "/var/lib/loki/rules";
        };
      };
      schema_config.configs = [
        {
          from = "2024-04-01";
          store = "tsdb";
          object_store = "filesystem";
          schema = "v13";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }
      ];
      limits_config = {
        allow_structured_metadata = true;
        retention_period = "168h";
        volume_enabled = true;
      };
      compactor = {
        working_directory = "/var/lib/loki/compactor";
        compaction_interval = "10m";
        retention_enabled = true;
        retention_delete_delay = "2h";
        delete_request_store = "filesystem";
      };
    };
  };

  services.alloy = {
    enable = true;
    extraFlags = [ "--disable-reporting" ];
  };

  environment.etc."alloy/nginx-logs.alloy".text = ''
    local.file_match "nginx_access" {
      path_targets = [{
        __path__ = "${nginxGeoAccessLogPath}",
        instance = constants.hostname,
        job      = "nginx-access",
      }]
    }

    loki.source.file "nginx_access" {
      targets    = local.file_match.nginx_access.targets
      forward_to = [loki.process.nginx_access.receiver]
    }

    loki.process "nginx_access" {
      stage.json {
        expressions = {
          timestamp = "timestamp",
        }
      }

      stage.timestamp {
        source = "timestamp"
        format = "RFC3339"
      }

      forward_to = [loki.write.local.receiver]
    }

    loki.write "local" {
      endpoint {
        url = "http://127.0.0.1:3100/loki/api/v1/push"
      }
    }
  '';

  systemd.services.alloy = {
    after = [ "loki.service" ];
    wants = [ "loki.service" ];
    serviceConfig.SupplementaryGroups = [ "nginx" ];
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
          relabel_configs = [
            # server_name is the NGINX virtual-host identifier for the proxied service.
            {
              target_label = "host";
              from = "server_name";
            }
          ];
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
  # Lumine appends the client address to X-Forwarded-For over the WireGuard network.
  # Trust this explicitly selected WireGuard range to restore $remote_addr for access logs and GeoIP.
  codgician.services.nginx.trustedProxies = [ "192.168.254.0/23" ];
  services.nginx = {
    additionalModules = [ pkgs.nginxModules.geoip2 ];

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

      # Resolve both IPv4 and IPv6 addresses from the immutable unstable
      # DB-IP City Lite MMDB. Unknown/private addresses remain explicit.
      geoip2 ${geoIpDatabase} {
        $geoip_country_code default=ZZ country iso_code;
        $geoip_country_name default=Unknown country names en;
        $geoip_city_name default=Unknown city names en;
        $geoip_latitude default=0 location latitude;
        $geoip_longitude default=0 location longitude;
      }

      log_format metrics '$remote_addr - $remote_user [$time_local] '
                        '"$request" $status $body_bytes_sent '
                        '"$http_referer" "$http_user_agent" '
                        '$request_time $upstream_time_or_zero $request_length $server_name';

      log_format geography escape=json '{'
        '"timestamp":"$time_iso8601",'
        '"remote_addr":"$remote_addr",'
        '"country_code":"$geoip_country_code",'
        '"country":"$geoip_country_name",'
        '"city":"$geoip_city_name",'
        '"latitude":"$geoip_latitude",'
        '"longitude":"$geoip_longitude",'
        '"method":"$request_method",'
        '"host":"$server_name",'
        '"uri":"$uri",'
        '"status":$status,'
        '"request_time":$request_time,'
        '"upstream_time":$upstream_time_or_zero,'
        '"bytes_sent":$body_bytes_sent,'
        '"bytes_received":$request_length'
      '}';
    '';

    # Then use the log format (appendHttpConfig comes after commonHttpConfig)
    appendHttpConfig = ''
      access_log ${nginxAccessLogPath} metrics;
      access_log ${nginxGeoAccessLogPath} geography;
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
    {
      type = "directory";
      path = "/var/lib/loki";
      user = "loki";
      group = "loki";
    }
  ];

  # Ensure log directory exists with correct permissions
  systemd.tmpfiles.rules = [
    "d /var/log/nginx 0755 nginx nginx -"
  ];
}
