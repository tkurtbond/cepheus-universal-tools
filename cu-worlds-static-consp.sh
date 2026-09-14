#!/usr/bin/env bash
# Runs the compiled cu-worlds-server (see GNUmakefile) bound to
# consp.org's external address on port 8102 by default, mirroring
# cu-worlds-server-local.sh but for the consp.org deployment (see
# cu-worlds-consp.sh for the equivalent interpreted-mode launcher). An
# explicit --addr=... or --port=... passed here still wins, since
# awful-main uses whichever appears last.

cd "$(dirname "$0")"
exec build/cu-worlds-server --addr=71.19.158.45 --port=8102 "$@"
