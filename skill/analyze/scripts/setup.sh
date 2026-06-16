#!/usr/bin/env bash
# setup.sh — make analyze's dependencies present AND actually runnable. Idempotent.
#
# Built to work "no matter what":
#   • yt-dlp is vendored as a PRIVATE, self-updating copy inside the skill, so the
#     skill never depends on a broken/stale/missing system yt-dlp (and keeps
#     working even when Claude Code's minimal PATH hides system binaries).
#   • ffmpeg is auto-installed via whatever package manager exists.
#   • the groq SDK is installed under the SAME python3 the skill runs, with a
#     real PEP-668 / --user / --break-system-packages fallback ladder.
#   • every dependency is VERIFIED to execute before we report success.
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$SKILL_DIR/bin"
KEY_FILE="$SKILL_DIR/.groq_key"
mkdir -p "$BIN_DIR"

PY="$(command -v python3 || true)"
HARD_FAIL=0

echo "→ Setting up analyze dependencies..."

# --- 1. yt-dlp (private, vendored zipapp) -----------------------------------
YTDLP="$BIN_DIR/yt-dlp"
ytdlp_runs () {  # $1 = path to a yt-dlp; run it with our python (zipapp) to test
  [ -n "$PY" ] && [ -f "$1" ] && "$PY" "$1" --version >/dev/null 2>&1
}

if ytdlp_runs "$YTDLP"; then
  echo "  yt-dlp:  updating private copy..."
  "$PY" "$YTDLP" -U >/dev/null 2>&1 || true
else
  echo "  yt-dlp:  installing private copy into the skill..."
  URL="https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$URL" -o "$YTDLP" 2>/dev/null || true
  elif command -v wget >/dev/null 2>&1; then
    wget -q "$URL" -O "$YTDLP" 2>/dev/null || true
  fi
  chmod +x "$YTDLP" 2>/dev/null || true
fi

if ytdlp_runs "$YTDLP"; then
  echo "  yt-dlp:  ok ($("$PY" "$YTDLP" --version 2>/dev/null))  → skill-private"
elif command -v yt-dlp >/dev/null 2>&1 && yt-dlp --version >/dev/null 2>&1; then
  echo "  yt-dlp:  ok ($(yt-dlp --version 2>/dev/null))  → system (private copy unavailable)"
else
  echo "  yt-dlp:  ✗ no working yt-dlp (needs internet + python3, or: brew install yt-dlp)"
  HARD_FAIL=1
fi

# --- 2. ffmpeg --------------------------------------------------------------
if command -v ffmpeg >/dev/null 2>&1; then
  echo "  ffmpeg:  ok"
else
  echo "  ffmpeg:  missing — attempting install..."
  if command -v brew >/dev/null 2>&1; then
    brew install ffmpeg >/dev/null 2>&1 || true
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -qq >/dev/null 2>&1 && sudo apt-get install -y ffmpeg >/dev/null 2>&1 || true
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y ffmpeg >/dev/null 2>&1 || true
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --noconfirm ffmpeg >/dev/null 2>&1 || true
  fi
  if command -v ffmpeg >/dev/null 2>&1; then
    echo "  ffmpeg:  ok (installed)"
  else
    echo "  ffmpeg:  ⚠ not installed — whisper needs it. Install manually:"
    echo "             macOS:  brew install ffmpeg"
    echo "             Linux:  sudo apt install ffmpeg   (or dnf/pacman)"
    echo "           (Without ffmpeg the skill still works but only via captions.)"
  fi
fi

# --- 3. groq SDK (under the SAME python3 the skill uses) --------------------
if [ -z "$PY" ]; then
  echo "  groq:    ✗ python3 not found — install Python 3"
  HARD_FAIL=1
else
  if ! "$PY" -c "import groq" >/dev/null 2>&1; then
    echo "  groq:    installing..."
    "$PY" -m pip install -q --upgrade groq >/dev/null 2>&1 \
      || "$PY" -m pip install -q --upgrade --user groq >/dev/null 2>&1 \
      || "$PY" -m pip install -q --upgrade --break-system-packages groq >/dev/null 2>&1 \
      || true
  fi
  if "$PY" -c "import groq" >/dev/null 2>&1; then
    echo "  groq:    ok"
  else
    echo "  groq:    ✗ could not install groq (try: $PY -m pip install --user groq)"
    HARD_FAIL=1
  fi
fi

# --- 4. Groq API key --------------------------------------------------------
if [ -n "${GROQ_API_KEY:-}" ]; then
  echo "  groq key: ok (GROQ_API_KEY env)"
elif [ -s "$KEY_FILE" ]; then
  echo "  groq key: ok (.groq_key file)"
else
  echo "  groq key: ⚠ none set — get a FREE key: https://console.groq.com/keys"
  echo "             printf '%s' 'gsk_yourkey' > \"$KEY_FILE\" && chmod 600 \"$KEY_FILE\""
  echo "           (Without it the skill falls back to captions only.)"
fi

echo ""
if [ "$HARD_FAIL" -eq 0 ]; then
  echo "✓ analyze is ready."
else
  echo "✗ Setup incomplete — see the ✗ lines above."
  exit 1
fi
