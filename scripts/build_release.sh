#!/usr/bin/env bash
# Forwarding script: delegates directly to scripts/app_release.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/app_release.sh" "$@"
