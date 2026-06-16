# analyze

A Claude Code skill that reverse-engineers any TikTok / Instagram Reel / YouTube Short.

Paste a URL, get a six-panel breakdown: data panel, hook deconstruction, script
structure, style tags, why it went viral, and three rewrite directions.

**What's different:** instead of scraping whatever caption track a platform
happens to expose, analyze downloads the video and transcribes the actual audio
with Groq Whisper (`whisper-large-v3-turbo`). So it gets the real spoken script
every time — even on videos with no captions. Captions are only a fallback.

## Use

In Claude Code:

```
/analyze https://www.tiktok.com/@someone/video/1234567890
/analyze https://www.instagram.com/reel/abcDEF123/
/analyze https://www.youtube.com/shorts/abcdefg
```

## Install

```bash
cp -r analyze ~/.claude/skills/analyze
bash ~/.claude/skills/analyze/scripts/setup.sh
export GROQ_API_KEY=gsk_...   # free key at console.groq.com/keys
```

## How it works

1. `yt-dlp` downloads the video + metadata.
2. `ffmpeg` strips the audio to mono 16kHz.
3. Groq `whisper-large-v3-turbo` transcribes it.
4. Claude writes the breakdown from the transcript + metadata.
5. Each run is appended to `results/analyzed-videos.md` for cross-video comparison.

## Notes

- Metrics are reliable for YouTube, partial for TikTok, usually unavailable for
  Instagram (IG hides like/comment counts). Missing metrics show as `N/A` —
  never guessed.
- If yt-dlp fails entirely, the skill falls back to WebFetch, then to asking you
  to paste the script manually.

Built on the structure of an original short-form-analysis skill by hongfamonvAI (MIT),
with audio transcription added and English output.

MIT
