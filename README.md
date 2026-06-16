# analyze — short-form video breakdown for Claude Code

Paste a TikTok / Instagram Reels / YouTube Shorts link and get a full breakdown of
**why it works**: the data panel, the hook, script structure, style tags, viral
factors, and rewrite angles. It downloads the video and transcribes the *actual
audio* with Groq Whisper — so it works even on videos with no captions.

---

## Install (one command)

1. Unzip this folder anywhere.
2. In a terminal, run:

   ```bash
   bash install.sh
   ```

   That copies the skill + `/analyze` command into `~/.claude/`, installs the
   `yt-dlp` and `groq` Python packages, checks for `ffmpeg`, and **prompts you to
   paste a free Groq API key** (get one at <https://console.groq.com/keys>).

   The key is saved to `~/.claude/skills/analyze/.groq_key` (chmod 600) — a
   skill-local file, **not** `~/.zshrc`. This matters: Claude Code runs each
   command in a *non-interactive* shell that does **not** source `~/.zshrc`, so a
   key exported there is invisible to the skill. The local file always works.

3. Restart Claude Code.

> Prefer an env var? Set `GROQ_API_KEY` in `~/.claude/settings.json` under an
> `"env": { ... }` block (Claude Code injects that into every command). A
> `GROQ_API_KEY` environment variable takes precedence over the `.groq_key` file.

## Use

Either type the command:

```
/analyze https://www.tiktok.com/@user/video/123...
```

…or just paste a video URL and ask "why does this work?" — the skill auto-triggers.

## Requirements

- **ffmpeg** — `brew install ffmpeg` (macOS) or `sudo apt install ffmpeg` (Linux).
  The installer warns you if it's missing.
- **Python 3** with pip (the installer handles the `yt-dlp` + `groq` packages).
- A **Groq API key** (free).

## What got installed

| Piece | Location |
|-------|----------|
| Skill | `~/.claude/skills/analyze/` |
| `/analyze` command | `~/.claude/commands/analyze.md` |

To uninstall: delete those two paths.
