#!/usr/bin/env bash
# ===================================================================
# Ever Dialer PC - Universal Dual-Boot Self-Healing Script for Linux
# ===================================================================
# Dynamically discovers the Ever Dialer PC project directory (no hardcoded paths),
# diagnoses cross-platform cache/dependency contamination from Windows, heals
# the project configuration, cleans stale CMake and Dart artifacts, synchronizes
# Flutter packages, restores execution permissions, and verifies VS Code readiness
# so clicking "Run" works seamlessly.
# ===================================================================

set -e

# Terminal styling
BOLD="\033[1m"
GREEN="\033[32m"
BLUE="\033[34m"
CYAN="\033[36m"
YELLOW="\033[33m"
MAGENTA="\033[35m"
RED="\033[31m"
RESET="\033[0m"

echo -e "${CYAN}==========================================================${RESET}"
echo -e "${BOLD}${CYAN}      Ever Dialer PC - Universal Dual-Boot Healer         ${RESET}"
echo -e "${CYAN}==========================================================${RESET}"
echo -e "[INFO] Host Platform: Linux"

# -------------------------------------------------------------------
# 1. DYNAMICALLY LOCATE PROJECT DIRECTORY (Zero Hardcoding)
# -------------------------------------------------------------------
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SCRIPT_SOURCE" ]; do
    SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" && pwd)"
    SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
    [[ $SCRIPT_SOURCE != /* ]] && SCRIPT_SOURCE="$SCRIPT_DIR/$SCRIPT_SOURCE"
done
RESOLVED_SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" && pwd)"

PROJECT_DIR=""

# Check 1: Script parent directory (scripts/.. -> project root)
if [ -f "${RESOLVED_SCRIPT_DIR}/../pubspec.yaml" ] && grep -q "name: ever_dialer_pc" "${RESOLVED_SCRIPT_DIR}/../pubspec.yaml" 2>/dev/null; then
    PROJECT_DIR="$(cd "${RESOLVED_SCRIPT_DIR}/.." && pwd)"
# Check 2: Script directory itself (if placed in root)
elif [ -f "${RESOLVED_SCRIPT_DIR}/pubspec.yaml" ] && grep -q "name: ever_dialer_pc" "${RESOLVED_SCRIPT_DIR}/pubspec.yaml" 2>/dev/null; then
    PROJECT_DIR="$RESOLVED_SCRIPT_DIR"
# Check 3: Current working directory and walk upward
else
    CURR_DIR="$(pwd)"
    while [ -n "$CURR_DIR" ] && [ "$CURR_DIR" != "/" ]; do
        if [ -f "${CURR_DIR}/pubspec.yaml" ] && grep -q "name: ever_dialer_pc" "${CURR_DIR}/pubspec.yaml" 2>/dev/null; then
            PROJECT_DIR="$CURR_DIR"
            break
        fi
        CURR_DIR="$(dirname "$CURR_DIR")"
    done
fi

# Check 4: Cached project location in ~/.config
CONFIG_FILE="${HOME}/.config/ever_dialer_pc/project_dir"
if [ -z "$PROJECT_DIR" ] && [ -f "$CONFIG_FILE" ]; then
    CACHED_DIR="$(cat "$CONFIG_FILE" 2>/dev/null | tr -d '\r\n')"
    if [ -n "$CACHED_DIR" ] && [ -f "${CACHED_DIR}/pubspec.yaml" ] && grep -q "name: ever_dialer_pc" "${CACHED_DIR}/pubspec.yaml" 2>/dev/null; then
        PROJECT_DIR="$CACHED_DIR"
    fi
fi

# Check 5: Git root lookup
if [ -z "$PROJECT_DIR" ]; then
    GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -n "$GIT_ROOT" ] && [ -f "${GIT_ROOT}/pubspec.yaml" ] && grep -q "name: ever_dialer_pc" "${GIT_ROOT}/pubspec.yaml" 2>/dev/null; then
        PROJECT_DIR="$GIT_ROOT"
    fi
fi

if [ -z "$PROJECT_DIR" ]; then
    echo -e "${RED}[ERROR] Could not find the Ever Dialer PC project directory!${RESET}"
    echo -e "${YELLOW}Please navigate (cd) into the Ever Dialer PC folder and run: bash scripts/heal.sh${RESET}"
    exit 1
fi

echo -e "${GREEN}[OK] Project located dynamically at: ${PROJECT_DIR}${RESET}"

# Cache project directory
mkdir -p "$(dirname "$CONFIG_FILE")"
echo "$PROJECT_DIR" > "$CONFIG_FILE"

cd "$PROJECT_DIR"

# -------------------------------------------------------------------
# 2. HEAL DART PACKAGE CONFIG & FLUTTER DEPENDENCY MAPS
# -------------------------------------------------------------------
echo -e "\n${YELLOW}[STEP 1/5] Checking cross-platform dependency health...${RESET}"

PKG_CONFIG_FILE="${PROJECT_DIR}/.dart_tool/package_config.json"
PLUGINS_FILE="${PROJECT_DIR}/.flutter-plugins-dependencies"
NEEDS_PUB_GET=0

if [ ! -f "$PKG_CONFIG_FILE" ]; then
    echo "[INFO] .dart_tool/package_config.json is missing."
    NEEDS_PUB_GET=1
else
    # If package_config was generated on Windows, it contains Windows drive paths (file:///C:, file:///D:, etc.) or backslashes
    if grep -q -E 'file:///[A-Za-z]:|\\\\' "$PKG_CONFIG_FILE" 2>/dev/null; then
        echo -e "${MAGENTA}[HEAL] Detected Windows file URIs in package_config.json! Purging Windows package mappings...${RESET}"
        rm -f "$PKG_CONFIG_FILE"
        NEEDS_PUB_GET=1
    fi
fi

if [ -f "$PLUGINS_FILE" ]; then
    if grep -q -E 'file:///[A-Za-z]:|\\\\' "$PLUGINS_FILE" 2>/dev/null; then
        echo -e "${MAGENTA}[HEAL] Detected Windows paths in .flutter-plugins-dependencies. Resetting...${RESET}"
        rm -f "$PLUGINS_FILE"
        rm -f "${PROJECT_DIR}/.flutter-plugins" 2>/dev/null || true
        NEEDS_PUB_GET=1
    fi
fi

# -------------------------------------------------------------------
# 3. HEAL STALE CROSS-OS BUILD CACHES
# -------------------------------------------------------------------
echo -e "\n${YELLOW}[STEP 2/5] Inspecting CMake & build artifacts...${RESET}"

LINUX_CMAKE_CACHE="${PROJECT_DIR}/build/linux/CMakeCache.txt"
if [ -f "$LINUX_CMAKE_CACHE" ]; then
    if grep -q -E '[A-Za-z]:\\\\|C:/|MSVC' "$LINUX_CMAKE_CACHE" 2>/dev/null; then
        echo -e "${MAGENTA}[HEAL] Linux build cache contains Windows compiler references. Cleaning build/linux...${RESET}"
        rm -rf "${PROJECT_DIR}/build/linux"
    fi
fi

# -------------------------------------------------------------------
# 4. RUN FLUTTER PUB GET FOR LINUX
# -------------------------------------------------------------------
if [ "$NEEDS_PUB_GET" -eq 1 ] || [ ! -f "$PKG_CONFIG_FILE" ]; then
    echo -e "${CYAN}[INFO] Synchronizing dependencies for Linux with 'flutter pub get'...${RESET}"
    flutter pub get
    echo -e "${GREEN}[OK] Dependencies synchronized successfully for Linux.${RESET}"
else
    echo -e "${GREEN}[OK] Dependencies are already healthy for Linux.${RESET}"
fi

# -------------------------------------------------------------------
# 5. RESTORE EXECUTABLE PERMISSIONS & DESKTOP LAUNCHERS
# -------------------------------------------------------------------
echo -e "\n${YELLOW}[STEP 3/5] Restoring permissions, VS Code configs, and desktop integration...${RESET}"

# Configure VS Code launch options for Linux
mkdir -p "${PROJECT_DIR}/.vscode"
cat << 'EOF' > "${PROJECT_DIR}/.vscode/launch.json"
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Ever Dialer PC (Linux Debug)",
            "request": "launch",
            "type": "dart",
            "deviceId": "linux",
            "flutterMode": "debug",
            "program": "lib/main.dart",
            "internalConsoleOptions": "openOnSessionStart"
        },
        {
            "name": "Ever Dialer PC (Linux Release)",
            "request": "launch",
            "type": "dart",
            "deviceId": "linux",
            "flutterMode": "release",
            "program": "lib/main.dart",
            "internalConsoleOptions": "openOnSessionStart"
        },
        {
            "name": "Ever Dialer PC (Windows Debug)",
            "request": "launch",
            "type": "dart",
            "deviceId": "windows",
            "flutterMode": "debug",
            "program": "lib/main.dart",
            "internalConsoleOptions": "openOnSessionStart"
        },
        {
            "name": "Ever Dialer PC (Windows Release)",
            "request": "launch",
            "type": "dart",
            "deviceId": "windows",
            "flutterMode": "release",
            "program": "lib/main.dart",
            "internalConsoleOptions": "openOnSessionStart"
        }
    ]
}
EOF
echo -e "${GREEN}[OK] VS Code build selection configured with Linux Debug, Linux Release, Windows Debug, Windows Release.${RESET}"

chmod +x "${PROJECT_DIR}/scripts/"*.sh 2>/dev/null || true
chmod +x "${PROJECT_DIR}/lib/services/scripts/"*.py 2>/dev/null || true
chmod +x "${PROJECT_DIR}/heal.sh" 2>/dev/null || true
chmod +x "${PROJECT_DIR}/heal" 2>/dev/null || true
chmod +x "${PROJECT_DIR}/app_release" 2>/dev/null || true
chmod +x "${PROJECT_DIR}/build_release" 2>/dev/null || true

# Verify desktop launcher files exist
DESKTOP1="${PROJECT_DIR}/linux/ever_dialer_pc.desktop"
DESKTOP2="${PROJECT_DIR}/linux/com.everdialer.ever_dialer_pc.desktop"
if [ -f "$DESKTOP1" ] && [ -f "$DESKTOP2" ]; then
    echo -e "${GREEN}[OK] Linux desktop launcher files verified.${RESET}"
else
    echo -e "${YELLOW}[WARN] Desktop launcher files missing in linux/ directory.${RESET}"
fi

# -------------------------------------------------------------------
# 6. VERIFY FLUTTER RUNNER DEVICE
# -------------------------------------------------------------------
echo -e "\n${YELLOW}[STEP 4/5] Checking connected Flutter devices...${RESET}"
if flutter devices 2>&1 | grep -q "linux"; then
    echo -e "${GREEN}[OK] Linux desktop runner device is active and recognized.${RESET}"
else
    echo -e "${YELLOW}[WARN] Linux desktop device was not listed by 'flutter devices'.${RESET}"
    echo -e "       Check if Linux desktop development is enabled ('flutter config --enable-linux-desktop')."
fi

# -------------------------------------------------------------------
# 7. CONFIGURE GLOBAL CLI COMMANDS (~/.local/bin)
# -------------------------------------------------------------------
echo -e "\n${YELLOW}[STEP 5/5] Ensuring global CLI commands are installed...${RESET}"

LOCAL_BIN="${HOME}/.local/bin"
mkdir -p "$LOCAL_BIN"

# Link heal command to ~/.local/bin/heal
CURRENT_HEAL="${PROJECT_DIR}/scripts/heal.sh"
if [ ! -L "${LOCAL_BIN}/heal" ] || [ "$(readlink -f "${LOCAL_BIN}/heal" 2>/dev/null)" != "$CURRENT_HEAL" ]; then
    ln -sf "$CURRENT_HEAL" "${LOCAL_BIN}/heal"
    chmod +x "${LOCAL_BIN}/heal"
fi
if [ ! -L "${LOCAL_BIN}/ever-heal" ] || [ "$(readlink -f "${LOCAL_BIN}/ever-heal" 2>/dev/null)" != "$CURRENT_HEAL" ]; then
    ln -sf "$CURRENT_HEAL" "${LOCAL_BIN}/ever-heal"
    chmod +x "${LOCAL_BIN}/ever-heal"
fi

echo -e "${GREEN}[OK] Global commands 'heal' and 'ever-heal' are available in ~/.local/bin${RESET}"

echo -e "\n${GREEN}==========================================================${RESET}"
echo -e "${BOLD}${GREEN}    [SUCCESS] Ever Dialer PC is healed for Linux!         ${RESET}"
echo -e "${GREEN}==========================================================${RESET}"
echo -e " You can now:"
echo -e "   1. Click the 'Run' button (F5) in VS Code or Android Studio."
echo -e "   2. Run 'flutter run -d linux' from any terminal."
echo -e "   3. Type 'heal' anytime you switch between Windows and Linux."
echo -e "${GREEN}==========================================================\n${RESET}"
