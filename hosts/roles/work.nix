{ pkgs, ... }:
{
  codgician = {
    services = {
      # Microsoft Intune enrollment (device compliance, identity broker,
      # Defender for Endpoint, VPN)
      intune.enable = true;

      plasma.wallpaper =
        (pkgs.fetchurl {
          url = "https://media.githubusercontent.com/media/codgician/assets/refs/heads/main/images/wallpapers/genshin-luna-viii.jpg";
          sha256 = "sha256-VjoCRP8AENaUlItKCn2751GY+WtF0ncwcBWYuJHmCWE=";
        }).outPath;

      # RAS hardware error monitoring (EDAC/DIMM ECC, PCIe AER, CPU MCE)
      rasdaemon.enable = true;

      sing-box = {
        enable = true;
        clients.ss-lumidouce.enable = true;
        tun.enable = true;
      };
    };

    virtualization.podman.enable = true;
  };

  home-manager.users.codgi = {
    codgician.codgi = {
      bilibili.enable = true;
      claude-code.enable = true;
      codex.enable = true;
      herdr.enable = true;
      oh-my-pi.defaultProfile = "github-copilot";
      plasma.launchers = [
        "applications:org.kde.dolphin.desktop"
        "applications:microsoft-edge.desktop"
        "applications:org.kde.konsole.desktop"
        "applications:code.desktop"
        "applications:teams-for-linux.desktop"
      ];
      teams-for-linux.enable = true;
    };

    # Set Microsoft Edge as default browser
    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = "microsoft-edge.desktop";
        "x-scheme-handler/http" = "microsoft-edge.desktop";
        "x-scheme-handler/https" = "microsoft-edge.desktop";
        "x-scheme-handler/about" = "microsoft-edge.desktop";
        "x-scheme-handler/unknown" = "microsoft-edge.desktop";
      };
    };
    xdg.configFile."mimeapps.list".force = true;
  };
}
