let
  datasource = {
    type = "prometheus";
    uid = "\${datasource}";
  };

  target = refId: expr: legendFormat: {
    inherit
      datasource
      expr
      legendFormat
      refId
      ;
    editorMode = "code";
    instant = false;
    range = true;
  };

  stat =
    {
      id,
      title,
      description,
      x,
      unit,
      expr,
    }:
    {
      inherit
        datasource
        description
        id
        title
        ;
      type = "stat";
      gridPos = {
        h = 4;
        w = 4;
        inherit x;
        y = 0;
      };
      fieldConfig.defaults = {
        color.mode = "thresholds";
        inherit unit;
      };
      options = {
        colorMode = "value";
        graphMode = "area";
        justifyMode = "auto";
        orientation = "auto";
        reduceOptions = {
          calcs = [ "lastNotNull" ];
          fields = "";
          values = false;
        };
        textMode = "auto";
        wideLayout = true;
      };
      targets = [ (target "A" expr "") ];
    };

  timeseries =
    {
      id,
      title,
      description,
      x,
      y,
      w ? 12,
      h ? 8,
      unit,
      targets,
    }:
    {
      inherit
        datasource
        description
        id
        targets
        title
        ;
      type = "timeseries";
      gridPos = {
        inherit
          h
          w
          x
          y
          ;
      };
      fieldConfig.defaults = {
        color.mode = "palette-classic";
        custom = {
          axisBorderShow = false;
          axisCenteredZero = false;
          axisColorMode = "text";
          axisPlacement = "auto";
          drawStyle = "line";
          fillOpacity = 10;
          lineInterpolation = "linear";
          lineWidth = 1;
          pointSize = 5;
          scaleDistribution.type = "linear";
          showPoints = "never";
          spanNulls = true;
          stacking = {
            group = "A";
            mode = "none";
          };
        };
        inherit unit;
      };
      options = {
        legend = {
          calcs = [
            "lastNotNull"
            "mean"
          ];
          displayMode = "table";
          placement = "bottom";
          showLegend = true;
        };
        tooltip = {
          mode = "multi";
          sort = "desc";
        };
      };
    };

  row = id: title: y: {
    inherit id title;
    type = "row";
    collapsed = false;
    gridPos = {
      h = 1;
      w = 24;
      x = 0;
      inherit y;
    };
    panels = [ ];
  };

  selector = ''job="sglang",instance=~"$instance",service=~"$service",model_name=~"$model"'';
  serviceSelector = ''job="sglang",instance=~"$instance",service=~"$service"'';
