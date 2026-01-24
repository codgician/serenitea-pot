{
  pkgs,
  lib,
  outputs,
}:
let
  terraformConf =
    builtins.fromJSON
      outputs.packages.${pkgs.stdenv.hostPlatform.system}.terraform-config.value;
  azureSubdomain = terraformConf.resource.azurerm_ai_services.akasha.custom_subdomain_name;
  deployedModelNames = lib.mapAttrsToList (_: v: v.name) (
    terraformConf.resource.azurerm_cognitive_deployment or { }
  );

  # Azure models
  azureModelDefinitions = [
    {
      model_name = "deepseek-r1";
      provider = "azure_ai";
      model_info.mode = "chat";
      model_info.base_model = "azure_ai/deepseek-r1";
    }
    {
      model_name = "deepseek-v3.2";
      provider = "azure_ai";
      model_info.mode = "chat";
      model_info.base_model = "azure_ai/deepseek-v3.2";
    }
    {
      model_name = "deepseek-v3.2-speciale";
      provider = "azure_ai";
      model_info.mode = "chat";
      model_info.base_model = "azure_ai/deepseek-v3.2-speciale";
    }
    {
      model_name = "flux-1-1-pro";
      provider = "azure_ai";
      model_info.mode = "image_generation";
      model_info.base_model = "azure_ai/FLUX-1.1-pro";
    }
    {
      model_name = "flux-1-kontext-pro";
      provider = "azure_ai";
      model_info.mode = "image_generation";
      model_info.base_model = "azure_ai/FLUX.1-Kontext-pro";
    }
    {
      model_name = "gpt-4o-transcribe-diarize";
      model_info.mode = "audio_transcription";
      model_info.base_model = "azure/gpt-4o-transcribe-diarize";
    }
    {
      model_name = "gpt-5.2-chat";
      model_info.mode = "chat";
      model_info.base_model = "azure/gpt-5.2-chat";
    }
    {
      model_name = "gpt-5.1-chat";
      model_info.mode = "chat";
      model_info.base_model = "azure/gpt-5.1-chat";
    }
    {
      model_name = "gpt-5-chat";
      model_info.mode = "chat";
      model_info.base_model = "azure/gpt-5-chat";
    }
    {
      model_name = "gpt-5-nano";
      model_info.mode = "chat";
      model_info.base_model = "azure/gpt-5-nano";
    }
    {
      model_name = "gpt-audio";
      model_info.mode = "chat";
      model_info.base_model = "azure/gpt-audio-2025-08-28";
    }
    {
      model_name = "gpt-audio-mini";
      model_info.mode = "chat";
      model_info.base_model = "azure/gpt-audio-mini-2025-10-06";
    }
    {
      model_name = "gpt-oss-120b";
      provider = "azure_ai";
      model_info.mode = "chat";
      model_info.base_model = "azure_ai/gpt-oss-120b";
    }
    {
      model_name = "gpt-realtime";
      model_info.mode = "realtime";
      model_info.base_model = "azure/gpt-realtime-2025-08-28";
    }
    {
      model_name = "grok-3";
      provider = "azure_ai";
      model_info.mode = "chat";
      model_info.base_model = "azure_ai/grok-3";
    }
    {
      model_name = "grok-4-fast-non-reasoning";
      provider = "azure_ai";
      model_info.mode = "chat";
      model_info.base_model = "azure_ai/grok-4-fast-non-reasoning";
    }
    {
      model_name = "grok-4-fast-reasoning";
      provider = "azure_ai";
      model_info.mode = "chat";
      model_info.base_model = "azure_ai/grok-4-fast-reasoning";
    }
    {
      model_name = "kimi-k2-thinking";
      provider = "azure_ai";
      model_info.mode = "chat";
      model_info.base_model = "azure_ai/kimi-k2-thinking";
    }
    {
      model_name = "o4-mini";
      model_info.mode = "chat";
      model_info.base_model = "azure/o4-mini";
    }
  ];

  # Google models
  googleModelDefinitions = [
    {
      model_name = "gemini-2.5-flash";
      model_info.mode = "chat";
      model_info.base_model = "gemini/gemini-2.5-flash";
    }
    {
      model_name = "gemini-3-pro-image-preview";
      model_info.mode = "image_generation";
      model_info.base_model = "gemini/gemini-3-pro-image-preview";
    }
    {
      model_name = "gemini-2.5-flash-image";
      model_info.mode = "image_generation";
      model_info.base_model = "gemini/gemini-2.5-flash-image";
    }
  ];

  # GitHub Copilot models
  githubModelDefinitions = [
    # Claude models
    {
      model_name = "claude-haiku-4.5";
      model_info = {
        mode = "chat";
        max_input_tokens = 128000;
        max_output_tokens = 16000;
        max_tokens = 16000;
        supports_function_calling = true;
        supports_parallel_function_calling = true;
        supports_vision = true;
      };
    }
    {
      model_name = "claude-opus-4.5";
      model_info = {
        mode = "chat";
        max_input_tokens = 128000;
        max_output_tokens = 16000;
        max_tokens = 16000;
        supports_function_calling = true;
        supports_parallel_function_calling = true;
        supports_vision = true;
      };
    }
    {
      model_name = "claude-opus-41";
      model_info = {
        mode = "chat";
        max_input_tokens = 80000;
        max_output_tokens = 16000;
        max_tokens = 16000;
        supports_vision = true;
      };
    }
    {
      model_name = "claude-sonnet-4";
      model_info = {
        mode = "chat";
        max_input_tokens = 128000;
        max_output_tokens = 16000;
        max_tokens = 16000;
        supports_function_calling = true;
        supports_parallel_function_calling = true;
        supports_vision = true;
      };
    }
    {
      model_name = "claude-sonnet-4.5";
      model_info = {
        mode = "chat";
        max_input_tokens = 128000;
        max_output_tokens = 16000;
        max_tokens = 16000;
        supports_function_calling = true;
        supports_parallel_function_calling = true;
        supports_vision = true;
      };
    }

    # Gemini models
    {
      model_name = "gemini-2.5-pro";
      model_info = {
        mode = "chat";
        max_input_tokens = 128000;
        max_output_tokens = 64000;
        max_tokens = 64000;
        supports_function_calling = true;
        supports_parallel_function_calling = true;
        supports_vision = true;
      };
    }
    {
      model_name = "gemini-3-flash-preview";
      model_info = {
        mode = "chat";
        max_input_tokens = 128000;
        max_output_tokens = 64000;
        max_tokens = 64000;
        supports_function_calling = true;
        supports_parallel_function_calling = true;
        supports_response_schema = true;
        supports_vision = true;
      };
    }
    {
      model_name = "gemini-3-pro-preview";
      model_info = {
        mode = "chat";
        max_input_tokens = 128000;
        max_output_tokens = 64000;
        max_tokens = 64000;
        supports_function_calling = true;
        supports_parallel_function_calling = true;
        supports_vision = true;
      };
    }

    # GPT-3.5 models
    {
      model_name = "gpt-3.5-turbo";
      model_info = {
        mode = "chat";
        max_input_tokens = 16384;
        max_output_tokens = 4096;
        max_tokens = 4096;
        supports_function_calling = true;
      };
    }
    {
      model_name = "gpt-3.5-turbo-0613";
      model_info = {
        mode = "chat";
        max_input_tokens = 16384;
        max_output_tokens = 4096;
        max_tokens = 4096;
        supports_function_calling = true;
      };
    }

    # GPT-4 models
    {
      model_name = "gpt-4";
      model_info = {
        mode = "chat";
        max_input_tokens = 32768;
        max_output_tokens = 4096;
        max_tokens = 4096;
        supports_function_calling = true;
      };
    }
    {
      model_name = "gpt-4-0613";
      model_info = {
        mode = "chat";
        max_input_tokens = 32768;
        max_output_tokens = 4096;
        max_tokens = 4096;
        supports_function_calling = true;
      };
    }
    {
      model_name = "gpt-4-o-preview";
      model_info = {
        mode = "chat";
        max_input_tokens = 64000;
        max_output_tokens = 4096;
        max_tokens = 4096;
        supports_function_calling = true;
        supports_parallel_function_calling = true;
      };
    }
    {
      model_name = "gpt-4.1";
      model_info = {
        mode = "chat";
        max_input_tokens = 128000;
        max_output_tokens = 16384;
        max_tokens = 16384;
        supports_function_calling = true;
        supports_parallel_function_calling = true;
        supports_response_schema = true;
        supports_vision = true;
      };
    }
    {
      model_name = "gpt-4.1-2025-04-14";
      model_info = {
        mode = "chat";
        max_input_tokens = 128000;
        max_output_tokens = 16384;
        max_tokens = 16384;
        supports_function_calling = true;
        supports_parallel_function_calling = true;
        supports_response_schema = true;
        supports_vision = true;
      };
    }
    {
      model_name = "gpt-41-copilot";
      model_info.mode = "completion";
    }
    {
      model_name = "gpt-4o";
      model_info = {
        mode = "chat";
        max_input_tokens = 64000;
        max_output_tokens = 4096;
        max_tokens = 4096;
        supports_function_calling = true;
        supports_parallel_function_calling = true;
        supports_vision = true;
      };
    }
    {
      model_name = "gpt-4o-2024-05-13";
      model_info = {
        mode = "chat";
        max_input_tokens = 64000;
        max_output_tokens = 4096;
        max_tokens = 4096;
        supports_function_calling = true;
        supports_parallel_function_calling = true;
        supports_vision = true;
      };
    }
    {
      model_name = "gpt-4o-2024-08-06";
      model_info = {
        mode = "chat";
        max_input_tokens = 64000;
        max_output_tokens = 16384;
        max_tokens = 16384;
        supports_function_calling = true;
        supports_parallel_function_calling = true;
      };
    }
    {
      model_name = "gpt-4o-2024-11-20";
      model_info = {
        mode = "chat";
        max_input_tokens = 64000;
        max_output_tokens = 16384;
        max_tokens = 16384;
        supports_function_calling = true;
        supports_parallel_function_calling = true;
        supports_vision = true;
      };
    }
    {
      model_name = "gpt-4o-mini";
      model_info = {
        mode = "chat";
        max_input_tokens = 64000;
        max_output_tokens = 4096;
        max_tokens = 4096;
        supports_function_calling = true;
        supports_parallel_function_calling = true;
      };
    }
    {
      model_name = "gpt-4o-mini-2024-07-18";
      model_info = {
        mode = "chat";
        max_input_tokens = 64000;
        max_output_tokens = 4096;
        max_tokens = 4096;
        supports_function_calling = true;
        supports_parallel_function_calling = true;
      };
    }

    # GPT-5 models
    {
      model_name = "gpt-5";
      model_info = {
        mode = "chat";
        max_input_tokens = 128000;
        max_output_tokens = 128000;
        max_tokens = 128000;
        supports_function_calling = true;
        supports_parallel_function_calling = true;
        supports_response_schema = true;
        supports_vision = true;
      };
    }
    {
      model_name = "gpt-5-codex";
      model_info.mode = "responses";
    }
    {
      model_name = "gpt-5-mini";
      model_info = {
        mode = "chat";
        max_input_tokens = 128000;
        max_output_tokens = 64000;
        max_tokens = 64000;
        supports_function_calling = true;
        supports_parallel_function_calling = true;
        supports_response_schema = true;
        supports_vision = true;
      };
    }
    {
      model_name = "gpt-5.1";
      model_info = {
        mode = "chat";
        max_input_tokens = 128000;
        max_output_tokens = 64000;
        max_tokens = 64000;
        supports_function_calling = true;
        supports_parallel_function_calling = true;
        supports_response_schema = true;
        supports_vision = true;
      };
    }
    {
      model_name = "gpt-5.1-codex";
      model_info.mode = "responses";
    }
    {
      model_name = "gpt-5.1-codex-max";
      model_info = {
        mode = "responses";
        max_input_tokens = 128000;
        max_output_tokens = 128000;
        max_tokens = 128000;
        supports_function_calling = true;
        supports_parallel_function_calling = true;
        supports_response_schema = true;
        supports_vision = true;
      };
    }
    {
      model_name = "gpt-5.1-codex-mini";
      model_info = {
        mode = "responses";
        max_input_tokens = 128000;
        max_output_tokens = 128000;
        max_tokens = 128000;
        supports_function_calling = true;
        supports_parallel_function_calling = true;
        supports_response_schema = true;
        supports_vision = true;
      };
    }
    {
      model_name = "gpt-5.2";
      model_info = {
        mode = "chat";
        max_input_tokens = 128000;
        max_output_tokens = 64000;
        max_tokens = 64000;
        supports_function_calling = true;
        supports_parallel_function_calling = true;
        supports_response_schema = true;
        supports_vision = true;
      };
    }
    {
      model_name = "gpt-5.2-codex";
      model_info = {
        mode = "responses";
        max_input_tokens = 272000;
        max_output_tokens = 128000;
        max_tokens = 128000;
        supports_function_calling = true;
        supports_parallel_function_calling = true;
        supports_response_schema = true;
        supports_vision = true;
      };
    }

    # Embedding models
    {
      model_name = "text-embedding-3-small";
      model_info = {
        mode = "embedding";
        max_input_tokens = 8191;
        max_tokens = 8191;
      };
    }
    {
      model_name = "text-embedding-3-small-inference";
      model_info = {
        mode = "embedding";
        max_input_tokens = 8191;
        max_tokens = 8191;
      };
    }
    {
      model_name = "text-embedding-ada-002";
      model_info = {
        mode = "embedding";
        max_input_tokens = 8191;
        max_tokens = 8191;
      };
    }
  ];

  # Nvidia NIM models
  nvidiaModelDefinitions = [
    {
      model_name = "z-ai/glm4.7";
      model_info.mode = "chat";
    }
    {
      model_name = "minimaxai/minimax-m2.1";
      model_info.mode = "chat";
    }
  ];

  missingAzureModels = lib.filter (
    m: !(builtins.elem m.model_name deployedModelNames)
  ) azureModelDefinitions;
