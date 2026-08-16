{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.opencode;
  inherit (lib) types;

  # Filter text generation models by allowed providers
  allowedProviders = [
    "azure"
    "chatgpt"
    "github"
    "nvidia"
    "vllm"
    "xai"
  ];

  filteredModels = builtins.filter (
    m: builtins.elem m.provider allowedProviders
  ) osConfig.codgician.models.textGenerationModels;

  # Transform to OpenCode format
  mkOpenCodeModel =
    m:
    let
      contextWindow = m.contextWindow or null;
      maxInputTokens = m.maxInputTokens or null;
      maxOutputTokens = m.maxOutputTokens or null;
      cost = m.cost or null;
      tiers = if cost == null then [ ] else cost.tiers or [ ];
      tier = if tiers == [ ] then null else builtins.head tiers;
      input =
        m.input or [
          "text"
          "image"
        ];
      variants =
        if m.provider == "github" then
          lib.genAttrs m.reasoningEfforts (reasoningEffort: {
            inherit reasoningEffort;
          })
        else
          m.variants;
    in
    {
      attachment = builtins.elem "image" input;
      name = m.model;
      modalities = {
        inherit input;
        output = [ "text" ];
      };
      reasoning = m.reasoningEfforts != [ ] || builtins.elem "reasoning" (m.supports or [ ]);
      tool_call = builtins.elem "toolCalls" (m.supports or [ ]);
    }
    // lib.optionalAttrs (contextWindow != null && maxOutputTokens != null) {
      limit = {
        context = contextWindow;
        output = maxOutputTokens;
      }
      // lib.optionalAttrs (maxInputTokens != null) { input = maxInputTokens; };
    }
    // lib.optionalAttrs (cost != null) {
      cost = {
        inherit (cost) input output;
        cache_read = cost.cacheRead;
        cache_write = cost.cacheWrite;
      }
      // lib.optionalAttrs (tier != null && tier.inputTokensAbove == 200000) {
        context_over_200k = {
          inherit (tier) input output;
          cache_read = tier.cacheRead;
          cache_write = tier.cacheWrite;
        };
      };
    }
    // lib.optionalAttrs (variants != { }) { inherit variants; };

  openCodeModels = builtins.listToAttrs (
    map (m: lib.nameValuePair m.model (mkOpenCodeModel m)) filteredModels
  );