in
{
  annotations.list = [
    {
      builtIn = 1;
      datasource = {
        type = "grafana";
        uid = "-- Grafana --";
      };
      enable = true;
      hide = true;
      iconColor = "rgba(0, 211, 255, 1)";
      name = "Annotations & Alerts";
      type = "dashboard";
    }
  ];
  description = "SGLang observability for API reliability, user-visible latency, throughput, scheduler and hybrid-model memory pressure, NVIDIA GPU hardware, prefix-cache efficiency, and speculative decoding.";
  editable = true;
  fiscalYearStartMonth = 0;
  graphTooltip = 1;
  id = null;
  links = [ ];
  panels = [
    (stat {
      id = 1;
      title = "SGLang";
      description = "Whether Prometheus can scrape the selected SGLang service.";
      x = 0;
      unit = "none";
      expr = "min(up{${serviceSelector}})";
    })
    (stat {
      id = 2;
      title = "Active requests";
      description = "Requests currently executing on the scheduler; sampled every two seconds.";
      x = 4;
      unit = "short";
      expr = "sum(sglang:num_running_reqs{${selector}})";
    })
    (stat {
      id = 3;
      title = "KV pool utilization";
      description = "Current bottleneck utilization across full-attention KV and hybrid state pools.";
      x = 8;
      unit = "percentunit";
      expr = "max(sglang:token_usage{${selector}})";
    })
    (stat {
      id = 4;
      title = "P95 TTFT (completed, 5m)";
      description = "95th-percentile TTFT among requests observed in the last five minutes. No value means no recent completed sample.";
      x = 12;
      unit = "s";
      expr = "histogram_quantile(0.95, sum by (le) (rate(sglang:time_to_first_token_seconds_bucket{${selector}}[5m])))";
    })
    (stat {
      id = 5;
      title = "Live decode throughput";
      description = "Measured decode tokens per second over the last 10 seconds; returns to zero shortly after generation stops.";
      x = 16;
      unit = "tps";
      expr = "sum(rate(sglang:realtime_tokens_total{${selector},mode=\"decode\"}[10s])) or vector(0)";
    })
    (stat {
      id = 6;
      title = "Queued requests";
      description = "Requests waiting for scheduler capacity.";
      x = 20;
      unit = "short";
      expr = "sum(sglang:num_queue_reqs{${selector}})";
    })

    (row 100 "API Reliability" 4)
    (timeseries {
      id = 7;
      title = "Completed request rate (1m)";
      description = "Requests completed per second over one minute, split by streaming mode. This is completion throughput, not arrivals.";
      x = 0;
      y = 5;
      unit = "reqps";
      targets = [
        (target "A" "sum by (is_streaming) (rate(sglang:num_requests_total{${selector}}[1m]))"
          "streaming={{is_streaming}}"
        )
      ];
    })
    (timeseries {
      id = 8;
      title = "Abort and retraction rate (1m)";
      description = "Completed aborts and scheduler retractions per second over one minute. Retractions indicate memory pressure, not HTTP failures.";
      x = 12;
      y = 5;
      unit = "reqps";
      targets = [
        (target "A" "sum(rate(sglang:num_aborted_requests_total{${selector}}[1m]))" "aborted")
        (target "B" "sum(rate(sglang:num_retracted_requests_total{${selector}}[1m]))" "retracted")
      ];
    })

    (row 101 "User-Visible Latency" 13)
    (timeseries {
      id = 9;
      title = "TTFT of completed requests (5m)";
      description = "TTFT percentiles from requests observed in the last five minutes. Histograms update on request observations, not continuously.";
      x = 0;
      y = 14;
      w = 8;
      unit = "s";
      targets = [
        (target "A"
          "histogram_quantile(0.50, sum by (le) (rate(sglang:time_to_first_token_seconds_bucket{${selector}}[5m])))"
          "P50"
        )
        (target "B"
          "histogram_quantile(0.95, sum by (le) (rate(sglang:time_to_first_token_seconds_bucket{${selector}}[5m])))"
          "P95"
        )
        (target "C"
          "histogram_quantile(0.99, sum by (le) (rate(sglang:time_to_first_token_seconds_bucket{${selector}}[5m])))"
          "P99"
        )
      ];
    })
    (timeseries {
      id = 10;
      title = "Inter-token latency (5m)";
      description = "Token-gap percentiles observed over the last five minutes. These are event histograms, not an instantaneous gauge.";
      x = 8;
      y = 14;
      w = 8;
      unit = "s";
      targets = [
        (target "A"
          "histogram_quantile(0.50, sum by (le) (rate(sglang:inter_token_latency_seconds_bucket{${selector}}[5m])))"
          "P50"
        )
        (target "B"
          "histogram_quantile(0.95, sum by (le) (rate(sglang:inter_token_latency_seconds_bucket{${selector}}[5m])))"
          "P95"
        )
        (target "C"
          "histogram_quantile(0.99, sum by (le) (rate(sglang:inter_token_latency_seconds_bucket{${selector}}[5m])))"
          "P99"
        )
      ];
    })
    (timeseries {
      id = 11;
      title = "End-to-end latency of completed requests (5m)";
      description = "Complete-request latency percentiles observed over five minutes; values appear only after requests finish.";
      x = 16;
      y = 14;
      w = 8;
      unit = "s";
      targets = [
        (target "A"
          "histogram_quantile(0.50, sum by (le) (rate(sglang:e2e_request_latency_seconds_bucket{${selector}}[5m])))"
          "P50"
        )
        (target "B"
          "histogram_quantile(0.95, sum by (le) (rate(sglang:e2e_request_latency_seconds_bucket{${selector}}[5m])))"
          "P95"
        )
        (target "C"
          "histogram_quantile(0.99, sum by (le) (rate(sglang:e2e_request_latency_seconds_bucket{${selector}}[5m])))"
          "P99"
        )
      ];
    })

    (row 102 "Workload & Throughput" 22)
    (timeseries {
      id = 12;
      title = "Live prefill throughput";
      description = "Prompt tokens actually computed and served from cache per second over the last 10 seconds.";
      x = 0;
      y = 23;
      w = 8;
      unit = "tps";
      targets = [
        (target "A"
          "sum(rate(sglang:realtime_tokens_total{${selector},mode=\"prefill_compute\"}[10s])) or vector(0)"
          "computed"
        )
        (target "B"
          "sum(rate(sglang:realtime_tokens_total{${selector},mode=\"prefill_cache\"}[10s])) or vector(0)"
          "cache hit"
        )
      ];
    })
    (timeseries {
      id = 13;
      title = "Live prefix-cache throughput by tier";
      description = "Effective prompt tokens served from device, host, or storage cache over the last 10 seconds.";
      x = 8;
      y = 23;
      w = 8;
      unit = "tps";
      targets = [
        (target "A"
          "sum by (mode) (rate(sglang:prefill_effective_tokens_total{${selector},mode=~\"device_hit|host_hit|storage_hit\"}[10s]))"
          "{{mode}}"
        )
      ];
    })
    (timeseries {
      id = 14;
      title = "Live decode throughput";
      description = "Measured decode tokens per second over the last 10 seconds. This counter tracks actual work and returns to zero after generation stops.";
      x = 16;
      y = 23;
      w = 8;
      unit = "tps";
      targets = [
        (target "A" "sum(rate(sglang:realtime_tokens_total{${selector},mode=\"decode\"}[10s])) or vector(0)"
          "measured decode rate"
        )
      ];
    })

    (row 103 "Scheduler & Capacity" 31)
    (timeseries {
      id = 15;
      title = "Scheduler queue time of admitted requests (5m)";
      description = "Queue-time percentiles observed during admissions over five minutes; this is historical. Current queue depth is shown beside it.";
      x = 0;
      y = 32;
      w = 8;
      unit = "s";
      targets = [
        (target "A"
          "histogram_quantile(0.50, sum by (le) (rate(sglang:queue_time_seconds_bucket{${selector}}[5m])))"
          "P50"
        )
        (target "B"
          "histogram_quantile(0.95, sum by (le) (rate(sglang:queue_time_seconds_bucket{${selector}}[5m])))"
          "P95"
        )
        (target "C"
          "histogram_quantile(0.99, sum by (le) (rate(sglang:queue_time_seconds_bucket{${selector}}[5m])))"
          "P99"
        )
      ];
    })
    (timeseries {
      id = 16;
      title = "Scheduler requests";
      description = "Requests currently running, queued, or retracted.";
      x = 8;
      y = 32;
      w = 8;
      unit = "short";
      targets = [
        (target "A" "sum(sglang:num_running_reqs{${selector}})" "running")
        (target "B" "sum(sglang:num_queue_reqs{${selector}})" "queued")
        (target "C" "sum(sglang:num_retracted_reqs{${selector}})" "retracted")
      ];
    })
    (timeseries {
      id = 17;
      title = "Memory-pool utilization";
      description = "Bottleneck, full-attention KV, and Mamba state-pool utilization.";
      x = 16;
      y = 32;
      w = 8;
      unit = "percentunit";
      targets = [
        (target "A" "max(sglang:token_usage{${selector}})" "bottleneck")
        (target "B" "max(sglang:full_token_usage{${selector}})" "full KV")
        (target "C" "max(sglang:mamba_usage{${selector}})" "Mamba state")
      ];
    })
    (timeseries {
      id = 18;
      title = "KV-cache token slots";
      description = "Active, evictable, and immediately available full-attention KV-cache slots.";
      x = 0;
      y = 40;
      w = 12;
      unit = "short";
      targets = [
        (target "A" "sum(sglang:kv_used_tokens{${selector}})" "used")
        (target "B" "sum(sglang:kv_evictable_tokens{${selector}})" "evictable")
        (target "C" "sum(sglang:kv_available_tokens{${selector}})" "available")
      ];
    })
    (timeseries {
      id = 19;
      title = "Mamba state slots";
      description = "Active, evictable, and available hybrid-model state slots.";
      x = 12;
      y = 40;
      w = 12;
      unit = "short";
      targets = [
        (target "A" "sum(sglang:mamba_used_tokens{${selector}})" "used")
        (target "B" "sum(sglang:mamba_evictable_tokens{${selector}})" "evictable")
        (target "C" "sum(sglang:mamba_available_tokens{${selector}})" "available")
      ];
    })

    (row 104 "GPU Hardware" 48)
    (timeseries {
      id = 20;
      title = "GPU core frequency";
      description = "Current GPU graphics clock frequency.";
      x = 0;
      y = 49;
      w = 6;
      unit = "hertz";
      targets = [
        (target "A" ''nvidia_smi_clocks_current_graphics_clock_hz{job="nvidia-gpu",instance=~"$instance"}''
          "GPU {{minor_number}}"
        )
      ];
    })
    (timeseries {
      id = 21;
      title = "VRAM utilization";
      description = "Framebuffer memory in use as a percentage of total VRAM.";
      x = 6;
      y = 49;
      w = 6;
      unit = "percent";
      targets = [
        (target "A"
          ''100 * nvidia_smi_memory_used_bytes{job="nvidia-gpu",instance=~"$instance"} / nvidia_smi_memory_total_bytes{job="nvidia-gpu",instance=~"$instance"}''
          "GPU {{minor_number}}"
        )
      ];
    })
    (timeseries {
      id = 22;
      title = "GPU compute utilization";
      description = "Percentage of the collection interval spent executing GPU kernels.";
      x = 12;
      y = 49;
      w = 6;
      unit = "percent";
      targets = [
        (target "A" ''100 * nvidia_smi_utilization_gpu_ratio{job="nvidia-gpu",instance=~"$instance"}''
          "GPU {{minor_number}}"
        )
      ];
    })
    (timeseries {
      id = 23;
      title = "Power draw / limit";
      description = "Current board power draw and enforced power limit.";
      x = 18;
      y = 49;
      w = 6;
      unit = "watt";
      targets = [
        (target "A" ''nvidia_smi_power_draw_watts{job="nvidia-gpu",instance=~"$instance"}''
          "draw GPU {{minor_number}}"
        )
        (target "B"
          ''nvidia_smi_enforced_power_limit_watts{job="nvidia-gpu",instance=~"$instance"} or nvidia_smi_power_limit_watts{job="nvidia-gpu",instance=~"$instance"}''
          "limit GPU {{minor_number}}"
        )
      ];
    })

    (row 105 "Prefix Cache Efficiency" 57)
    (timeseries {
      id = 24;
      title = "Prefix cache hit rate (1m)";
      description = "Counter-derived share of effective prefill tokens served from any cache tier over one minute.";
      x = 0;
      y = 58;
      unit = "percentunit";
      targets = [
        (target "A"
          "sum(rate(sglang:prefill_effective_tokens_total{${selector},mode=~\"device_hit|host_hit|storage_hit\"}[1m])) / clamp_min(sum(rate(sglang:prefill_effective_tokens_total{${selector}}[1m])), 1e-9)"
          "hit rate"
        )
      ];
    })
    (timeseries {
      id = 25;
      title = "Live prefill token disposition";
      description = "Effective prefill token rates by compute and cache tier over the last 10 seconds.";
      x = 12;
      y = 58;
      unit = "tps";
      targets = [
        (target "A" "sum by (mode) (rate(sglang:prefill_effective_tokens_total{${selector}}[10s]))"
          "{{mode}}"
        )
      ];
    })

    (row 106 "Speculative Decoding" 66)
    (timeseries {
      id = 26;
      title = "Last-window draft acceptance rate";
      description = "Acceptance rate from SGLang's most recently published decode reporting window; it is not recalculated while idle.";
      x = 0;
      y = 67;
      w = 8;
      unit = "percentunit";
      targets = [ (target "A" "avg(sglang:spec_accept_rate{${selector}})" "acceptance rate") ];
    })
    (timeseries {
      id = 27;
      title = "Last-window mean acceptance length";
      description = "Mean accepted length from SGLang's most recently published decode window, including the bonus token.";
      x = 8;
      y = 67;
      w = 8;
      unit = "short";
      targets = [ (target "A" "avg(sglang:spec_accept_length{${selector}})" "accepted tokens") ];
    })
    (timeseries {
      id = 28;
      title = "Active speculative configuration";
      description = "Runtime speculative steps and draft-token count.";
      x = 16;
      y = 67;
      w = 8;
      unit = "short";
      targets = [
        (target "A" "max(sglang:spec_num_steps{${selector}})" "steps")
        (target "B" "max(sglang:spec_num_draft_tokens{${selector}})" "draft tokens")
      ];
    })
  ];
  refresh = "2s";
  schemaVersion = 41;
  tags = [
    "sglang"
    "llm"
    "prometheus"
    "gpu"
  ];
  templating.list = [
    {
      name = "datasource";
      label = "Prometheus";
      type = "datasource";
      query = "prometheus";
      current = {
        selected = false;
        text = "Prometheus";
        value = "Prometheus";
      };
      options = [ ];
      refresh = 1;
    }
    {
      inherit datasource;
      allValue = ".*";
      name = "instance";
      label = "Instance";
      type = "query";
      definition = ''label_values(up{job="sglang"}, instance)'';
      query = {
        query = ''label_values(up{job="sglang"}, instance)'';
        refId = "PrometheusVariableQueryEditor-Instance";
      };
      includeAll = true;
      multi = true;
      refresh = 2;
      options = [ ];
      current = {
        selected = false;
        text = "All";
        value = "$__all";
      };
    }
    {
      inherit datasource;
      allValue = ".*";
      name = "service";
      label = "Service";
      type = "query";
      definition = ''label_values(up{job="sglang",instance=~"$instance"}, service)'';
      query = {
        query = ''label_values(up{job="sglang",instance=~"$instance"}, service)'';
        refId = "PrometheusVariableQueryEditor-Service";
      };
      includeAll = true;
      multi = true;
      refresh = 2;
      options = [ ];
      current = {
        selected = false;
        text = "All";
        value = "$__all";
      };
    }
    {
      inherit datasource;
      allValue = ".*";
      name = "model";
      label = "Model";
      type = "query";
      definition = ''label_values(sglang:num_running_reqs{job="sglang",instance=~"$instance",service=~"$service"}, model_name)'';
      query = {
        query = ''label_values(sglang:num_running_reqs{job="sglang",instance=~"$instance",service=~"$service"}, model_name)'';
        refId = "PrometheusVariableQueryEditor-Model";
      };
      includeAll = true;
      multi = true;
      refresh = 2;
      options = [ ];
      current = {
        selected = false;
        text = "All";
        value = "$__all";
      };
    }
  ];
  time = {
    from = "now-30m";
    to = "now";
  };
  timepicker = { };
  timezone = "browser";
  title = "SGLang Inference Overview";
  uid = "sglang-inference-overview";
  version = 2;
  weekStart = "";
}
