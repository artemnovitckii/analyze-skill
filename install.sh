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
echo ""
if [ -z "${GROQ_API_KEY:-}" ]; then
  echo "  ⚠ One last step — set a FREE Groq API key (https://console.groq.com/keys):"
  echo ""
  echo "      echo 'export GROQ_API_KEY=gsk_yourkey' >> ~/.zshrc && source ~/.zshrc"
  echo ""
  echo "    (Without it, the skill falls back to captions only — no real audio transcription.)"
else
  echo "  ✓ GROQ_API_KEY is set."
fi

echo ""
echo "✅ Installed. Restart Claude Code, then try:  /analyze <tiktok|reels|shorts url>"
