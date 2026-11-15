#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if ! command -v swipl >/dev/null 2>&1; then
  echo "SWI-Prolog (swipl) was not found on PATH."
  echo "On Debian/Ubuntu: sudo apt-get install -y swi-prolog-nox"
  exit 1
fi
exec swipl -s scripts/server.pl -- "$@"
