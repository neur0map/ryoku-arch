-- Laptop clamshell: hand the lid switch to ryoku-clamshell so closing the lid
-- with an external display present blanks the internal panel, and opening it
-- restores the layout. The suspend side (no sleep on lid close when on AC power
-- with an external display) is owned by the ryoku-clamshell daemon (autostart)
-- plus logind; see system/hardware/power/. locked = fires even when the session
-- is locked, so a lid close while locked still switches displays. A missing
-- ryoku-clamshell (old ISO / partial install) makes the exec a harmless no-op.
hl.bind("switch:on:Lid Switch",  hl.dsp.exec_cmd("command -v ryoku-clamshell >/dev/null 2>&1 && ryoku-clamshell lid close"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("command -v ryoku-clamshell >/dev/null 2>&1 && ryoku-clamshell lid open"),  { locked = true })
