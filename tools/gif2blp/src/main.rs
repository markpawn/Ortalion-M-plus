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

    // collect *.gif
    let mut gifs: Vec<PathBuf> = fs::read_dir(&raw_dir)?
        .filter_map(|e| e.ok().map(|e| e.path()))
        .filter(|p| {
            p.extension()
                .map(|x| x.eq_ignore_ascii_case("gif"))
                .unwrap_or(false)
        })
        .collect();
    gifs.sort();
    if gifs.is_empty() {
        return Err(format!("no .gif files in {}", raw_dir.display()).into());
    }

    println!("converting {} gif(s) from {}:", gifs.len(), raw_dir.display());
    let mut results: Vec<(String, usize, i64)> = Vec::new();
    for gif in &gifs {
        let stem = gif
            .file_stem()
            .and_then(|s| s.to_str())
            .ok_or("bad filename")?;
        let name = stem.to_lowercase();
        if name.is_empty() || !name.chars().all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '-') {
            return Err(format!(
                "invalid emote name '{name}' (from {}); use only a-z 0-9 _ -",
                gif.display()
            )
            .into());
        }
        let out = gifs_dir.join(&name);
        let (frames, fps) = process_gif(&name, gif, &out)?;
        println!("  {name:<14} {frames:>3} frames  ~{fps} fps");
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
