{ ... }:
{
  config = {
    programs.gpg.enable = true;
    services = {
      ssh-agent.enable = true;
      gpg-agent = {
        enable = true;
        enableSshSupport = false;
      };
    };
  };
}
