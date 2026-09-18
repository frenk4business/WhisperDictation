#!/bin/bash
# Download Whisper model from Hugging Face
set -euo pipefail

MODEL_NAME="${1:-small-q5_1}"
case "$MODEL_NAME" in
    base-q5_1) SHA256=422f1ae452ade6f30a004d7e5c6a43195e4433bc370bf23fac9cc591f01a8898 ;;
    small-q5_1) SHA256=ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb ;;
    medium-q5_0) SHA256=19fea4b380c3a618ec4723c3eef2eb785ffba0d0538cf43f8f235e7b3b34220f ;;
    base.en) SHA256=a03779c86df3323075f5e796cb2ce5029f00ec8869eee3fdfb897afe36c6d002 ;;
    small.en) SHA256=c6138d6d58ecc8322097e0f987c32f1be8bb0a18532a3f88f734d1bbf9c41e5d ;;
    medium.en) SHA256=cc37e93478338ec7700281a7ac30a10128929eb8f427dda2e865faa8f6da4356 ;;
    base.en-q5_1) SHA256=4baf70dd0d7c4247ba2b81fafd9c01005ac77c2f9ef064e00dcf195d0e2fdd2f ;;
    small.en-q5_1) SHA256=bfdff4894dcb76bbf647d56263ea2a96645423f1669176f4844a1bf8e478ad30 ;;
    medium.en-q5_0) SHA256=76733e26ad8fe1c7a5bf7531a9d41917b2adc0f20f2e4f5531688a8c6cd88eb0 ;;
    *) echo "Unknown model. Select a model from the app catalog." >&2; exit 1 ;;
esac
MODEL_FILE="ggml-${MODEL_NAME}.bin"
MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/${MODEL_FILE}"

# App stores models in Application Support
APP_SUPPORT_DIR="$HOME/Library/Application Support/WhisperDictation/Models"
mkdir -p "$APP_SUPPORT_DIR"

DEST="$APP_SUPPORT_DIR/$MODEL_FILE"

if [ -f "$DEST" ]; then
    ACTUAL=$(shasum -a 256 "$DEST" | awk '{print $1}')
    if [ "$ACTUAL" != "$SHA256" ]; then
        echo "Existing model failed integrity check; it has not been overwritten: $DEST" >&2
        exit 1
    fi
    echo "Model already exists and checksum is valid: $DEST"
    exit 0
fi

echo "==> Downloading $MODEL_FILE..."
echo "    URL: $MODEL_URL"
echo "    Destination: $DEST"
echo ""

MODEL_TEMP=$(mktemp "$APP_SUPPORT_DIR/.whisper-download.XXXXXX")
trap 'rm -f -- "$MODEL_TEMP"' EXIT
curl --fail --location --progress-bar -o "$MODEL_TEMP" "$MODEL_URL"
ACTUAL=$(shasum -a 256 "$MODEL_TEMP" | awk '{print $1}')
if [ "$ACTUAL" != "$SHA256" ]; then
    echo "Download failed integrity check; temporary file discarded." >&2
    exit 1
fi
mv -n "$MODEL_TEMP" "$DEST"

SIZE=$(ls -lh "$DEST" | awk '{print $5}')
echo ""
echo "==> Downloaded $MODEL_FILE ($SIZE) to $DEST"
