#!/usr/bin/env bash
set -e

# Colors for terminal output
BOLD="\033[1m"
GREEN="\033[32m"
BLUE="\033[34m"
CYAN="\033[36m"
YELLOW="\033[33m"
RESET="\033[0m"

# -------------------------------------------------------------------
# 1. DYNAMICALLY LOCATE PROJECT ROOT
# -------------------------------------------------------------------
# Resolve the real directory of this script, even if invoked via a symlink
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SCRIPT_SOURCE" ]; do
    SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" && pwd)"
    SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
    [[ $SCRIPT_SOURCE != /* ]] && SCRIPT_SOURCE="$SCRIPT_DIR/$SCRIPT_SOURCE"
done
RESOLVED_SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" && pwd)"

# Project root is the parent directory of 'scripts/'
CANDIDATE_PROJECT_DIR="$(cd "${RESOLVED_SCRIPT_DIR}/.." && pwd)"

CONFIG_FILE="${HOME}/.config/ever_dialer_pc/project_dir"
mkdir -p "$(dirname "$CONFIG_FILE")"

if [ -f "${CANDIDATE_PROJECT_DIR}/pubspec.yaml" ] && grep -q "name: ever_dialer_pc" "${CANDIDATE_PROJECT_DIR}/pubspec.yaml" 2>/dev/null; then
    PROJECT_DIR="$CANDIDATE_PROJECT_DIR"
    echo "$PROJECT_DIR" > "$CONFIG_FILE"
elif [ -f "./pubspec.yaml" ] && grep -q "name: ever_dialer_pc" "./pubspec.yaml" 2>/dev/null; then
    PROJECT_DIR="$(pwd)"
    echo "$PROJECT_DIR" > "$CONFIG_FILE"
elif [ -f "$CONFIG_FILE" ] && [ -d "$(cat "$CONFIG_FILE")" ]; then
    PROJECT_DIR="$(cat "$CONFIG_FILE")"
else
    echo "Error: Could not locate the Ever Dialer PC project directory."
    echo "Please navigate into the project folder and run: bash scripts/app_release.sh"
    exit 1
fi

cd "$PROJECT_DIR"

# -------------------------------------------------------------------
# 2. SELF-HEALING: ENSURE 'app_release' SYMLINK IS ALWAYS VALID
# -------------------------------------------------------------------
LOCAL_BIN="${HOME}/.local/bin"
mkdir -p "$LOCAL_BIN"
CURRENT_SCRIPT="${PROJECT_DIR}/scripts/app_release.sh"

if [ ! -L "${LOCAL_BIN}/app_release" ] || [ "$(readlink -f "${LOCAL_BIN}/app_release")" != "$CURRENT_SCRIPT" ]; then
    ln -sf "$CURRENT_SCRIPT" "${LOCAL_BIN}/app_release"
    chmod +x "${LOCAL_BIN}/app_release"
fi

export PATH="${LOCAL_BIN}:${HOME}/bin:${PATH}"

# -------------------------------------------------------------------
# 3. AUTO-BOOTSTRAP PACKAGING TOOLS IF ON A NEW PC
# -------------------------------------------------------------------
if ! command -v nfpm &> /dev/null; then
    echo -e "${YELLOW}nfpm not detected. Auto-installing lightweight packager to ${LOCAL_BIN}...${RESET}"
    TMP_NFPM_TAR="/tmp/nfpm_install.tar.gz"
    curl -sL -o "$TMP_NFPM_TAR" "https://github.com/goreleaser/nfpm/releases/download/v2.48.0/nfpm_2.48.0_Linux_x86_64.tar.gz"
    tar -xzf "$TMP_NFPM_TAR" -C "/tmp" nfpm
    mv /tmp/nfpm "${LOCAL_BIN}/"
    chmod +x "${LOCAL_BIN}/nfpm"
    rm -f "$TMP_NFPM_TAR"
    echo -e "${GREEN}✓ nfpm installed successfully.${RESET}"
fi

if ! command -v appimagetool &> /dev/null; then
    echo -e "${YELLOW}appimagetool not detected. Auto-installing AppImage packager to ${LOCAL_BIN}...${RESET}"
    curl -sL -o "${LOCAL_BIN}/appimagetool" "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
    chmod +x "${LOCAL_BIN}/appimagetool"
    echo -e "${GREEN}✓ appimagetool installed successfully.${RESET}"
fi

if [ ! -f "${LOCAL_BIN}/runtime-x86_64" ]; then
    echo -e "${YELLOW}Downloading offline AppImage runtime to ${LOCAL_BIN}...${RESET}"
    curl -sL -o "${LOCAL_BIN}/runtime-x86_64" "https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-x86_64"
    mkdir -p "${HOME}/.cache/appimagetool"
    cp "${LOCAL_BIN}/runtime-x86_64" "${HOME}/.cache/appimagetool/runtime-x86_64"
    echo -e "${GREEN}✓ AppImage runtime cached for 100% offline packaging.${RESET}"
fi

# -------------------------------------------------------------------
# 4. PREPARE OUTPUT DIRECTORY
# -------------------------------------------------------------------
DOWNLOADS_DIR="$(xdg-user-dir DOWNLOAD 2>/dev/null || echo "${HOME}/Downloads")"
OUTPUT_DIR="${DOWNLOADS_DIR}/Linux Release"
mkdir -p "$OUTPUT_DIR"

VERSION=$(grep -m 1 "^version:" pubspec.yaml | awk '{print $2}' | cut -d '+' -f 1)
[ -z "$VERSION" ] && VERSION="1.0.0"

APP_NAME="ever-dialer-pc"
BINARY_NAME="ever_dialer_pc"
ARCH="x86_64"
DEB_ARCH="amd64"

echo -e "${BOLD}${CYAN}====================================================${RESET}"
echo -e "${BOLD}${CYAN}      Ever Dialer PC — Universal Linux Release      ${RESET}"
echo -e "${BOLD}Project Directory:${RESET} ${PROJECT_DIR}"
echo -e "${BOLD}Version:${RESET}          ${VERSION}"
echo -e "${BOLD}Architecture:${RESET}     ${ARCH} (64-bit)"
echo -e "${BOLD}Output Folder:${RESET}    ${OUTPUT_DIR}"
echo -e "${BOLD}${CYAN}====================================================${RESET}"
echo ""

# -------------------------------------------------------------------
# 5. COMPILE FLUTTER RELEASE
# -------------------------------------------------------------------
echo -e "${BLUE}▶ 1/5 Compiling Flutter Linux Release Binary...${RESET}"
flutter build linux --release

BUNDLE_DIR="${PROJECT_DIR}/build/linux/x64/release/bundle"
if [ ! -d "$BUNDLE_DIR" ]; then
    echo "Error: Release bundle was not generated at $BUNDLE_DIR"
    exit 1
fi

# Ensure desktop entry exists
if [ ! -f "${PROJECT_DIR}/linux/ever_dialer_pc.desktop" ]; then
    cat << 'EOF' > "${PROJECT_DIR}/linux/ever_dialer_pc.desktop"
[Desktop Entry]
Name=Ever Dialer PC
GenericName=Bluetooth Audio Companion
Comment=Stream phone audio to PC speakers and control dialer features
Exec=ever_dialer_pc
Icon=ever_dialer_pc
Terminal=false
Type=Application
Categories=AudioVideo;Audio;Utility;
StartupWMClass=ever_dialer_pc
Keywords=Bluetooth;Dialer;Audio;Speaker;A2DP;
EOF
fi

# -------------------------------------------------------------------
# 6. PACKAGE APPIMAGE
# -------------------------------------------------------------------
echo -e "${BLUE}▶ 2/5 Packaging Universal AppImage (Runs on all Linux distros)...${RESET}"
APPDIR="/tmp/EverDialer_AppDir"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/lib" "$APPDIR/usr/share/icons/hicolor/512x512/apps"

cp -r "$BUNDLE_DIR/"* "$APPDIR/usr/bin/"
mv "$APPDIR/usr/bin/lib/"* "$APPDIR/usr/lib/" 2>/dev/null || true
cp "${PROJECT_DIR}/assets/icons/app_icon_512.png" "$APPDIR/ever_dialer_pc.png"
cp "${PROJECT_DIR}/assets/icons/app_icon_512.png" "$APPDIR/usr/share/icons/hicolor/512x512/apps/ever_dialer_pc.png"
cp "${PROJECT_DIR}/linux/ever_dialer_pc.desktop" "$APPDIR/ever_dialer_pc.desktop"

cat << 'EOF' > "$APPDIR/AppRun"
#!/bin/sh
HERE="$(dirname "$(readlink -f "${0}")")"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH}"
exec "${HERE}/usr/bin/ever_dialer_pc" "$@"
EOF
chmod +x "$APPDIR/AppRun"

APPIMAGE_OUT="${OUTPUT_DIR}/Ever-Dialer-PC-${VERSION}-${ARCH}.AppImage"
rm -f "$APPIMAGE_OUT"
ARCH=x86_64 appimagetool --runtime-file "${LOCAL_BIN}/runtime-x86_64" "$APPDIR" "$APPIMAGE_OUT" > /dev/null 2>&1 || \
ARCH=x86_64 appimagetool --appimage-extract-and-run --runtime-file "${LOCAL_BIN}/runtime-x86_64" "$APPDIR" "$APPIMAGE_OUT" > /dev/null 2>&1
chmod +x "$APPIMAGE_OUT"
rm -rf "$APPDIR"
echo -e "${GREEN}  ✓ Created AppImage:${RESET} $(basename "$APPIMAGE_OUT")"

# -------------------------------------------------------------------
# 7. PACKAGE DEB, RPM, & ARCH LINUX WITH NFPM
# -------------------------------------------------------------------
echo -e "${BLUE}▶ 3/5 Packaging Debian (.deb) for Ubuntu, Mint, Debian, Pop!_OS...${RESET}"
echo -e "${BLUE}▶ 4/5 Packaging RPM (.rpm) for Fedora, openSUSE, RHEL, Rocky...${RESET}"

NFPM_CONFIG="/tmp/ever_dialer_nfpm.yaml"
cat << EOF > "$NFPM_CONFIG"
name: "${APP_NAME}"
arch: "${DEB_ARCH}"
platform: "linux"
version: "${VERSION}"
section: "sound"
priority: "optional"
maintainer: "Hari <user@local>"
description: "Ever Dialer PC - Bluetooth Audio Companion & Dialer"
homepage: "https://github.com/hari161008/Ever-Dialer-PC"
license: "Proprietary"

contents:
  - src: "${BUNDLE_DIR}/"
    dst: "/opt/${BINARY_NAME}"
    type: "tree"
  - src: "${PROJECT_DIR}/assets/icons/app_icon_512.png"
    dst: "/usr/share/icons/hicolor/512x512/apps/ever_dialer_pc.png"
  - src: "${PROJECT_DIR}/linux/ever_dialer_pc.desktop"
    dst: "/usr/share/applications/ever_dialer_pc.desktop"
  - src: "/opt/${BINARY_NAME}/${BINARY_NAME}"
    dst: "/usr/bin/${BINARY_NAME}"
    type: "symlink"

depends:
  - gtk3
  - bluez
  - util-linux
  - python3
EOF

DEB_OUT="${OUTPUT_DIR}/${APP_NAME}_${VERSION}_${DEB_ARCH}.deb"
RPM_OUT="${OUTPUT_DIR}/${APP_NAME}-${VERSION}-1.${ARCH}.rpm"
ARCH_OUT="${OUTPUT_DIR}/${APP_NAME}-${VERSION}-1-${ARCH}.pkg.tar.zst"
rm -f "$DEB_OUT" "$RPM_OUT" "$ARCH_OUT"

nfpm package -f "$NFPM_CONFIG" --packager deb --target "$DEB_OUT" > /dev/null
echo -e "${GREEN}  ✓ Created DEB package:${RESET} $(basename "$DEB_OUT")"

nfpm package -f "$NFPM_CONFIG" --packager rpm --target "$RPM_OUT" > /dev/null
echo -e "${GREEN}  ✓ Created RPM package:${RESET} $(basename "$RPM_OUT")"

nfpm package -f "$NFPM_CONFIG" --packager archlinux --target "$ARCH_OUT" > /dev/null 2>&1 || true
if [ -f "$ARCH_OUT" ]; then
    echo -e "${GREEN}  ✓ Created Arch Linux package:${RESET} $(basename "$ARCH_OUT")"
fi

rm -f "$NFPM_CONFIG"

# -------------------------------------------------------------
# 8. PACKAGE PORTABLE TARBALL (.tar.gz)
# -------------------------------------------------------------
echo -e "${BLUE}▶ 5/5 Packaging Portable Tarball (.tar.gz) for any Linux distro...${RESET}"
PORTABLE_DIR="/tmp/${APP_NAME}-${VERSION}"
rm -rf "$PORTABLE_DIR"
mkdir -p "$PORTABLE_DIR"
cp -r "$BUNDLE_DIR/"* "$PORTABLE_DIR/"
cp "${PROJECT_DIR}/assets/icons/app_icon_512.png" "$PORTABLE_DIR/app_icon.png"
cp "${PROJECT_DIR}/linux/ever_dialer_pc.desktop" "$PORTABLE_DIR/ever_dialer_pc.desktop"

cat << 'EOF' > "$PORTABLE_DIR/run.sh"
#!/bin/sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export LD_LIBRARY_PATH="${SCRIPT_DIR}/lib:${LD_LIBRARY_PATH}"
exec "${SCRIPT_DIR}/ever_dialer_pc" "$@"
EOF
chmod +x "$PORTABLE_DIR/run.sh"

TAR_OUT="${OUTPUT_DIR}/${APP_NAME}-${VERSION}-linux-${ARCH}.tar.gz"
rm -f "$TAR_OUT"
tar -czf "$TAR_OUT" -C "/tmp" "${APP_NAME}-${VERSION}"
rm -rf "$PORTABLE_DIR"
echo -e "${GREEN}  ✓ Created Portable Tarball:${RESET} $(basename "$TAR_OUT")"

echo ""
echo -e "${BOLD}${GREEN}====================================================${RESET}"
echo -e "${BOLD}${GREEN}       ✔ ALL RELEASE PACKAGES CREATED SUCCESSFULLY   ${RESET}"
echo -e "${BOLD}${GREEN}====================================================${RESET}"
echo -e "Files are ready in: ${BOLD}${CYAN}${OUTPUT_DIR}${RESET}\n"

ls -lh "$OUTPUT_DIR"
echo ""
