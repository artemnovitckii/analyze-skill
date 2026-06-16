---
name: analyze
description: "Use when the user gives a TikTok/Instagram Reels/YouTube Shorts URL (or runs /analyze <url>) and wants to know why the video works. Downloads the video, transcribes the actual audio with Groq Whisper (works even when there are no captions), then breaks down the data panel, hook, script structure, style tags, viral factors, and rewrite angles."
---

# /analyze — Short-Form Video Breakdown

Reverse-engineer any Reel / TikTok / Short: why it works, and how to remake it.

## Input

`$ARGUMENTS` = one video URL (TikTok / Instagram Reels / YouTube Shorts).
If the user gives no URL, ask for one.

## Setup (first run only)

This skill needs `yt-dlp`, `ffmpeg`, the `groq` python package, and a Groq key.
Run `bash ~/.claude/skills/analyze/scripts/setup.sh` once. The key is read from
(1) the `GROQ_API_KEY` env var, or (2) the skill-local file
`~/.claude/skills/analyze/.groq_key`. If neither is present, stop and tell the user:
> Set a free Groq key (console.groq.com/keys). Easiest: save it to the skill file —
> `printf '%s' 'gsk_...' > ~/.claude/skills/analyze/.groq_key && chmod 600 ~/.claude/skills/analyze/.groq_key`
> (An exported `GROQ_API_KEY` won't reach this skill — Claude Code's shell doesn't source `~/.zshrc`.)

## Step 1: Extract

```bash
python3 ~/.claude/skills/analyze/scripts/analyze-video.py "$ARGUMENTS"
```

Returns JSON with:
- `platform`: tiktok / instagram / youtube
- `metadata`: title, description, uploader, duration, views, likes, comments, shares, engagement_rate_pct
- `transcript`: the spoken words of the video (may be null)
- `transcript_source`: `whisper` (audio transcription, the default) · `caption` (fell back to platform subtitles) · `null` (none available)

**How transcription works here:** the script downloads the video, strips the
audio, and transcribes it with Groq `whisper-large-v3-turbo`. This is the key
difference from caption-scraping tools — it reads the actual audio, so it still
works on videos that ship no caption track. Captions are only a fallback.

### Fallback ladder (only if `metadata._error` is present)

1. **WebFetch** the video URL with the prompt:
   > "Extract all video metadata: title, description, author name, author handle, view count, like count, comment count, share count, duration, and any transcript/caption text visible on the page."
2. **Ask the user** to paste the script text and the stats (a screenshot is fine).

Note the data source and completeness at the top of the output whenever a
fallback was used, or when `transcript_source` is `caption` or `null`.

## Step 2: Analyze

Produce the following. English output. Never invent numbers — anything null in
the JSON is written `N/A`.

### 2.1 Data Panel
Table: platform, uploader, duration, views, likes, comments, shares.
Engagement rate = (likes + comments) / views. Skip it if views is null.
Remember metrics are reliable for YouTube, partial for TikTok, usually `N/A` for Instagram.

### 2.2 Full Transcript
Print the complete transcript **verbatim** from the JSON `transcript` field, inside
a fenced block or blockquote so it's easy to copy. Do not summarize, trim, or
paraphrase — show every word. Lead with a one-line source note:
`Transcript (whisper — actual audio)` or `Transcript (caption — platform subtitles)`.
If `transcript` is null, write "_No transcript available_" and continue.

### 2.3 Hook (first 3 seconds)
From the first 1-3 sentences of the transcript:
- **Hook type**: curiosity gap / shocking stat / bold claim / question / visual hook / pattern interrupt
- **Why it stops the scroll**: tie it to the exact opening line
- **Rewrite**: a sharper alternative hook line
If there's no transcript, infer the hook strategy from title + description and flag low confidence.

### 2.4 Script Structure
Segment the transcript by narrative function:

| Segment | Est. timing | Content | Function |
|---------|-------------|---------|----------|

Typical arc: Hook → Problem/Context → Solution/Reveal → Proof/Example → CTA.
Analyze pacing: is information density right, where's the turn, where do viewers drop?
Use the but/therefore lens — flag flat "and then" joins where tension goes slack.

### 2.5 Style Tags
- **Presentation**: talking head / voiceover / text-on-screen / skit / montage / screencast / interview
- **Content type**: educational / entertainment / storytelling / review / tutorial / hot-take / news
- **Emotional tone**: urgent / curious / funny / shocking / relatable / authoritative

### 2.6 Why It Went Viral
2-3 specific reasons. Be concrete. Not "the content is good" but
"the opening builds contrast with a hard number ($0 → $10K) and lands a clear value promise inside 3 seconds."

### 2.7 Rewrite Directions
3 actionable angles. Each with:
- **Angle**: one line
- **Hook example**: the actual rewritten hook line
- **Best platform**: Reel / TikTok / Shorts, and why

## Step 3: Output

Output 2.1-2.7 in order, clean markdown with tables and section headings.
Always include the full transcript (2.2) — never replace it with a summary.
End with one line:
> Source: yt-dlp + Groq Whisper (`transcript_source`) | Analysis: Claude

## Step 4: Log to results library

Append (never overwrite) one record to
`~/.claude/skills/analyze/results/analyzed-videos.md`:

```markdown
## [YYYY-MM-DD] Uploader — Title/Topic (platform)

- URL: <link>
- Stats: views X / likes X / comments X / shares X
- Hook type: ...
- Why it worked: one-line takeaway
- Rewrite angle: one-line takeaway

---
```

This file is the cross-video pattern library — when the user later asks to "find
the pattern across the ones I've analyzed," read this file instead of re-running extraction.

## Notes
- If no transcript, note "Couldn't transcribe — analysis based on metadata and description" at the top and lower the confidence, but still deliver.
- Never fabricate data. Missing metric = `N/A`.
- Skip engagement rate if view_count is missing.
- Keep technical terms in English (hook, CTA, talking head).
