{ lib, pkgs, ... }:
let
  dsh = lib.codgician.published.services.dsh-web;
in
{
  codgician = {
    services = {
      jupyter = {
        notebookDir = "/lab/jupyter";
      };

      # The dsh Web UI is a Home Manager service, so its vhost is declared here.
      nginx.reverseProxies.dsh-web = {
        proxyPass = dsh.localUpstream;
        locations."/".extraConfig = ''
          # dsh's initial URL contains a browser login token.
          access_log off;
          proxy_cookie_flags ~^dsh-auth- secure;
          proxy_buffering off;
        '';
      };
    };

    system.common.inChina = true;
  };

  home-manager.users.codgi = {
    codgician.codgi = {
      claude-code.enable = true;
      codex.enable = true;
      dev.dotnet.enable = true;
      dsh = {
        enable = true;
      };
      github-copilot-cli.enable = true;
      mcp.enable = true;
      pi-coding-agent.enable = true;
      oh-my-pi.enable = true;
    };

    home.packages = with pkgs; [
      acpica-tools
      uefitool
      binwalk
    ];
  };

  # Enable nix-ld for lab environment
  programs.nix-ld.enable = true;

  system.stateVersion = "26.05";
}
