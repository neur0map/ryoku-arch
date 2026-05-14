#!/bin/bash
# Retired 2026-05-08. This migration originally propagated the three-island
# topbar (cornerStyle == 4) to existing user configs. The three-island bar
# style was removed; running its original logic now would re-set users to a
# style that no longer exists. Kept as a no-op so the migration runner still
# records it as applied for users who never ran it.
exit 0
