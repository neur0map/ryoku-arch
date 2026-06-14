# Ryoku service-health nixos test (P4/P5): boot the Ryoku service layer in a
# sandboxed VM and assert a clean bring-up: multi-user reached, no failed units,
# systemctl is-system-running in {running,degraded}, and NetworkManager active.
#
# This is the CI-runnable health gate for modules/services (the P4/P5-relevant
# layer). It does NO offline install, so unlike install-base it also runs to
# completion under rootless nix-portable. The full installed system (boot,
# desktop substrate, hardware) is exercised end to end on host KVM by
# ~/Work/ryoku-nix-build/artifacts/install-test.py and on the physical box (P7).
#
# Run: nix build .#checks.x86_64-linux.health
{
  pkgs ? import <nixpkgs> { },
}:
pkgs.testers.runNixOSTest {
  name = "ryoku-health";

  nodes.machine = {
    # The Ryoku service set verbatim: NetworkManager (+iwd), firewall, sshd,
    # polkit, fwupd, bluetooth, printing. Imported alone so the test avoids the
    # nixpkgs overlay module, which runNixOSTest locks read-only.
    imports = [ ../system/modules/services ];

    # A realistic primary user mirroring roles/base, minus the overlay layer.
    users.users.ryoku = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "networkmanager"
      ];
      initialPassword = "ryoku";
    };

    documentation.enable = false;
    system.stateVersion = "26.05";
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    # P5: NetworkManager is the network stack Ryoku ships.
    machine.wait_for_unit("NetworkManager.service")
    machine.succeed("systemctl is-active NetworkManager.service")

    # Units active at boot. sshd runs (startWhenNeeded is off); firewall is a
    # oneshot that stays active. polkit and bluetooth are dbus/hardware
    # activated, so they are correctly inactive until used: assert they are
    # configured (unit present), not running, and let the failed-units check
    # below catch a genuine crash.
    for unit in ("sshd.service", "firewall.service"):
        machine.wait_for_unit(unit)
    for unit in ("polkit.service", "bluetooth.service"):
        machine.succeed(f"systemctl cat {unit} >/dev/null")

    # P4: no failed units.
    failed = machine.succeed(
        "systemctl list-units --state=failed --no-legend --plain --no-pager"
    ).strip()
    assert failed == "", f"failed units present:\n{failed}"

    # P4: the manager settled to a healthy state.
    state = machine.succeed("systemctl is-system-running || true").strip()
    assert state in ("running", "degraded"), f"unexpected system state: {state}"
  '';
}
