# Network diagnostic CLI tools. The NetworkManager daemon lives in modules/services.
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    dnsutils
    nmap
    iperf3
    ethtool
  ];
}
