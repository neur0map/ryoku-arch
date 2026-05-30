# Install drivers for Motorcomm YT6801 ethernet adapter used by the Slimbook Executive.
# Best-effort: the yt6801-dkms AUR source is currently broken upstream (Motorcomm moved
# their downloads), so a failure here must not abort the install. Re-runs cleanly once
# the AUR package builds again.
if lspci | grep -i "YT6801\|Motorcomm.*Ethernet"; then
  ryoku-pkg-add linux-headers yt6801-dkms ||
    echo "warning: yt6801-dkms unavailable (AUR source broken upstream); skipping NIC driver"
fi
