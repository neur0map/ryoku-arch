pragma Singleton

import Quickshell

Singleton {
  property bool coordinatesReady: false
  property string displayCoordinates: ""
  property bool isFetchingWeather: false
  property string stableName: ""

  function init() {}

  function geolocateAndApply() {}

  function resetWeather() {
    coordinatesReady = false;
    displayCoordinates = "";
    stableName = "";
  }
}
