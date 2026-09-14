#!/usr/bin/env bash
# Runs the compiled cu-systems-server (see GNUmakefile) bound to
# consp.org's external address on port 8103 by default, mirroring
# cu-systems-server-local.sh but for the consp.org deployment (see
# cu-systems-consp.sh for the equivalent interpreted-mode launcher). An
# explicit --addr=... or --port=... passed here still wins, since
# awful-main uses whichever appears last.

cd "$(dirname "$0")"
exec build/cu-systems-server --addr=71.19.158.45 --port=8103 "$@"
