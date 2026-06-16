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

if [ -z "${GROQ_API_KEY:-}" ]; then
  echo ""
  echo "  ✗ GROQ_API_KEY not set. Free key: https://console.groq.com/keys"
  echo "    Then: export GROQ_API_KEY=gsk_..."
  exit 1
fi
echo "  GROQ_API_KEY: set ✓"
echo "→ Ready."
