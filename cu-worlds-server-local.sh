#!/usr/bin/env bash
# Runs the compiled cu-worlds-server (see GNUmakefile) on port 8102 by
# default. awful-main's own default (8080) is hardcoded in the egg and
# can't be overridden from cu-worlds-main.scm, so this wrapper supplies
# --port=8102 itself; a --port=... passed here still wins, since
# awful-main uses whichever --port appears last.

cd "$(dirname "$0")"
exec build/cu-worlds-server --port=8102 "$@"
