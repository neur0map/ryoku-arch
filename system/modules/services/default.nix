# Core system services: networking, ssh, polkit, firmware updates, bluetooth, printing.
{ ... }:
{
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.backend = "iwd";

  networking.firewall.enable = true;

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;
  services.openssh.settings.PermitRootLogin = "no";

  security.polkit.enable = true;

  services.fwupd.enable = true;

  hardware.bluetooth.enable = true;

  services.printing.enable = true;
}
