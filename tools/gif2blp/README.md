# gif2blp

Tiny CLI that turns a **GIF or video (mp4/mov/webm/mkv/avi/m4v)** into a **256×256 BLP frame
sequence** for the addon (`<name>_00.blp`, `_01.blp`, …). Built on `wow-blp` + `image`.
- **GIF**: pure Rust (`image` decodes frames + delays, coalesces, resizes). No external deps.
- **Video**: shells out to **ffmpeg** (`fps=12, scale=256`) to extract frames, then encodes BLP.
  (WoW never plays video; we pre-extract to BLP frames.)

### ffmpeg (only for video; no PATH edit needed)
The tool finds ffmpeg in this order: env `GIF2BLP_FFMPEG` → **next to `gif2blp.exe`** → current folder → PATH.
Easiest: drop **`ffmpeg.exe`** into `tools\gif2blp\target\release\` (next to `gif2blp.exe`). Done — no PATH changes.
Alternatively per-run: `set GIF2BLP_FFMPEG=C:\path\to\ffmpeg.exe` before running.

## Build (once)
1. Install Rust: https://rustup.rs  (gives `cargo`)
2. From this folder:
   ```
   cargo build --release
   ```
   Binary: `target/release/gif2blp` (`.exe` on Windows).

## Use (batch — fully automatic)
1. Drop your GIFs/videos into **`assets/raw_gifs/`** (filename = emote token, e.g. `ronaldo.gif`/`ronaldo.mp4` → `#ronaldo`).
2. Run from the **addon root**:
   ```
   tools\gif2blp\target\release\gif2blp.exe
   ```
   (optional: `gif2blp <base_dir>` if not run from the addon root)

It then, for every gif in `raw_gifs/`:
- decodes + coalesces frames, resizes to 256, writes `assets/gifs/<name>/<name>_00.blp …`,
- and **overwrites `GigaKloce_Emotes.lua`** with the full `GK.EMOTES = { … }` manifest,
- prints a summary (name / frames / fps).

No manual editing — just `/reload` in game. Any failure aborts (non-zero exit).
Names must be `a-z 0-9 _` (lowercased from the filename).

## Notes
- Output is fixed at 256×256 (`SIZE` in `src/main.rs`).
- GIF frames are **coalesced** (delta frames composited to full frames) — optimized GIFs work.
- Naming uses min-2-digit (`_00`, `_01`, … `_100`), matching the addon's Lua `%02d`. More frames = more VRAM; keep it sane.
- `target/` and `Cargo.lock` are git-ignored; nothing here ships in the addon zip.
