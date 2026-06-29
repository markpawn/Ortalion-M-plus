// gif2blp — BATCH: converts every assets/raw_gifs/*.gif into a 256x256 BLP frame
// sequence (assets/gifs/<name>/<name>_NN.blp) and OVERWRITES GigaKloce_Emotes.lua
// with the full GK.EMOTES manifest. Any failure aborts (non-zero exit).
//
// Usage (run from the addon root):
//   gif2blp            (base dir = ".")
//   gif2blp <base_dir>
//
// <name> = lowercased gif filename stem (must be a-z 0-9 _ to match the #token).

use std::fs;
use std::path::{Path, PathBuf};

use image::codecs::gif::GifDecoder;
use image::imageops::{overlay, FilterType};
use image::{AnimationDecoder, ImageDecoder, RgbaImage};
use wow_blp::convert::{image_to_blp, Blp2Format, BlpTarget, DxtAlgorithm};
use wow_blp::encode::save_blp;

const SIZE: u32 = 256;

fn main() {
    if let Err(e) = run() {
        eprintln!("gif2blp error: {e}");
        std::process::exit(1);
    }
}

fn run() -> Result<(), Box<dyn std::error::Error>> {
    let base = std::env::args()
        .nth(1)
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("."));
    let raw_dir = base.join("assets").join("raw_gifs");
    let gifs_dir = base.join("assets").join("gifs");
    let manifest = base.join("GigaKloce_Emotes.lua");

    if !raw_dir.is_dir() {
        return Err(format!("raw_gifs folder not found: {}", raw_dir.display()).into());
    }

    // collect *.gif + wideo (mp4/mov/webm/mkv/avi/m4v -> przez ffmpeg)
    fn is_video(ext: &str) -> bool {
        matches!(ext.to_ascii_lowercase().as_str(), "mp4" | "mov" | "webm" | "mkv" | "avi" | "m4v")
    }
    let mut srcs: Vec<PathBuf> = fs::read_dir(&raw_dir)?
        .filter_map(|e| e.ok().map(|e| e.path()))
        .filter(|p| {
            p.extension().and_then(|x| x.to_str()).map(|x| x.eq_ignore_ascii_case("gif") || is_video(x)).unwrap_or(false)
        })
        .collect();
    srcs.sort();
    if srcs.is_empty() {
        return Err(format!("no .gif / video files in {}", raw_dir.display()).into());
    }

    println!("converting {} source(s) from {}:", srcs.len(), raw_dir.display());
    let mut results: Vec<(String, usize, i64)> = Vec::new();
    for src in &srcs {
        let stem = src
            .file_stem()
            .and_then(|s| s.to_str())
            .ok_or("bad filename")?;
        let name = stem.to_lowercase();
        if name.is_empty() || !name.chars().all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '-') {
            return Err(format!(
                "invalid emote name '{name}' (from {}); use only a-z 0-9 _ -",
                src.display()
            )
            .into());
        }
        let out = gifs_dir.join(&name);
        let ext = src.extension().and_then(|x| x.to_str()).unwrap_or("");
        let (frames, fps) = if is_video(ext) {
            process_video(&name, src, &out)?
        } else {
            process_gif(&name, src, &out)?
        };
        println!("  {name:<16} {frames:>3} frames  ~{fps} fps");
        results.push((name, frames, fps));
    }

    // overwrite the manifest (sorted, stable)
    results.sort_by(|a, b| a.0.cmp(&b.0));
    let mut s = String::new();
    s.push_str("local _, GK = ...\r\n");
    s.push_str("-- ============================\r\n");
    s.push_str("-- AUTO-GENEROWANE przez tools/gif2blp (z assets/raw_gifs/*.gif). NIE EDYTUJ RECZNIE.\r\n");
    s.push_str("-- Caly plik jest nadpisywany przy kazdej konwersji.\r\n");
    s.push_str("-- ============================\r\n");
    s.push_str("GK.EMOTES = {\r\n");
    for (name, frames, fps) in &results {
        s.push_str(&format!(
            "    [\"{name}\"] = {{ frames = {frames}, fps = {fps} }},\r\n"
        ));
    }
    s.push_str("}\r\n");
    fs::write(&manifest, s)?;

    println!(
        "\nwrote {} emote(s) -> {}",
        results.len(),
        manifest.display()
    );
    Ok(())
}

