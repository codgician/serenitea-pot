{ pkgs, ... }:
{
  home-manager.users.codgi =
    { pkgs, ... }:
    {
      codgician.codgi = {
        claude-code.enable = true;
        codex = {
          enable = true;
          package = pkgs.codex-wrapped;
        };
        dev = {
          haskell.enable = true;
          rust.enable = true;
        };
        dsh.enable = true;
        droid = {
          enable = true;
          package = pkgs.droid-wrapped;
        };
        github-copilot-cli.enable = true;
        herdr.enable = true;
        mcp.enable = true;
        oh-my-pi.enable = true;
        pi-coding-agent.enable = true;
        vscode.enable = true;
      };

      home = {
        packages =
          with pkgs;
          [
            jq
            dnsutils
            iperf3
            htop
            aria2
            android-tools
            scrcpy
            pandoc
            terraform
            smartmontools
            ffmpeg-full
            tcping-go
            binwalk
            imhex
            ghidra
            prismlauncher-unwrapped
            macmon
            mtk-uartboot
            mas
            sshpass
            firefox-bin
            unstable.antigravity-cli
          ]
          ++ (with pkgs.nur.repos.codgician; [
            nanokvm-usb
          ]);

        # symlinks to binaries
        file = {
          ".local/bin/jdk8".source = pkgs.zulu8;
        };
      };
    };

  environment = {
    # System packages
    systemPackages = with pkgs; [
      fastfetch
      zulu
      openssl
    ];

    # SMB client settings
    etc."nsmb.conf".text = ''
      [default]
      mc_prefer_wired=yes
    '';
  };

  # System settings
  system.defaults = {
    dock = {
      largesize = 128;
      tilesize = 64;
      magnification = true;
      persistent-apps = [
        "/System/Applications/Apps.app"
        "/System/Cryptexes/App/System/Applications/Safari.app"
        "/System/Applications/Messages.app"
        "/System/Applications/Mail.app"
        "/System/Applications/Maps.app"
        "/System/Applications/Photos.app"
        "/System/Applications/FaceTime.app"
        "/System/Applications/Phone.app"
        "/System/Applications/Calendar.app"
        "/System/Applications/Contacts.app"
        "/System/Applications/Reminders.app"
        "/System/Applications/Notes.app"
        "/System/Applications/TV.app"
        "/System/Applications/Music.app"
        "/System/Applications/Games.app"
        "/System/Applications/App Store.app"
        "/System/Applications/System Settings.app"
        "/System/Applications/iPhone Mirroring.app"
      ];
    };
    trackpad.Clicking = true;
  };

  system.stateVersion = 7;
}
