{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.codgician.codgi.codex;

  # Transform MCP servers to Codex format: `http_headers` instead of `headers`,
  # a native `enabled` flag instead of `disabled`, and no `type` field.
  mkMcpServer =
    server:
    (
      if server.command != null then
        { inherit (server) command args env; }
      else
        {
          inherit (server) url;
        }
        // lib.optionalAttrs (server.headers != { }) { http_headers = server.headers; }
    )
    // {
      enabled = !(server.disabled or false);
    };

  mcpServers = lib.mapAttrs (_: mkMcpServer) config.programs.mcp.servers;
in
{
  options.codgician.codgi.codex = {
    enable = lib.mkEnableOption "Codex";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.codex;
      defaultText = lib.literalExpression "pkgs.codex";
      description = ''
        The Codex package to install.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs.nur.repos.codgician; [ agent-browser ];

    # Link skills directory to ~/.agents/skills
    home.file.".agents/skills".source = pkgs.symlinkJoin {
      name = "codex-skills";
      paths = [
        "${inputs.superpowers}/skills"
        "${pkgs.nur.repos.codgician.agent-browser.src}/skills"
      ];
    };

    programs.codex = {
      enable = true;
      package = cfg.package;

      settings = {
        openai_base_url = "https://dendro.codgician.me/v1";
        mcp_servers = lib.mkIf config.codgician.codgi.mcp.enable mcpServers;
        model = "gpt-5.5";
      };
    };
  };
}
