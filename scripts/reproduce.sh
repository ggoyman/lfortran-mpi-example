#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
"$root/scripts/fetch.sh"
"$root/scripts/build.sh" lfortran
"$root/scripts/build.sh" backend
"$root/scripts/build.sh" bindings
"$root/scripts/test.sh"
