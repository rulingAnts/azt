#!/bin/bash
# Build A-Z+T for macOS arm64 (Apple Silicon) — offline build script
#
# Prerequisites:
#   - Homebrew  (https://brew.sh)
#   - Python 3.12+ (arm64-native; verify with `python3 -c "import platform; print(platform.machine())"`)
#   - Xcode Command Line Tools  (`xcode-select --install`)
#
# Usage (from repo root):
#   bash build/build_macos_arm64.sh

set -euo pipefail

APP_VERSION="1.0.5"   # keep in sync with program['version'] in main.py
APP_NAME="A-Z+T"
BUNDLE_ID="org.sil.azt"
ARCH="arm64"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$REPO_ROOT"

echo "==> Repo root: $REPO_ROOT"
echo "==> A-Z+T version: $APP_VERSION  arch: $ARCH"

# --- 1. Prerequisites check --------------------------------------------------
echo ""
echo "==> Checking prerequisites..."
if ! command -v brew &>/dev/null; then
    echo "ERROR: Homebrew not found. Install from https://brew.sh/"
    exit 1
fi

PYTHON_ARCH=$(python3 -c "import platform; print(platform.machine())" 2>/dev/null || echo "unknown")
if [ "$PYTHON_ARCH" != "arm64" ]; then
    echo "WARNING: python3 reports arch='$PYTHON_ARCH', expected 'arm64'."
    echo "  If you're on Apple Silicon, make sure you're using a native arm64 Python"
    echo "  (not Rosetta). Download from https://www.python.org/downloads/macos/"
    read -rp "Continue anyway? [y/N] " yn
    [[ "$yn" =~ ^[Yy] ]] || exit 1
fi

# --- 2. System dependencies --------------------------------------------------
echo ""
echo "==> Installing system dependencies via Homebrew..."
brew install portaudio gettext 2>/dev/null || true

# --- 3. Python dependencies --------------------------------------------------
echo ""
echo "==> Installing Python dependencies..."
pip3 install --upgrade pip
pip3 install pyinstaller \
    pyaudio Pillow lxml psutil soundfile librosa \
    "langcodes[data]" patiencediff reportlab svglib \
    packaging numpy scipy

# --- 4. Compile translations -------------------------------------------------
echo ""
echo "==> Compiling translations..."
python3 translations/compile.py || echo "Translation compile skipped (non-fatal)"

# --- 5. PyInstaller build ----------------------------------------------------
echo ""
echo "==> Building app bundle with PyInstaller..."
python3 -m PyInstaller azt.spec --clean --noconfirm

echo "==> Built: dist/${APP_NAME}.app"

# --- 6. Charis SIL font ------------------------------------------------------
echo ""
echo "==> Fetching Charis SIL font..."
CHARIS_ZIP="CharisSIL-6.200.zip"
if [ ! -f "$CHARIS_ZIP" ]; then
    curl -fL "https://software.sil.org/downloads/r/charis/${CHARIS_ZIP}" -o "$CHARIS_ZIP"
fi
rm -rf CharisSIL_extracted
unzip -qo "$CHARIS_ZIP" -d CharisSIL_extracted

echo "==> Bundling fonts into app..."
FONT_DEST="dist/${APP_NAME}.app/Contents/Resources/fonts"
mkdir -p "$FONT_DEST"
find CharisSIL_extracted -name "*.ttf" -exec cp {} "$FONT_DEST/" \;

# --- 7. component .pkg -------------------------------------------------------
echo ""
echo "==> Building main component .pkg..."
chmod +x build/installer_macos/scripts/postinstall
pkgbuild \
    --component "dist/${APP_NAME}.app" \
    --install-location /Applications \
    --identifier "$BUNDLE_ID" \
    --version "$APP_VERSION" \
    --scripts build/installer_macos/scripts \
    azt_component.pkg

# --- 7b. ASR component .pkg (scripts only; pip-installs from PyPI at user request)
echo ""
echo "==> Building optional ASR component .pkg..."
chmod +x build/installer_macos/scripts/postinstall_asr
ASR_SCRIPTS_TMP="$(mktemp -d)"
cp build/installer_macos/scripts/postinstall_asr "$ASR_SCRIPTS_TMP/postinstall"
pkgbuild \
    --nopayload \
    --identifier "${BUNDLE_ID}.asr" \
    --version "$APP_VERSION" \
    --scripts "$ASR_SCRIPTS_TMP" \
    azt_asr_component.pkg
rm -rf "$ASR_SCRIPTS_TMP"

# --- 8. distributable .pkg ---------------------------------------------------
echo ""
echo "==> Building distributable .pkg..."
productbuild \
    --distribution build/installer_macos/distribution.xml \
    --resources build/installer_macos/resources \
    --package-path . \
    "${APP_NAME}-${APP_VERSION}-macos-${ARCH}.pkg"

# --- 9. DMG ------------------------------------------------------------------
echo ""
echo "==> Creating DMG..."
STAGING="dmg_staging_${ARCH}"
rm -rf "$STAGING"
mkdir "$STAGING"
cp "${APP_NAME}-${APP_VERSION}-macos-${ARCH}.pkg" "$STAGING/"
cat > "$STAGING/README.txt" <<'EOF'
A-Z+T Installer
===============
Double-click AZT-*.pkg to install A-Z+T.

During installation you will be offered an optional
"ASR Speech Recognition Features" component (~4 GB download).
You can leave this unchecked and install it later by
re-running the .pkg installer.
EOF
hdiutil create \
    -volname "${APP_NAME} ${APP_VERSION}" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "${APP_NAME}-${APP_VERSION}-macos-${ARCH}.dmg"
rm -rf "$STAGING" azt_component.pkg azt_asr_component.pkg

# --- Done --------------------------------------------------------------------
echo ""
echo "============================================================"
echo "  Output: ${APP_NAME}-${APP_VERSION}-macos-${ARCH}.dmg"
echo "============================================================"
echo ""
echo "NOTES:"
echo "  - The app is UNSIGNED. macOS will warn 'unidentified developer'."
echo "    To allow: System Settings → Privacy & Security → Open Anyway"
echo "  - ASR/Whisper features are NOT bundled."
echo "    Install separately: pip3 install torch openai-whisper"
echo "  - Praat and XLingPaper are not bundled; install them separately."
echo ""
