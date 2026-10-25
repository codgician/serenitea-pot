{
  account = {
    name = "akasha";
    location = "swedencentral";
  };

  deployments = {
    "gpt-image-2" = {
      registry = {
        mode = "image_generation";
        apiVersion = "2025-04-01-preview";
      };
      model = {
        format = "OpenAI";
        name = "gpt-image-2";
        version = "2026-04-21";
      };
      sku = {
        name = "GlobalStandard";
        capacity = 9;
      };
    };

    "gpt-realtime-2.1" = {
      registry = {
        mode = "realtime";
        realtimeProtocol = "GA";
      };
      model = {
        format = "OpenAI";
        name = "gpt-realtime-2.1";
        version = "2026-07-07";
      };
      sku = {
        name = "GlobalStandard";
        capacity = 10;
      };
    };

    "gpt-realtime-2.1-mini" = {
      registry = {
        mode = "realtime";
        realtimeProtocol = "GA";
      };
      model = {
        format = "OpenAI";
        name = "gpt-realtime-2.1-mini";
        version = "2026-07-07";
      };
      sku = {
        name = "GlobalStandard";
        capacity = 10;
      };
    };

    "gpt-image-2.5-flare" = {
      registry = {
        mode = "image_generation";
        apiVersion = "2025-04-01-preview";
      };
      model = {
        format = "OpenAI";
        name = "gpt-image-2.5-flare";
        version = "2026-09-08";
      };
      sku = {
        name = "GlobalStandard";
        capacity = 2;
      };
    };

    "gpt-image-2.5-sunburst" = {
      registry = {
        mode = "image_generation";
        apiVersion = "2025-04-01-preview";
      };
      model = {
        format = "OpenAI";
        name = "gpt-image-2.5-sunburst";
        version = "2026-09-08";
      };
      sku = {
        name = "GlobalStandard";
        capacity = 2;
      };
    };

    "decision-1" = {
      model = {
        format = "Microsoft";
        name = "Microsoft-Decision-1";
        version = "1";
      };
      sku = {
        name = "DataZoneStandard";
        capacity = 2160;
      };
    };

    "mai-image-2.6" = {
      registry = {
        provider = "azure_ai";
        mode = "image_generation";
        baseModel = "azure_ai/MAI-Image-2.6";
      };
      model = {
        format = "Microsoft";
        name = "MAI-Image-2.6";
        version = "2026-07-31";
      };
      sku = {
        name = "GlobalStandard";
        capacity = 6;
      };
    };
  };
}