fn process_gif(
    name: &str,
    gif_path: &Path,
    out_dir: &Path,
) -> Result<(usize, i64), Box<dyn std::error::Error>> {
    // fresh output dir (drop stale frames from a previous, longer gif)
    let _ = fs::remove_dir_all(out_dir);
    fs::create_dir_all(out_dir)?;

    let file = fs::File::open(gif_path)?;
    let decoder = GifDecoder::new(std::io::BufReader::new(file))?;
    let (gw, gh) = decoder.dimensions(); // logical screen size (for compositing)
    let frames = decoder.into_frames().collect_frames()?;
    let n = frames.len();
    if n == 0 {
        return Err(format!("{}: no frames", gif_path.display()).into());
    }

    // Coalesce: accumulate delta frames onto a persistent canvas -> full frames (no green/transparent holes).
    let mut canvas = RgbaImage::new(gw, gh);
    let mut total_ms: f64 = 0.0;
    for (i, frame) in frames.iter().enumerate() {
        let (num, den) = frame.delay().numer_denom_ms();
        total_ms += if den == 0 { 0.0 } else { num as f64 / den as f64 };

        overlay(&mut canvas, frame.buffer(), frame.left() as i64, frame.top() as i64);

        let img = image::DynamicImage::ImageRgba8(canvas.clone())
            .resize_exact(SIZE, SIZE, FilterType::Lanczos3);

        let blp = image_to_blp(
            img,
            true, // mipmaps
            BlpTarget::Blp2(Blp2Format::Dxt5 {
                has_alpha: true,
                compress_algorithm: DxtAlgorithm::ClusterFit,
            }),
            FilterType::Lanczos3,
        )?;
        // name matches Lua %02d (min 2 digits; i>=100 -> "100")
        save_blp(&blp, &out_dir.join(format!("{}_{:02}.blp", name, i)))?;
    }

    let fps = if total_ms > 0.0 {
        (n as f64) / (total_ms / 1000.0)
    } else {
        10.0
    };
    Ok((n, (fps.round() as i64).max(1)))
}

// Znajdz ffmpeg BEZ ruszania PATH: env GIF2BLP_FFMPEG -> obok naszego .exe -> biezacy folder -> PATH.
fn ffmpeg_bin() -> PathBuf {
    let exe_name = if cfg!(windows) { "ffmpeg.exe" } else { "ffmpeg" };
    if let Ok(p) = std::env::var("GIF2BLP_FFMPEG") {
        if !p.is_empty() {
            return PathBuf::from(p);
        }
    }
    if let Ok(exe) = std::env::current_exe() {
        if let Some(dir) = exe.parent() {
            let c = dir.join(exe_name);
            if c.exists() {
                return c;
            }
        }
    }
    let cwd = PathBuf::from(exe_name);
    if cwd.exists() {
        return cwd;
    }
    PathBuf::from("ffmpeg") // ostatecznie z PATH
}

// Wideo (mp4/...): ffmpeg rozbija na klatki @12 fps, 256x256, potem encode do BLP.
const VIDEO_FPS: i64 = 12;
fn process_video(
    name: &str,
    path: &Path,
    out_dir: &Path,
) -> Result<(usize, i64), Box<dyn std::error::Error>> {
    let _ = fs::remove_dir_all(out_dir);
    fs::create_dir_all(out_dir)?;

    // ekstrakcja klatek do tymczasowych PNG (__frame_0001.png ...)
    let pat = out_dir.join("__frame_%04d.png");
    let ff = ffmpeg_bin();
    let status = std::process::Command::new(&ff)
        .args(["-hide_banner", "-loglevel", "error", "-y", "-i"])
        .arg(path)
        .args(["-vf", &format!("fps={VIDEO_FPS},scale=256:256:flags=lanczos")])
        .arg(&pat)
        .status()
        .map_err(|e| format!(
            "ffmpeg not found ({}): {e}. Put ffmpeg.exe next to gif2blp.exe (or set GIF2BLP_FFMPEG)",
            ff.display()
        ))?;
    if !status.success() {
        return Err(format!("ffmpeg failed for {}", path.display()).into());
    }

    let mut pngs: Vec<PathBuf> = fs::read_dir(out_dir)?
        .filter_map(|e| e.ok().map(|e| e.path()))
        .filter(|p| {
            p.file_name()
                .and_then(|s| s.to_str())
                .map(|s| s.starts_with("__frame_") && s.ends_with(".png"))
                .unwrap_or(false)
        })
        .collect();
    pngs.sort();
    if pngs.is_empty() {
        return Err(format!("{}: ffmpeg produced no frames", path.display()).into());
    }

    for (i, png) in pngs.iter().enumerate() {
        let img = image::open(png)?.resize_exact(SIZE, SIZE, FilterType::Lanczos3);
        let blp = image_to_blp(
            img,
            true,
            BlpTarget::Blp2(Blp2Format::Dxt5 {
                has_alpha: true,
                compress_algorithm: DxtAlgorithm::ClusterFit,
            }),
            FilterType::Lanczos3,
        )?;
        save_blp(&blp, &out_dir.join(format!("{}_{:02}.blp", name, i)))?;
    }
    for png in &pngs {
        let _ = fs::remove_file(png);
    }
    Ok((pngs.len(), VIDEO_FPS))
}
