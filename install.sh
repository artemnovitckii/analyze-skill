#!/usr/bin/env bash
# install.sh — one-step installer for the "analyze" skill + /analyze command.
# Safe to re-run (idempotent). Installs at the user level so it works in every
# Claude Code project/session.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE="$HOME/.claude"

echo "→ Installing analyze into $CLAUDE ..."
mkdir -p "$CLAUDE/skills" "$CLAUDE/commands"

# 1. Skill
rm -rf "$CLAUDE/skills/analyze"
cp -R "$HERE/skill/analyze" "$CLAUDE/skills/analyze"
chmod +x "$CLAUDE/skills/analyze/scripts/"*.sh "$CLAUDE/skills/analyze/scripts/"*.py 2>/dev/null || true
echo "  ✓ skill    → ~/.claude/skills/analyze"

# 2. /analyze command
cp "$HERE/commands/analyze.md" "$CLAUDE/commands/analyze.md"
echo "  ✓ command  → ~/.claude/commands/analyze.md  (run it as /analyze <url>)"

# 3. Dependencies
echo "→ Checking dependencies..."
if ! command -v yt-dlp >/dev/null 2>&1; then
  echo "  installing yt-dlp..."
  pip3 install -q --upgrade yt-dlp 2>/dev/null || pip3 install -q --upgrade --break-system-packages yt-dlp
fi
echo "    yt-dlp: $(command -v yt-dlp >/dev/null 2>&1 && echo ok || echo MISSING)"

if ! python3 -c "import groq" >/dev/null 2>&1; then
  echo "  installing groq sdk..."
  pip3 install -q --upgrade groq 2>/dev/null || pip3 install -q --upgrade --break-system-packages groq
fi
echo "    groq:   $(python3 -c 'import groq' >/dev/null 2>&1 && echo ok || echo MISSING)"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "    ffmpeg: MISSING — install it:"
  echo "            macOS:  brew install ffmpeg"
  echo "            Linux:  sudo apt install ffmpeg"
else
  echo "    ffmpeg: ok"
fi

# 4. Groq API key
# Stored in a skill-local file so the skill works inside Claude Code, which runs
# a NON-interactive shell that does not source ~/.zshrc. The skill also honors a
# GROQ_API_KEY env var (that takes precedence) if you prefer to set one.
echo ""
KEY_FILE="$CLAUDE/skills/analyze/.groq_key"
KEY="${GROQ_API_KEY:-}"
if [ -z "$KEY" ] && [ -s "$KEY_FILE" ]; then
  echo "  ✓ Groq key already stored at ~/.claude/skills/analyze/.groq_key"
else
  if [ -z "$KEY" ]; then
    echo "  One last step — get a FREE Groq API key: https://console.groq.com/keys"
    printf "  Paste it here (or press Enter to skip): "
    read -r KEY || true
  fi
  if [ -n "$KEY" ]; then
    printf '%s\n' "$KEY" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
    echo "  ✓ key stored → ~/.claude/skills/analyze/.groq_key (chmod 600)"
  else
    echo "  ⚠ No key set. Add one anytime:"
    echo "      printf '%s' 'gsk_yourkey' > \"$KEY_FILE\" && chmod 600 \"$KEY_FILE\""
    echo "    (Without it, the skill falls back to captions only — no real audio transcription.)"
  fi
fi

echo ""
echo "✅ Installed. Restart Claude Code, then try:  /analyze <tiktok|reels|shorts url>"
