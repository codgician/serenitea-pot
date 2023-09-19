{
  # GUI applications from Mac AppStore
  masApps = {
    "Pages" = 409201541;
    "Numbers" = 409203825;
    "Keynote" = 409183694;
    "iMovie" = 408981434;
    "Garageband" = 682658836;

    "Playgrounds" = 1496833156;
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
    "OneDrive" = 823766827;

    "Telegram" = 747648890;
    "Twitter" = 1482454543;
    "WeChat" = 836500024;
    "QQ" = 451108668;
    "VooV" = 1497685373;
    "Lark" = 6449830127;

    "WireGuard" = 1451685025;
    "Infuse" = 1136220934;
    "LocalSend" = 1661733229;
    "Hex Fiend" = 1342896380;

    "IT之家" = 570610859;
    "Store Redirect" = 1601434613;
    "ServerCat" = 1501532023;
    "NetEaseMusic" = 944848654;
  };

  # Homebrew casks
  casks = builtins.map (name: { inherit name; greedy = true; }) [
    "appcleaner"
    "visual-studio-code"
    "microsoft-edge"
    "logi-options-plus"
    "playcover-community"
    "parallels"
    "iina"
    "bilibili"
    "motrix"
    "zoom"
    "discord"
    "prismlauncher"
    "microsoft-teams"
    "ghidra"
  ];
}
