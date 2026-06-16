#!/usr/bin/env bash
# setup.sh — one-time dependency check for analyze. Idempotent.
set -uo pipefail
echo "→ Checking analyze dependencies..."

if ! command -v yt-dlp >/dev/null 2>&1; then
  echo "  installing yt-dlp..."
  pip3 install -q --upgrade yt-dlp 2>/dev/null || pip3 install -q --upgrade --break-system-packages yt-dlp
fi
echo "  yt-dlp:  $(command -v yt-dlp || echo MISSING)"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "  ⚠ ffmpeg missing — install it:"
  echo "      macOS:  brew install ffmpeg"
  echo "      Ubuntu: sudo apt install ffmpeg"
fi
echo "  ffmpeg:  $(command -v ffmpeg || echo MISSING)"

if ! python3 -c "import groq" >/dev/null 2>&1; then
  echo "  installing groq sdk..."
  pip3 install -q --upgrade groq 2>/dev/null || pip3 install -q --upgrade --break-system-packages groq
fi
python3 -c "import groq" >/dev/null 2>&1 && echo "  groq:    ok" || echo "  groq:    MISSING"

KEY_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.groq_key"
if [ -z "${GROQ_API_KEY:-}" ] && [ ! -s "$KEY_FILE" ]; then
  echo ""
  echo "  ✗ No Groq key found. Free key: https://console.groq.com/keys"
  echo "    Store it where the skill can always read it:"
  echo "      printf '%s' 'gsk_yourkey' > \"$KEY_FILE\" && chmod 600 \"$KEY_FILE\""
  echo "    (A GROQ_API_KEY env var also works and takes precedence.)"
  exit 1
fi
if [ -n "${GROQ_API_KEY:-}" ]; then
  echo "  Groq key: set via GROQ_API_KEY env ✓"
else
  echo "  Groq key: set via .groq_key file ✓"
fi
echo "→ Ready."
