{
  pkgs,
  lib,
  outputs,
}:
let
  terraformConf = builtins.fromJSON outputs.packages.${pkgs.system}.terraform-config.value;
  azureSubdomain = terraformConf.resource.azurerm_ai_services.akasha.custom_subdomain_name;
in
rec {
  # Everything
  all = azure ++ google ++ github;

  # Azure AI models
  azure = lib.pipe terraformConf.resource.azurerm_cognitive_deployment [
    builtins.attrValues
    (builtins.filter (x: !(lib.hasPrefix "flux" x.name)))
    (builtins.map (x: {
      model_name = x.name;
      litellm_params = {
        model = "azure_ai/${x.name}";
        api_base = "https://${azureSubdomain}.services.ai.azure.com";
        api_key = "os.environ/AZURE_AKASHA_API_KEY";
      };
    }))
  ];

  # Google Cloud models
  google =
    lib.map
      (model_name: {
        inherit model_name;
        litellm_params = {
          model = "gemini/${model_name}";
          api_key = "os.environ/GEMINI_API_KEY";
        };
      })
      [
        "gemini-2.5-pro"
        "gemini-2.5-flash"
      ];

  # GitHub Copilot models
  github =
    lib.map
      (model_name: {
        inherit model_name;
        litellm_params = {
          model = "github_copilot/${model_name}";
          extra_headers = {
            editor-version = "vscode/${pkgs.vscode.version}";
            editor-plugin-version = "copilot/${pkgs.vscode-extensions.github.copilot.version}";
            Copilot-Integration-Id = "vscode-chat";
            Copilot-Vision-Request = "true";
            user-agent = "GithubCopilot/${pkgs.vscode-extensions.github.copilot.version}";
          };
        };
      })
      [
        "claude-sonnet-4"
        "claude-opus-41"
        "gpt-5"
        "o3"
      ];
}
