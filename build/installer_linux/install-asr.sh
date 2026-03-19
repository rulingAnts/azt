#!/bin/bash
# install-asr.sh — optional ASR/Speech Recognition features for A-Z+T (Linux)
#
# Run this script manually after installing A-Z+T if you want
# speech recognition (Whisper/PyTorch) functionality.
#
# This script installs PyTorch, Whisper, and supporting packages into
# an isolated venv at ~/.azt-asr/ so they don't affect your system Python.
#
# The app's asr.py looks for ~/.azt-asr/ when loading these features.
#
# Usage:
#   bash install-asr.sh
#
# Requirements:
#   - Python 3.10 or later
#   - Internet connection (~4 GB download)

set -euo pipefail

ASR_ENV="$HOME/.azt-asr"

echo "==> A-Z+T optional ASR features installer"
echo "    This will download approximately 4 GB from PyPI."
echo "    Venv location: $ASR_ENV"
echo ""
read -rp "Continue? [y/N] " yn
[[ "$yn" =~ ^[Yy] ]] || { echo "Aborted."; exit 0; }

# Find a usable Python 3
PYTHON=""
for candidate in python3.12 python3.11 python3.10 python3; do
    if command -v "$candidate" &>/dev/null; then
        PYTHON="$(command -v "$candidate")"
        break
    fi
done

if [ -z "$PYTHON" ]; then
    echo "ERROR: No Python 3 found. Install python3 with your package manager." >&2
    exit 1
fi

echo "==> Using Python: $PYTHON ($($PYTHON --version))"

echo "==> Creating venv..."
"$PYTHON" -m venv "$ASR_ENV"

echo "==> Installing packages from PyPI..."
"$ASR_ENV/bin/pip" install --upgrade pip
"$ASR_ENV/bin/pip" install \
    torch \
    openai-whisper \
    transformers \
    "huggingface_hub[hf_xet]"

# Write marker file so A-Z+T can locate this env
printf '%s' "$ASR_ENV" > "$HOME/.config/azt/asr-env-path.txt" 2>/dev/null || \
    printf '%s' "$ASR_ENV" > "$HOME/.azt-asr-path.txt"

echo ""
echo "==> ASR features installed to: $ASR_ENV"
echo "    Restart A-Z+T to use speech recognition features."
