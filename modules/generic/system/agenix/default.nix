{ config, pkgs, inputs, ... }: {
  # Install agenix CLI
  config.environment.systemPackages = with pkgs; [ agenix ];
}
