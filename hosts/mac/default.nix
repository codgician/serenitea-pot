let
  pubKeys = import ../../pubkeys.nix;
in
{ config, pkgs, ... }: {

  # Nix garbage collection
  nix.gc = {
    automatic = true;
    interval = {
      Hour = 24 * 7;
      Minute = 0;
    };
  };

  # Users
  users.users.codgi = {
    name = "codgi";
    description = "Shijia Zhang";
    home = "/Users/codgi";
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = pubKeys.users.codgi;
  };

  # System packages
  environment.systemPackages = with pkgs; [
    neofetch
    jdk
    openssl
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
  homebrew =
    let
      brew = import ./brew.nix;
      masApps = brew.masApps;
      casks = brew.casks;
    in
    {
      enable = true;
      onActivation = {
        autoUpdate = true;
        upgrade = true;
        cleanup = "zap";
      };

      inherit masApps;
      inherit casks;
    };

  # Home manager
  home-manager.users.codgi = { config, pkgs, ... }: {
    imports = [
      ../../users/codgi/pwsh.nix
      ../../users/codgi/git.nix
      ../../users/codgi/ssh.nix
      ../../users/codgi/zsh.nix
    ];

    home.stateVersion = "23.05";
    home.packages = with pkgs; [
      httplz
      rnix-lsp
      iperf3
      android-tools
      aria2
      ghc
      pandoc
      acpica-tools
      terraform
      crate2nix
      go
      gopls
      go-outline
      smartmontools
    ];

    # symlinks to binaries
    home.file = {
      ".local/bin/jdk8".source = pkgs.jdk8;
    };
  };
}
