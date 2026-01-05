{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.pwsh;
in
{
  options.codgician.codgi.pwsh.enable = lib.mkEnableOption "PowerShell and oh-my-posh";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [ powershell ];
    home.sessionVariables = {
      POWERSHELL_UPDATECHECK = "Off"; # Disable PowerShell update check
    };

    # Oh my posh
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

      ${lib.getExe pkgs.oh-my-posh} init pwsh `
        --config "${pkgs.oh-my-posh}/share/oh-my-posh/themes/half-life.omp.json" | Invoke-Expression
    '';
  };
}
