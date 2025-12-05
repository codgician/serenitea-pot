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
in
rec {
  # Everything
  all = azure ++ deepseek ++ google ++ github;

  # Azure AI models
  azure = lib.pipe terraformConf.resource.azurerm_cognitive_deployment [
    builtins.attrValues
    (builtins.filter (x: !(lib.hasPrefix "flux" x.name)))
    (builtins.map (x: {
      model_name = x.name;
      model_info.mode = "chat";
      litellm_params = {
        model = "azure_ai/${x.name}";
        api_base = "https://${azureSubdomain}.services.ai.azure.com";
        api_key = "os.environ/AZURE_AKASHA_API_KEY";
      };
      model_info.base_model = "azure/${x.model.name}";
    }))
  ];

  # Deepseek models
  deepseek = lib.map (model_name: {
    inherit model_name;
    model_info.mode = "chat";
    litellm_params = {
      model = "deepseek/${model_name}";
      api_key = "os.environ/DEEPSEEK_API_KEY";
    };
  }) [ "deepseek-chat" ];

  # Google Cloud models
  google =
    lib.map
      (model_name: {
        inherit model_name;
        litellm_params = {
          model = "gemini/${model_name}";
          api_key = "os.environ/GEMINI_API_KEY";
        };
        model_info.base_model = "gemini/${model_name}";
      })
      [
        # Use GitHub Copilot
        # "gemini-3-pro-preview"
        # "gemini-2.5-pro"
        "gemini-2.5-flash"
      ];

  # GitHub Copilot models
  github =
    lib.map
      (
        {
          model_name,
          model_info ? { },
        }:
        {
          inherit model_name model_info;
          litellm_params = {
            model = "github_copilot/${model_name}";
            extra_headers = {
              editor-version = "vscode/${pkgs.vscode.version}";
              editor-plugin-version = "copilot/${pkgs.vscode-marketplace-release.github.copilot.version}";
              user-agent = "GithubCopilot/${pkgs.vscode-marketplace-release.github.copilot.version}";
            };
          };
        }
      )
      [
        {
          model_name = "claude-haiku-4.5";
          model_info.mode = "chat";
        }
        {
          model_name = "claude-sonnet-4.5";
          model_info.mode = "chat";
        }
        {
          model_name = "claude-opus-4.5";
          model_info.mode = "chat";
        }
        {
          model_name = "gemini-3-pro-preview";
          model_info.mode = "chat";
        }
        {
          model_name = "gemini-2.5-pro";
          model_info.mode = "chat";
        }
        {
          model_name = "gpt-5";
          model_info.mode = "chat";
        }
        {
          model_name = "gpt-5-codex";
          model_info.mode = "responses";
        }
        {
          model_name = "gpt-5-mini";
          model_info.mode = "chat";
        }
        {
          model_name = "gpt-5.1";
          model_info.mode = "chat";
        }
        {
          model_name = "gpt-5.1-codex-max";
          model_info.mode = "responses";
        }
        {
          model_name = "gpt-5.1-codex";
          model_info.mode = "responses";
        }
        {
          model_name = "gpt-5.1-codex-mini";
          model_info.mode = "responses";
        }
        {
          model_name = "o3";
          model_info.mode = "chat";
        }
        {
          model_name = "text-embedding-ada-002";
          model_info.mode = "embedding";
        }
        {
          model_name = "text-embedding-3-small";
          model_info.mode = "embedding";
        }
        {
          model_name = "text-embedding-3-small-inference";
          model_info.mode = "embedding";
        }
      ];
}
