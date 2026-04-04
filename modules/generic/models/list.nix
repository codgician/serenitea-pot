# Model definitions using typed provider options
{ ... }:
let
  # ===========================================================================
  # Variant Definitions (shared across providers)
  # ===========================================================================

  # Claude Sonnet 4.6 effort-based variants
  # See: https://platform.claude.com/docs/en/build-with-claude/effort
  claudeSonnet46 = {
    high.output_config.effort = "high";
    medium.output_config.effort = "medium";
    low.output_config.effort = "low";
  };

  # Claude Opus 4.6 extends Sonnet 4.6 with max effort
  claudeOpus46 = claudeSonnet46 // {
    max.output_config.effort = "max";
  };

  # Opus 4.5 and Sonnet 4.5 use manual thinking (budget_tokens)
  claude45 = {
    high.thinking = {
      type = "enabled";
      budget_tokens = 16000;
    };
    max.thinking = {
      type = "enabled";
      budget_tokens = 31999;
    };
  };

  # GPT-5.x reasoning effort variants
  gpt5 = {
    high = {
      reasoningEffort = "high";
      textVerbosity = "high";
    };
    medium.reasoningEffort = "medium";
    low.reasoningEffort = "low";
    minimal.reasoningEffort = "minimal";
    none.reasoningEffort = "none";
  };

  # GPT-5.2+ adds xhigh reasoning
  gpt52 = gpt5 // {
    xhigh = {
      reasoningEffort = "xhigh";
      textVerbosity = "high";
    };
  };

  # Gemini Pro reasoning variants
  geminiPro = {
    high.reasoningEffort = "high";
    low.reasoningEffort = "low";
  };
in
{
  config.codgician.models.providers = {
    # =========================================================================
    # Anthropic Claude models
    # =========================================================================
    anthropic = {
      # Opus 4.6 supports effort-based control (including max effort)
      "claude-opus-4-6" = {
        aliases = [ "claude-opus-4.6" ];
        variants = claudeOpus46;
      };
      # Opus 4.5 uses manual thinking with budget_tokens
      "claude-opus-4-5" = {
        aliases = [ "claude-opus-4.5" ];
        variants = claude45;
      };
      # Haiku doesn't support extended thinking
      "claude-haiku-4-5".aliases = [ "claude-haiku-4.5" ];
      # Sonnet 4.6 supports effort-based control (no max effort)
      "claude-sonnet-4-6" = {
        aliases = [ "claude-sonnet-4.6" ];
        variants = claudeSonnet46;
      };
      # Sonnet 4.5 uses manual thinking with budget_tokens
      "claude-sonnet-4-5" = {
        aliases = [ "claude-sonnet-4.5" ];
        variants = claude45;
      };
    };

    # =========================================================================
    # Azure models
    # =========================================================================
    azure = {
      # Azure AI provider - chat models
      "deepseek-v3.2".provider = "azure_ai";
      "deepseek-v3.2-speciale".provider = "azure_ai";
      "grok-4-1-fast-non-reasoning".provider = "azure_ai";
      "grok-4-1-fast-reasoning".provider = "azure_ai";
      "kimi-k2.5".provider = "azure_ai";

      # Azure AI provider - image generation
      "flux-1-1-pro" = {
        provider = "azure_ai";
        mode = "image_generation";
        baseModel = "azure_ai/FLUX-1.1-pro";
      };
      "flux-1-kontext-pro" = {
        provider = "azure_ai";
        mode = "image_generation";
        baseModel = "azure_ai/FLUX.1-Kontext-pro";
      };

      # Azure provider - OpenAI models
      "gpt-4o-transcribe-diarize".mode = "audio_transcription";
      "gpt-5.3-chat" = { };
      "gpt-5.2-chat" = { };
      "gpt-5.1-chat" = { };
      "gpt-5-nano" = { };
      "gpt-audio-1.5".baseModel = "azure/gpt-audio-1.5-2026-02-23";
      "gpt-realtime-1.5" = {
        mode = "realtime";
        baseModel = "azure/gpt-realtime-1.5-2026-02-23";
      };
      "o4-mini" = { };
    };

    # =========================================================================
    # DeepSeek models
    # =========================================================================
    deepseek = {
      "deepseek-chat" = { };
      "deepseek-reasoner" = { };
    };

    # =========================================================================
    # Google Gemini models (image generation)
    # =========================================================================
    google = {
      "gemini-3-pro-image-preview" = { };
      "gemini-3.1-flash-image-preview" = { };
      "gemini-2.5-flash-image" = { };
    };

    # =========================================================================
    # GitHub Copilot models
    # =========================================================================
    github = {
      # Embedding models
      "text-embedding-3-small".mode = "embedding";
      "text-embedding-3-small-inference".mode = "embedding";
      "text-embedding-ada-002".mode = "embedding";

      # Gemini models
      "gemini-3-flash-preview" = { };
      "gemini-3.1-pro-preview".variants = geminiPro;

      # GPT-5.x chat models
      "gpt-5-mini".variants = gpt5;
      "gpt-5.1".variants = gpt5;
      "gpt-5.2".variants = gpt52;

      # GPT-5.x codex models (responses mode)
      "gpt-5.2-codex" = {
        mode = "responses";
        variants = gpt52;
      };
      "gpt-5.3-codex" = {
        mode = "responses";
        variants = gpt52;
      };
      "gpt-5.4" = {
        mode = "responses";
        variants = gpt52;
      };
    };

    # =========================================================================
    # NVIDIA NIM models
    # =========================================================================
    nvidia = {
      "glm5".path = "z-ai/glm5";
      "minimax-m2.5".path = "minimaxai/minimax-m2.5";
      "kimi-k2.5".path = "moonshotai/kimi-k2.5";
      "qwen3.5-397b-a17b".path = "qwen/qwen3.5-397b-a17b";
    };
  };
}
