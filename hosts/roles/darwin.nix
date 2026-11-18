{
  codgician.system = {
    brew.enable = true;
    common.inChina = true;
  };

  system.primaryUser = "codgi";

  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      AppleInterfaceStyleSwitchesAutomatically = false;
      AppleTemperatureUnit = "Celsius";
      AppleMeasurementUnits = "Centimeters";
      AppleMetricUnits = 1;
    };

    SoftwareUpdate.AutomaticallyInstallMacOSUpdates = true;
  };
}
