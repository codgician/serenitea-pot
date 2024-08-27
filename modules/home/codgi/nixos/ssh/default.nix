{ ... }: {
  config.services = {
    ssh-agent.enable = true;
    gpg-agent = {
      enable = true;
      enableSshSupport = true;
    };
  };
}
