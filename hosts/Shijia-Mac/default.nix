{ config, pkgs, ... }: {

  # Nix settings
  nix = {
    settings = {
      auto-optimise-store = true;
      sandbox = true;
    };

    # Garbage collection
    gc = {
      automatic = true;
      interval = {
        Hour = 24 * 7;
        Minute = 0;
      };
    };
  };

  # Users
  users.users.codgi = {
    name = "codgi";
    description = "Shijia Zhang";
    home = "/Users/codgi";
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM/Mohin9ceHn6zpaRYWi3LeATeXI7ydiMrP3RsglZ2r codgi-ssh" ];
  };

  # System packages
  environment.systemPackages = with pkgs; [
    direnv
    neofetch
    jdk
  ];

  # Fonts
  fonts = {
    fontDir.enable = true;
    fonts = with pkgs; [ cascadia-code ];
  };

  # zsh
  programs.zsh = {
    enable = true;
    promptInit = "";
  };

  # Enable Touch ID for sudo
  security.pam.enableSudoTouchIdAuth = true;

  # Disable ssh password authentication
  environment.etc."ssh/sshd_config.d/110-no-password-authentication.conf" = {
    text = "PasswordAuthentication no";
  };

  # Homebrew
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
    };

    # GUI applications from Mac AppStore
    masApps = {
      "Pages" = 409201541;
      "Numbers" = 409203825;
      "Keynote" = 409183694;
      "iMovie" = 408981434;
      "Garageband" = 682658836;

      "Swift Playgrounds" = 1496833156;
      "Testflight" = 899247664;
      "Developer" = 640199958;
      "Apple Configurator" = 1037126344;
      "Shazam" = 897118787;

      "Microsoft Word" = 462054704;
      "Microsoft Excel" = 462058435;
      "Microsoft PowerPoint" = 462062816;
      "Microsoft Outlook" = 985367838;
      "Microsoft OneNote" = 784801555;
      "Microsoft To Do" = 1274495053;
      "Microsoft Remote Desktop" = 1295203466;

      "Telegram" = 747648890;
      "Twitter" = 1482454543;
      "WeChat" = 836500024;
      "QQ" = 451108668;
      "VooV" = 1497685373;

      "WireGuard" = 1451685025;
      "Infuse" = 1136220934;
      "LocalSend" = 1661733229;

      "IT之家" = 570610859;
    };

    # Homebrew casks
    casks = [
      "appcleaner"
      "visual-studio-code"
      "microsoft-edge"
      "minecraft"
      "logi-options-plus"
      "playcover-community"
      "parallels"
      "iina"
      "bilibili"
      "motrix"
      "zoom"
    ];
  };

  # Home manager
  home-manager.users.codgi = { config, pkgs, ... }: {
    home.stateVersion = "23.05";
    home.packages = with pkgs; [ httplz powershell rnix-lsp ];
    home.sessionVariables = {
      POWERSHELL_UPDATECHECK = "Off";  # Disable PowerShell update check
    };

    # ssh
    programs.ssh = {
      enable = true;
    };

    # git
    programs.git = {
      enable = true;
      lfs.enable = true;
      package = pkgs.gitFull;

      userName = "codgician";
      userEmail = "15964984+codgician@users.noreply.github.com";
      extraConfig.credential.helper = "osxkeychain";
    };

    # Oh my posh!
    programs.oh-my-posh = {
      enable = true;
      enableZshIntegration = false;
      useTheme = "half-life";
    };

    # PowerShell profile
    xdg.configFile."powershell/Microsoft.PowerShell_profile.ps1".text = ''
      Set-PSReadLineOption -PredictionSource HistoryAndPlugin 
      Set-PSReadLineKeyHandler -Chord Tab -Function MenuComplete 
      Set-PSReadLineKeyHandler -Key UpArrow -ScriptBlock { 
          [Microsoft.PowerShell.PSConsoleReadLine]::HistorySearchBackward() 
          [Microsoft.PowerShell.PSConsoleReadLine]::EndOfLine() 
      } 
      Set-PSReadLineKeyHandler -Key DownArrow -ScriptBlock { 
          [Microsoft.PowerShell.PSConsoleReadLine]::HistorySearchForward() 
          [Microsoft.PowerShell.PSConsoleReadLine]::EndOfLine() 
      }

      ${pkgs.oh-my-posh}/bin/oh-my-posh init pwsh `
        --config "${pkgs.oh-my-posh}/share/oh-my-posh/themes/half-life.omp.json" | Invoke-Expression
    '';

    # zsh
    programs.zsh = {
      enable = true;
      oh-my-zsh = {
        enable = true;
        plugins = [ "git" "macos" "ssh-agent" ];
        theme = "half-life";
      };
      initExtra = ''
        zstyle :omz:plugins:ssh-agent quiet yes
        zstyle :omz:plugins:ssh-agent ssh-add-args --apple-load-keychain
        eval "$(/opt/homebrew/bin/brew shellenv)"
      '';
    };
  };
}
