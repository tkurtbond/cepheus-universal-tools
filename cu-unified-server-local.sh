#!/usr/bin/env bash
# Runs the compiled cu-unified-server (see GNUmakefile) on port 8100 by
# default. awful-main's own default (8080) is hardcoded in the egg and
# can't be overridden from cu-unified-main.scm, so this wrapper supplies
# --port=8100 itself; a --port=... passed here still wins, since
# awful-main uses whichever --port appears last.

cd "$(dirname "$0")"
exec build/cu-unified-server --port=8100 "$@"