in
assert lib.assertMsg (missingAzureModels == [ ])
  "The following Azure models are defined in LiteLLM but not found in Terraform configuration: ${
    builtins.concatStringsSep ", " (map (m: m.model_name) missingAzureModels)
  }";
rec {
  # Everything
  all = azure ++ deepseek ++ google ++ github ++ nvidia;

  # Azure AI models
  azure = builtins.map (
    {
      model_name,
      model_info ? { },
      provider ? "azure",
      litellm_params ? { },
    }:
    {
      inherit model_name model_info;
      litellm_params = {
        model = "${provider}/${model_name}";
        api_base = "https://${azureSubdomain}.services.ai.azure.com";
        api_key = "os.environ/AZURE_AKASHA_API_KEY";
      }
      // litellm_params;
    }
  ) azureModelDefinitions;

  # Deepseek models
  deepseek =
    builtins.map
      (model_name: {
        inherit model_name;
        model_info = {
          mode = "chat";
          base_model = "deepseek/${model_name}";
        };
        litellm_params = {
          model = "deepseek/${model_name}";
          api_key = "os.environ/DEEPSEEK_API_KEY";
        };
      })
      [
        "deepseek-chat"
        "deepseek-reasoner"
      ];

  # Google Cloud models
  google = builtins.map (
    {
      model_name,
      model_info ? { },
      litellm_params ? { },
    }:
    {
      inherit model_name model_info;
      litellm_params = {
        model = "gemini/${model_name}";
        api_key = "os.environ/GEMINI_API_KEY";
      }
      // litellm_params;
    }
  ) googleModelDefinitions;

  # GitHub Copilot models
  github = builtins.map (
    {
      model_name,
      model_info ? { },
      litellm_params ? { },
    }:
    {
      inherit model_name model_info;
      litellm_params = {
        model = "github_copilot/${model_name}";
        extra_headers = {
          editor-version = "vscode/${pkgs.vscode.version}";
          editor-plugin-version = "copilot/${pkgs.vscode-marketplace-release.github.copilot.version}";
          user-agent = "GithubCopilot/${pkgs.vscode-marketplace-release.github.copilot.version}";
          Copilot-Vision-Request = "true";
        };
      }
      // litellm_params;
    }
  ) githubModelDefinitions;

  # Nvidia NIM models
  nvidia = builtins.map (
    {
      model_name,
      model_info ? { },
      litellm_params ? { },
    }:
    {
      model_name = builtins.baseNameOf model_name;
      inherit model_info;
      litellm_params = {
        model = "nvidia_nim/${model_name}";
        api_key = "os.environ/NVIDIA_NIM_API_KEY";
      }
      // litellm_params;
    }
  ) nvidiaModelDefinitions;
}
