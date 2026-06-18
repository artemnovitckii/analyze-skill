# analyze — short-form video breakdown for Claude Code

Paste a TikTok / Instagram Reels / YouTube Shorts link and get a full breakdown of
**why it works**: the data panel, the hook, script structure, style tags, viral
factors, and rewrite angles. It downloads the video and transcribes the *actual
audio* with Groq Whisper — so it works even on videos with no captions.

---

## Install (one command)

In a terminal:

```bash
git clone https://github.com/artemnovitckii/analyze-skill && bash analyze-skill/install.sh
```

The installer copies the skill + `/analyze` command into `~/.claude/`, vendors a
private self-updating `yt-dlp` into the skill, installs `ffmpeg` + the `groq`
package, verifies everything runs, and **prompts you to paste a free Groq API
key** (get one at <https://console.groq.com/keys>). Then restart Claude Code.

### Hands-off / non-interactive install

Pass the key as a flag (no prompt) — handy when you ask Claude Code to install it
for you:

```bash
git clone https://github.com/artemnovitckii/analyze-skill && \
  bash analyze-skill/install.sh --key gsk_yourkey
```

A `GROQ_API_KEY` environment variable works the same way. Either is saved to
`~/.claude/skills/analyze/.groq_key` (chmod 600) — a skill-local file, **not**
`~/.zshrc`. This matters: Claude Code runs each command in a *non-interactive*
shell that does **not** source `~/.zshrc`, so a key exported there is invisible
to the skill. The local file always works.

> Prefer an env var at runtime? Set `GROQ_API_KEY` in `~/.claude/settings.json`
> under an `"env": { ... }` block (Claude Code injects that into every command).
> A `GROQ_API_KEY` environment variable takes precedence over the `.groq_key` file.

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
