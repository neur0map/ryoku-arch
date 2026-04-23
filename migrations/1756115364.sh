echo "Replace buggy native Zoom client with webapp"

if ryoku-pkg-present zoom; then
  ryoku-pkg-drop zoom
  ryoku-webapp-install "Zoom" https://app.zoom.us/wc/home https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/zoom.png
fi
