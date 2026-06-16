#!/usr/bin/env bash
# install.sh — one-step installer for the "analyze" skill + /analyze command.
# Safe to re-run (idempotent). Installs at the user level so it works in every
# Claude Code project/session. All dependency work is delegated to the skill's
# own setup.sh so the logic lives in one place.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE="$HOME/.claude"
SKILL="$CLAUDE/skills/analyze"
KEY_FILE="$SKILL/.groq_key"

echo "→ Installing analyze into $CLAUDE ..."
mkdir -p "$CLAUDE/skills" "$CLAUDE/commands"

# 1. Skill — preserve an existing Groq key across reinstalls.
SAVED_KEY=""
[ -s "$KEY_FILE" ] && SAVED_KEY="$(cat "$KEY_FILE")"
rm -rf "$SKILL"
cp -R "$HERE/skill/analyze" "$SKILL"
chmod +x "$SKILL/scripts/"*.sh "$SKILL/scripts/"*.py 2>/dev/null || true
if [ -n "$SAVED_KEY" ]; then
  printf '%s\n' "$SAVED_KEY" > "$KEY_FILE"
  chmod 600 "$KEY_FILE"
fi
echo "  ✓ skill    → ~/.claude/skills/analyze"

# 2. /analyze command
cp "$HERE/commands/analyze.md" "$CLAUDE/commands/analyze.md"
echo "  ✓ command  → ~/.claude/commands/analyze.md  (run it as /analyze <url>)"

# 3. Groq API key (skill-local file; Claude Code's non-interactive shell does
#    NOT source ~/.zshrc, so an exported env var there would be invisible).
echo ""
if [ -z "${GROQ_API_KEY:-}" ] && [ ! -s "$KEY_FILE" ]; then
  echo "  Get a FREE Groq API key: https://console.groq.com/keys"
  printf "  Paste it here (or press Enter to skip): "
  read -r KEY || true
  if [ -n "${KEY:-}" ]; then
    printf '%s\n' "$KEY" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
    echo "  ✓ key stored → ~/.claude/skills/analyze/.groq_key (chmod 600)"
  fi
fi

# 4. Dependencies + verification (vendored yt-dlp, ffmpeg, groq SDK).
echo ""
bash "$SKILL/scripts/setup.sh"
STATUS=$?

echo ""
if [ "$STATUS" -eq 0 ]; then
  echo "✅ Installed. Restart Claude Code, then try:  /analyze <tiktok|reels|shorts url>"
else
  echo "⚠ Installed the skill, but some dependencies need attention (see above)."
  echo "   Fix them, then re-run:  bash ~/.claude/skills/analyze/scripts/setup.sh"
fi
exit "$STATUS"
