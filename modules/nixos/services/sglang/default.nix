{
  config,
  lib,
  ...
}:
let
  serviceName = "sglang";
  cfg = config.codgician.services.sglang;
  inherit (lib) types;

  defaultCacheDir = "/var/lib/llm-cache";
  scrapeHost =
    host:
    if
      builtins.elem host [
        "0.0.0.0"
        "::"
      ]
    then
      "127.0.0.1"
    else
      host;
  dashboard = builtins.toFile "sglang-dashboard.json" (builtins.toJSON (import ./dashboard.nix));

  instanceModule.options = {
    model = lib.mkOption {
      type = types.str;
      description = "ModelScope or Hugging Face model name, or a local model path.";
      example = "Qwen/Qwen3.8-27B-FP8";
    };

    image = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Per-instance image override. Null uses `cfg.image`.";
    };

    host = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Host-side bind address for the published port.";
    };

    port = lib.mkOption {
      type = types.port;
      default = 30000;
      description = "SGLang HTTP server port inside and outside the container.";
    };

    memFractionStatic = lib.mkOption {
      type = types.float;
      default = 0.9;
      description = "Fraction of GPU memory reserved for model weights and the KV cache pool.";
    };

    environmentVariables = lib.mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Environment variables for this instance.";
    };

    extraArgs = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional arguments passed to `sglang.launch_server`.";
      example = [
        "--kv-cache-dtype"
        "fp8_e4m3"
      ];
    };
  };

  mkContainer =
    name: c:
    lib.nameValuePair "${serviceName}-${name}" {
      autoStart = true;
      image = if c.image != null then c.image else cfg.image;
      environment = {
        HF_HUB_DOWNLOAD_TIMEOUT = "600";
      }
      // lib.optionalAttrs config.codgician.system.common.inChina {
        SGLANG_USE_MODELSCOPE = "true";
      }
      // c.environmentVariables;
      volumes = [ "${cfg.cacheDir}:/root/.cache:rw" ];
      ports = [ "${c.host}:${toString c.port}:${toString c.port}" ];
      extraOptions = [
        "--pull=newer"
        "--ipc=host"
        "--ulimit=memlock=-1"
        "--device=nvidia.com/gpu=all"
      ];
      cmd = [
        "python3"
        "-m"
        "sglang.launch_server"
        "--model-path"
        c.model
        "--host"
        "0.0.0.0"
        "--port"
        (toString c.port)
        "--mem-fraction-static"
        (toString c.memFractionStatic)
      ]
      ++ lib.optional cfg.monitoring.enable "--enable-metrics"
      ++ c.extraArgs;
    };
in
{
  options.codgician.services.sglang = {
    enable = lib.mkEnableOption "SGLang inference server (container-based)";

    monitoring.enable = lib.mkEnableOption "Prometheus scraping and the bundled Grafana dashboard";

    image = lib.mkOption {
      type = types.str;
      default = "lmsysorg/sglang:latest";
      description = "Default image ref for instances that do not override `image`.";
    };

    cacheDir = lib.mkOption {
      type = types.path;
      default = defaultCacheDir;
      description = "Shared model cache directory mounted at `/root/.cache`.";
    };

    instances = lib.mkOption {
      type = types.attrsOf (types.submodule instanceModule);
      default = { };
      description = "SGLang server instances. Each receives every NVIDIA GPU through CDI.";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.instances != { }) {
    assertions =
      let
        grouped = lib.groupBy (
          name: "${cfg.instances.${name}.host}:${toString cfg.instances.${name}.port}"
        ) (builtins.attrNames cfg.instances);
      in
      lib.mapAttrsToList (key: names: {
        assertion = builtins.length names == 1;
        message = "codgician.services.sglang: multiple instances bind to ${key} (${lib.concatStringsSep ", " names}).";
      }) grouped
      ++ [
        {
          assertion = config.hardware.nvidia-container-toolkit.enable;
          message = "codgician.services.sglang requires hardware.nvidia-container-toolkit.enable.";
        }
        {
          assertion = !cfg.monitoring.enable || config.codgician.services.prometheus.enable;
          message = "codgician.services.sglang.monitoring requires codgician.services.prometheus.enable.";
        }
        {
          assertion = !cfg.monitoring.enable || config.codgician.services.grafana.enable;
          message = "codgician.services.sglang.monitoring requires codgician.services.grafana.enable.";
        }
      ];

    systemd.tmpfiles.rules = [ "d ${cfg.cacheDir} 0755 root root -" ];

    codgician.system.impermanence.extraItems = lib.optional (cfg.cacheDir == defaultCacheDir) {
      type = "directory";
      path = cfg.cacheDir;
    };

    codgician.services.prometheus.scrapeConfigs.extraConfigs = lib.optional cfg.monitoring.enable {
      job_name = serviceName;
      scrape_interval = "2s";
      metrics_path = "/metrics";
      static_configs = lib.mapAttrsToList (name: c: {
        targets = [ "${scrapeHost c.host}:${toString c.port}" ];
        labels = {
          instance = config.networking.hostName;
          service = name;
        };
      }) cfg.instances;
    };

    codgician.services.grafana.provision.dashboards = lib.optional cfg.monitoring.enable dashboard;

    virtualisation.oci-containers.containers = lib.mapAttrs' mkContainer cfg.instances;
  };
}