in
{
  options.codgician.codgi.opencode = {
    enable = lib.mkEnableOption "opencode";

    package = lib.mkOption {
      type = types.package;
      default = pkgs.opencode;
      defaultText = lib.literalExpression "pkgs.opencode";
      description = ''
        The OpenCode package to install.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.nur.repos.codgician.agent-browser ];
    programs.opencode = {
      enable = true;
      inherit (cfg) package;
      enableMcpIntegration = config.codgician.codgi.mcp.enable;
      tui = {
        theme = "github";
        plugin = [ "oh-my-openagent" ];
      };
      settings = {
        instructions = [
          (pkgs.writeText "nix.md" ''
            You are on a Nix managed system with arch ${pkgs.stdenv.hostPlatform.system}.
            To install new packages for one off tasks, use `nix run` or create a nix shell.
            To configure an environment for a project, create a flake.nix and use direnv with .envrc to load it.
          '')
        ];
        plugin = [
          "oh-my-openagent"
          "@simonwjackson/opencode-direnv"
        ];
        permission = {
          read = {
            "*" = "allow";
            "*.env" = "deny";
            "*.env.*" = "deny";
            "*.env.example" = "allow";
            "/etc/ssh*" = "deny";
            "/run/secrets*" = "deny";
          };
          edit = "allow";
          external_directory = {
            "*" = "allow";
            "/tmp/*" = "allow";
            "/etc/ssh*" = "deny";
            "/run/secrets*" = "deny";
          };
          bash = {
            "*" = "allow";
            "git *" = "allow";
            "*git push*" = "ask";
            "*sudo*" = "ask";
            "brew*" = "ask";
          };
          list = {
            "*" = "allow";
            "/run/secrets*" = "deny";
          };
        };
        provider = {
          dendro = {
            npm = "@ai-sdk/openai-compatible";
            name = "dendro";
            options = {
              baseURL = "https://dendro.codgician.me/v1";
              apiKey = "{file:${osConfig.codgician.secrets.files."litellm-user-api-key".path}}";
            };
            models = openCodeModels;
          };
        };
      };
    };

    xdg.configFile = {
      # Register agent-browser skill
      "opencode/skills" = {
        source = pkgs.symlinkJoin {
          name = "opencode-skills";
          paths = [
            "${pkgs.nur.repos.codgician.agent-browser.src}/skills"
          ];
        };
        recursive = true;
        force = true;
      };

      # Add override for oh-my-openagent
      "opencode/oh-my-openagent.json".text = builtins.toJSON {
        "$schema" =
          "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/refs/heads/dev/assets/oh-my-opencode.schema.json";
        disabled_skills = [
          "dev-browser"
          "playwright"
        ];
        browser_automation_engine.provider = "agent-browser";
        git_master = {
          commit_footer = false;
          include_co_authored_by = false;
        };
        tmux.enabled = config.codgician.codgi.tmux.enable;
        agents = {
          sisyphus = {
            model = "dendro/claude-opus-5";
            variant = "max";
            fallback_models = [
              "github-copilot/claude-opus-5"
            ];
          };
          sisyphus-junior = {
            model = "dendro/claude-sonnet-5";
            fallback_models = [
              "github-copilot/claude-sonnet-5"
            ];
          };
          hephaestus = {
            model = "dendro/gpt-5.6-sol";
            fallback_models = [ "github-copilot/gpt-5.6-sol" ];
          };
          oracle = {
            model = "dendro/gpt-5.5";
            variant = "high";
            fallback_models = [ "github-copilot/gpt-5.5" ];
          };
          librarian = {
            model = "dendro/gpt-5.4-mini";
            fallback_models = [ "github-copilot/gpt-5.4-mini" ];
          };
          explore = {
            model = "dendro/gpt-5.4-mini";
            fallback_models = [ "github-copilot/gpt-5.4-mini" ];
          };
          multimodal-looker = {
            model = "dendro/gpt-5.5";
            variant = "medium";
            fallback_models = [ "github-copilot/gpt-5.5" ];
          };
          metis = {
            model = "dendro/claude-sonnet-5";
            fallback_models = [
              "github-copilot/claude-sonnet-5"
            ];
          };
          momus = {
            model = "dendro/gpt-5.6-sol";
            variant = "xhigh";
            fallback_models = [ "github-copilot/gpt-5.6-sol" ];
          };
          atlas = {
            model = "dendro/claude-sonnet-5";
            fallback_models = [
              "github-copilot/claude-sonnet-5"
            ];
          };
          prometheus = {
            model = "dendro/claude-opus-5";
            variant = "max";
            fallback_models = [
              "github-copilot/claude-opus-5"
            ];
          };
        };
        categories = {
          visual-engineering = {
            model = "dendro/gemini-3.1-pro-preview";
            fallback_models = [ "github-copilot/gemini-3.1-pro-preview" ];
          };
          ultrabrain = {
            model = "dendro/gpt-5.6-sol";
            fallback_models = [ "github-copilot/gpt-5.6-sol" ];
          };
          deep = {
            model = "dendro/gpt-5.6-terra";
            fallback_models = [ "github-copilot/gpt-5.6-terra" ];
          };
          artistry = {
            model = "dendro/gemini-3.1-pro-preview";
            fallback_models = [ "github-copilot/gemini-3.1-pro-preview" ];
          };
          quick = {
            model = "dendro/gpt-5.4-mini";
            fallback_models = [ "github-copilot/gpt-5.4-mini" ];
          };
          unspecified-low = {
            model = "dendro/gpt-5.6-luna";
            fallback_models = [ "github-copilot/gpt-5.6-luna" ];
          };
          unspecified-high = {
            model = "dendro/claude-opus-5";
            fallback_models = [
              "github-copilot/claude-opus-5"
            ];
          };
          writing = {
            model = "dendro/kimi-k2.6";
            fallback_models = [
              "github-copilot/gemini-3.5-flash"
            ];
          };
        };
      };
    };
  };
}
