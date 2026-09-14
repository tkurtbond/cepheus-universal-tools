#!/usr/bin/env bash
# Runs the compiled cu-unified-server (see GNUmakefile) bound to
# consp.org's external address on port 8100 by default, mirroring
# cu-unified-server-local.sh but for the consp.org deployment (see
# cu-unified-consp.sh for the equivalent interpreted-mode launcher). An
# explicit --addr=... or --port=... passed here still wins, since
# awful-main uses whichever appears last.

cd "$(dirname "$0")"
exec build/cu-unified-server --addr=71.19.158.45 --port=8100 "$@"
