{ ... }:
{
  # Vendor-neutral laptop baseline.
  services.power-profiles-daemon.enable = true;
  services.fwupd.enable = true;
  hardware.bluetooth.enable = true;
  hardware.enableRedistributableFirmware = true; # linux-firmware (wifi/audio blobs)
  boot.kernelParams = [ "amd_pstate=active" ]; # 7940HS power scaling

  # Ignore the power button by default (Ryoku ignore-power-button.sh equivalent).
  # The freeform settings.Login form is the 25.05+ interface and is present in 26.05.
  # If absent on an older channel, use: services.logind.powerKey = "ignore";
  services.logind.settings.Login.HandlePowerKey = "ignore";
}
