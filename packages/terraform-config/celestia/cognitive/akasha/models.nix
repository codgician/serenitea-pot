{
  account = {
    name = "akasha";
    location = "swedencentral";
  };

  deployments = {
    "deepseek-v4-flash" = {
      registry.provider = "azure_ai";
      model = {
        format = "DeepSeek";
        name = "DeepSeek-V4-Flash";
        version = "2026-04-23";
      };
      sku = {
        name = "GlobalStandard";
        capacity = 20;
      };
    };

    "deepseek-v4-pro" = {
      registry.provider = "azure_ai";
      model = {
        format = "DeepSeek";
        name = "DeepSeek-V4-Pro";
        version = "2026-04-23";
      };
      sku = {
        name = "GlobalStandard";
        capacity = 20;
      };
    };

    "flux-2-pro" = {
      registry = {
        provider = "azure_ai";
        mode = "image_generation";
        baseModel = "azure_ai/FLUX.2-pro";
      };
      model = {
        format = "Black Forest Labs";
        name = "FLUX.2-pro";
        version = "1";
      };
      sku = {
        name = "GlobalStandard";
        capacity = 30;
      };
    };

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

    "grok-4.3" = {
      registry.provider = "azure_ai";
      model = {
        format = "xAI";
        name = "grok-4.3";
        version = "1";
      };
      sku = {
        name = "GlobalStandard";
        capacity = 50;
      };
    };

    "kimi-k2.6" = {
      registry.provider = "azure_ai";
      model = {
        format = "MoonshotAI";
        name = "Kimi-K2.6";
        version = "2026-04-20";
      };
      sku = {
        name = "GlobalStandard";
        capacity = 20;
      };
    };
  };
}
