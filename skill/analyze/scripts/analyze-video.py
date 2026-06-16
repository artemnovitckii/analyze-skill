#!/usr/bin/env python3
"""
analyze-video.py — extract everything needed to break down a short-form video.

Pipeline:
  1. yt-dlp  -> download video file + metadata json
  2. ffmpeg  -> strip audio to mono 16kHz mp3
  3. Groq    -> transcribe with whisper-large-v3-turbo (the real spoken words)

Transcription strategy (this is the upgrade over caption-scraping versions):
  - PRIMARY: Whisper transcribes the actual audio. Works even when the
    platform ships no caption track.
  - FALLBACK: if Whisper/audio fails, fall back to yt-dlp's caption/subtitle
    text so we still return something.
  - Metrics that yt-dlp can't supply are returned as null. Never guessed.

Outputs a single JSON object to stdout. Usage:
    python3 analyze-video.py "<url>"
"""
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path


def detect_platform(url: str) -> str:
    u = url.lower()
    if "instagram.com" in u:
        return "instagram"
    if "tiktok.com" in u:
        return "tiktok"
    if "youtube.com" in u or "youtu.be" in u:
        return "youtube"
    return "unknown"


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)


def ytdlp_download(url: str, workdir: Path) -> dict:
    """Download the video + info json. Returns parsed info dict or {'_error': ...}."""
    out_tmpl = str(workdir / "video.%(ext)s")
    cmd = [
        "yt-dlp",
        "-f", "mp4/best[ext=mp4]/best",
        "-o", out_tmpl,
        "--write-info-json",
        "--no-playlist",
        "--no-warnings",
        # write any available captions/subs as a fallback transcript source
        "--write-subs", "--write-auto-subs",
        "--sub-format", "vtt",
        "--sub-langs", "en.*,en",
        url,
    ]
    r = run(cmd)
    info_files = list(workdir.glob("video*.info.json"))
    if not info_files:
        return {"_error": (r.stderr or "yt-dlp produced no metadata").strip()[-800:]}
    with open(info_files[0]) as f:
        return json.load(f)


def extract_metrics(info: dict) -> dict:
    def g(*keys):
        for k in keys:
            v = info.get(k)
            if v is not None:
                return v
        return None

    views = g("view_count")
    likes = g("like_count")
    comments = g("comment_count")
    shares = g("repost_count", "share_count")

    eng = None
    if isinstance(views, int) and views > 0:
        parts = [x for x in (likes, comments) if isinstance(x, int)]
        if parts:
            eng = round(sum(parts) / views * 100, 2)

    return {
        "views": views,
        "likes": likes,
        "comments": comments,
        "shares": shares,
        "engagement_rate_pct": eng,
    }


def find_video(workdir: Path):
    for p in workdir.glob("video.*"):
        if p.suffix in (".json",) or p.name.endswith(".info.json") or p.suffix == ".vtt":
            continue
        return p
    return None


def extract_audio(video: Path, workdir: Path):
    audio = workdir / "audio.mp3"
    r = run([
        "ffmpeg", "-y", "-i", str(video),
        "-ar", "16000", "-ac", "1", "-b:a", "64k",
        str(audio),
    ])
    return audio if (r.returncode == 0 and audio.exists()) else None


def load_groq_key():
    """Resolve the Groq key independent of shell init files.

    Precedence:
      1. GROQ_API_KEY environment variable
      2. skill-local key file: ~/.claude/skills/analyze/.groq_key
    Claude Code runs a non-interactive shell that does NOT source ~/.zshrc,
    so the local key file is the reliable path for that environment.
    """
    key = os.environ.get("GROQ_API_KEY")
    if key and key.strip():
        return key.strip()
    key_file = Path(__file__).resolve().parent.parent / ".groq_key"
    if key_file.exists():
        val = key_file.read_text(encoding="utf-8").strip()
        # accept a bare key or "GROQ_API_KEY=..." / "export GROQ_API_KEY=..."
        if "=" in val:
            val = val.split("=", 1)[1]
        val = val.strip().strip('"').strip("'")
        return val or None
    return None


def whisper_transcribe(audio: Path):
    """Transcribe via Groq. Returns (text, source) or (None, reason)."""
    key = load_groq_key()
    if not key:
        return None, "GROQ_API_KEY not set"
    try:
        from groq import Groq
    except ImportError:
        return None, "groq sdk not installed"
    try:
        client = Groq(api_key=key)
        with open(audio, "rb") as f:
            resp = client.audio.transcriptions.create(
                file=(audio.name, f.read()),
                model="whisper-large-v3-turbo",
                response_format="text",
            )
        text = resp if isinstance(resp, str) else getattr(resp, "text", str(resp))
        text = (text or "").strip()
        return (text, "whisper") if text else (None, "whisper returned empty")
    except Exception as e:
        return None, f"whisper error: {e}"


def caption_fallback(workdir: Path):
    """Parse any yt-dlp .vtt caption file into plain text."""
    vtts = list(workdir.glob("*.vtt"))
    if not vtts:
        return None
    lines = []
    for raw in open(vtts[0], encoding="utf-8", errors="ignore"):
        s = raw.strip()
        if not s or s == "WEBVTT" or "-->" in s or s.isdigit():
            continue
        if s.startswith(("Kind:", "Language:", "NOTE")):
            continue
        if s not in lines[-1:]:  # collapse immediate dupes from auto-subs
            lines.append(s)
    text = " ".join(lines).strip()
    return text or None


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"_error": 'usage: analyze-video.py "<url>"'}))
        sys.exit(1)
    url = sys.argv[1].strip()
    platform = detect_platform(url)

    with tempfile.TemporaryDirectory(prefix="analyze_") as tmp:
        workdir = Path(tmp)
        info = ytdlp_download(url, workdir)

        if "_error" in info:
            # Hand control back to SKILL.md fallback ladder (WebFetch / manual)
            print(json.dumps({
                "platform": platform,
                "url": url,
                "metadata": {"_error": info["_error"]},
                "transcript": None,
                "transcript_source": None,
            }, ensure_ascii=False, indent=2))
            return

        metrics = extract_metrics(info)
        transcript, source = None, None

        video = find_video(workdir)
        if video:
            audio = extract_audio(video, workdir)
            if audio:
                transcript, source = whisper_transcribe(audio)

        # Fallback to platform captions if Whisper couldn't run
        if not transcript:
            cap = caption_fallback(workdir)
            if cap:
                transcript, source = cap, "caption"

        out = {
            "platform": platform,
            "url": url,
            "metadata": {
                "title": info.get("title"),
                "description": (info.get("description") or "")[:2000],
                "uploader": info.get("uploader") or info.get("channel"),
                "uploader_handle": info.get("uploader_id"),
                "duration": info.get("duration"),
                "views": metrics["views"],
                "likes": metrics["likes"],
                "comments": metrics["comments"],
                "shares": metrics["shares"],
                "engagement_rate_pct": metrics["engagement_rate_pct"],
            },
            "transcript": transcript,
            "transcript_source": source,  # "whisper" | "caption" | None
        }
        print(json.dumps(out, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
