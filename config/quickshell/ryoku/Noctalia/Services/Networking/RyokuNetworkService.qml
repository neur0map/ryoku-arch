pragma Singleton

import QtQuick
import Quickshell
import qs.Noctalia.Commons

Singleton {
  id: root

  readonly property string providerName: IwdProvider.available ? "iwd" : (NmcliProvider.available ? "nmcli" : "none")
  readonly property var provider: IwdProvider.available ? IwdProvider : (NmcliProvider.available ? NmcliProvider : null)
  readonly property bool available: provider !== null
  readonly property bool usingIwd: providerName === "iwd"
  readonly property bool usingNmcli: providerName === "nmcli"
  readonly property bool hasCommand: IwdProvider.available || NmcliProvider.available

  readonly property bool wifiAvailable: available && provider.wifiAvailable
  readonly property bool wifiEnabled: available ? provider.wifiEnabled : false
  readonly property bool scanning: available ? provider.scanning : false
  readonly property bool scanningActive: scanning
  readonly property var networks: available ? provider.networks : ({})
  readonly property string activeSsid: available ? provider.activeSsid : ""
  readonly property string error: available ? provider.error : "No supported Wi-Fi provider is available"
  readonly property string lastError: error
  readonly property bool wifiConnected: available ? provider.wifiConnected : false
  readonly property bool connecting: available ? provider.connecting : false
  readonly property string connectingTo: available ? provider.connectingTo : ""
  readonly property string disconnectingFrom: available ? provider.disconnectingFrom : ""
  readonly property string forgettingNetwork: available ? provider.forgettingNetwork : ""
  readonly property var existingProfiles: available ? provider.existingProfiles : ({})
  readonly property var activeWifiDetails: available ? provider.activeWifiDetails : ({})
  readonly property string activeWifiIf: available ? provider.activeWifiIf : ""
  readonly property bool airplaneModeEnabled: available ? provider.airplaneModeEnabled : false
  readonly property bool internetConnectivity: available ? provider.internetConnectivity : false
  readonly property string networkConnectivity: available ? provider.networkConnectivity : "unknown"

  readonly property var supportedSecurityTypes: [
    {
      key: "open",
      name: I18n.tr("wifi.panel.security-open")
    },
    {
      key: "wep",
      name: I18n.tr("wifi.panel.security-wep")
    },
    {
      key: "wpa-psk",
      name: I18n.tr("wifi.panel.security-wpa")
    },
    {
      key: "wpa2-psk",
      name: I18n.tr("wifi.panel.security-wpa23")
    },
    {
      key: "sae",
      name: I18n.tr("wifi.panel.security-wpa3")
    },
    {
      key: "wpa-eap",
      name: I18n.tr("wifi.panel.security-wpa-ent")
    },
    {
      key: "wpa2-eap",
      name: I18n.tr("wifi.panel.security-wpa2-ent")
    },
    {
      key: "wpa3-eap",
      name: I18n.tr("wifi.panel.security-wpa3-ent")
    }
  ]

  Component.onCompleted: refresh()

  function commandExists(name) {
    if (name === "iwctl") {
      return IwdProvider.available;
    }
    if (name === "nmcli") {
      return NmcliProvider.available;
    }
    return false;
  }

  function refresh() {
    IwdProvider.refresh();
    NmcliProvider.refresh();
  }

  function scan() {
    if (provider) {
      provider.scan();
    }
  }

  function connect(ssid, security, passphrase) {
    if (!provider) {
      return;
    }

    let resolvedSecurity = security || securityForSsid(ssid);
    let resolvedPassphrase = passphrase || "";

    if (arguments.length >= 4) {
      resolvedPassphrase = security || "";
      resolvedSecurity = arguments[3] || securityForSsid(ssid);
    } else if (arguments.length >= 3 && typeof passphrase === "boolean") {
      resolvedPassphrase = security || "";
      resolvedSecurity = securityForSsid(ssid);
    } else if (arguments.length === 2) {
      resolvedPassphrase = "";
      resolvedSecurity = security || securityForSsid(ssid);
    }

    provider.connect(ssid, resolvedSecurity, resolvedPassphrase);
  }

  function disconnect(ssid) {
    if (provider) {
      provider.disconnect(ssid);
    }
  }

  function forget(ssid) {
    if (provider) {
      provider.forget(ssid);
    }
  }

  function refreshActiveWifiDetails() {
    if (provider) {
      provider.refreshActiveWifiDetails();
    }
  }

  function setWifiEnabled(enabled) {
    if (provider) {
      provider.setWifiEnabled(enabled);
    }
  }

  function setAirplaneMode(state) {
    IwdProvider.setWifiEnabled(!state);
    NmcliProvider.setWifiEnabled(!state);
  }

  function getSignalInfo(signal, isConnected) {
    return provider ? provider.getSignalInfo(signal, isConnected) : {
      "icon": "wifi-off",
      "label": "Unavailable"
    };
  }

  function isSecured(security) {
    return provider ? provider.isSecured(security) : !!security && security !== "--" && security.trim() !== "";
  }

  function isEnterprise(security) {
    return provider ? provider.isEnterprise(security) : false;
  }

  function securityForSsid(ssid) {
    if (!ssid || !networks[ssid]) {
      return "";
    }
    return networks[ssid].security || "";
  }

  function getStatusText(showSpeed) {
    if (connecting) {
      return connectingTo ? I18n.tr("common.connecting") + " " + connectingTo : I18n.tr("common.connecting");
    }
    return activeSsid;
  }

  function getIcon() {
    if (!wifiEnabled) {
      return "wifi-off";
    }
    if (wifiConnected) {
      const signal = activeWifiDetails.signal || 0;
      return getSignalInfo(signal, true).icon;
    }
    return wifiAvailable ? "wifi-0" : "wifi-off";
  }
}
