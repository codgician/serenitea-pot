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
  users.users.runner = {
    name = "runner";
    description = "Runner";
    home = "/Users/runner";
    shell = pkgs.zsh;
  };

  # Homebrew
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
    };
  };

  # GitLab runner
  services.gitlab-runner = {
    enable = true;
    concurrent = 1;
    extraPackages = with pkgs; [ ];
    prometheusListenAddress = "localhost:8080";
    services = { };
  };
}
