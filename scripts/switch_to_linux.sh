#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

echo "[INFO] Preparing Ever Dialer PC for Linux..."
dart run scripts/sync_platform.dart

# Ensure script execution permissions
chmod +x scripts/*.sh 2>/dev/null || true
chmod +x lib/services/scripts/*.py 2>/dev/null || true

echo ""
echo "[SUCCESS] Linux environment ready! You can now run the app or click Run in Android Studio / VS Code."
