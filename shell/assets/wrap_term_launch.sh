#!/usr/bin/env sh

cat ~/.local/state/ryoku/sequences.txt 2>/dev/null

exec "$@"
