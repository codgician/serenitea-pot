# Model definitions using typed provider options
{ config, ... }:
let
  variants = config.codgician.models.variants;
in
{
  config.codgician.models.providers = {
    # =========================================================================
    # Anthropic Claude models
    # =========================================================================
    anthropic = {
      "claude-opus-4-6" = {
        aliases = [ "claude-opus-4.6" ];
        variants = variants.claude;
      };
      "claude-opus-4-5" = {
        aliases = [ "claude-opus-4.5" ];
        variants = variants.claude;
      };
      "claude-haiku-4-5".aliases = [ "claude-haiku-4.5" ];
      "claude-sonnet-4-6" = {
        aliases = [ "claude-sonnet-4.6" ];
        variants = variants.claude;
      };
      "claude-sonnet-4-5" = {
        aliases = [ "claude-sonnet-4.5" ];
        variants = variants.claude;
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
      "gemini-3.1-pro-preview".variants = variants.geminiPro;

      # GPT-5.x chat models
      "gpt-5-mini".variants = variants.gpt5;
      "gpt-5.1".variants = variants.gpt5;
      "gpt-5.2".variants = variants.gpt52;

      # GPT-5.x codex models (responses mode)
      "gpt-5.1-codex" = {
        mode = "responses";
        variants = variants.gpt5;
      };
      "gpt-5.1-codex-max" = {
        mode = "responses";
        variants = variants.gpt5;
      };
      "gpt-5.1-codex-mini" = {
        mode = "responses";
        variants = variants.gpt5;
      };
      "gpt-5.2-codex" = {
        mode = "responses";
        variants = variants.gpt52;
      };
      "gpt-5.3-codex" = {
        mode = "responses";
        variants = variants.gpt52;
      };
      "gpt-5.4" = {
        mode = "responses";
        variants = variants.gpt52;
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
