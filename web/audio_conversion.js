// Same-origin, lazy-loaded, single-thread FFmpeg.wasm. No upload or CDN requests.
// Keep this classic script before Flutter bootstrap so Dart can find the bridge.
(() => {
  "use strict";
  const vendor = new URL("vendor/ffmpeg/", document.currentScript.src);
  const allowed = new Set(["wav", "m4a", "aac", "ogg", "opus", "flac", "amr", "3gp"]);
  const maxSource = 50 * 1024 * 1024;
  const maxStored = 10 * 1024 * 1024;
  let busy = false;

  async function bounded(promise, milliseconds, message) {
    let timer;
    try {
      return await Promise.race([
        promise,
        new Promise((_, reject) => {
          timer = setTimeout(() => reject(new Error(message)), milliseconds);
        })
      ]);
    } finally {
      clearTimeout(timer);
    }
  }

  globalThis.kontriosConvertAudio = async (bytes, extension, maxOutputBytes) => {
    if (busy) throw new Error("Another recording is being converted.");
    if (!allowed.has(extension) || !(bytes instanceof Uint8Array) ||
        bytes.byteLength === 0 || bytes.byteLength > maxSource ||
        !Number.isInteger(maxOutputBytes) || maxOutputBytes <= 0 ||
        maxOutputBytes > maxStored) {
      throw new Error("Unsupported audio input or size.");
    }
    busy = true;
    let ffmpeg;
    try {
      let FFmpeg;
      try {
        ({ FFmpeg } = await bounded(
          import(new URL("wrapper/index.js", vendor).href),
          30000, "Browser audio engine module timed out."));
      } catch (error) {
        throw new Error("Browser audio engine is missing. Run scripts/setup-web-audio.ps1 and restart HQ.", { cause: error });
      }
      ffmpeg = new FFmpeg();
      await bounded(ffmpeg.load({
        coreURL: new URL("core/ffmpeg-core.js", vendor).href,
        wasmURL: new URL("core/ffmpeg-core.wasm", vendor).href
      }), 90000, "Browser audio engine failed to load. Check the local WASM files.");
      const input = "input." + extension;
      const output = "output.mp3";
      // writeFile transfers the ArrayBuffer to the worker. Copy it so the
      // original Dart Uint8List is never detached or mutated.
      await bounded(ffmpeg.writeFile(input, new Uint8Array(bytes)), 15000,
        "Could not stage the audio recording.");
      const exitCode = await bounded(ffmpeg.exec([
        "-hide_banner", "-loglevel", "error", "-nostdin", "-xerror",
        "-protocol_whitelist", "file",
        "-format_whitelist", "wav,mov,mp4,m4a,3gp,3g2,mj2,aac,ogg,flac,amr,mp3",
        "-i", input, "-map", "0:a:0", "-vn", "-sn", "-dn",
        "-map_metadata", "-1", "-map_chapters", "-1",
        "-ac", "1", "-ar", "44100", "-c:a", "libmp3lame", "-b:a", "96k",
        "-fs", String(maxOutputBytes + 65536), "-f", "mp3", "-y", output
      ], 60000), 75000, "Audio conversion timed out. Try a shorter recording.");
      if (exitCode !== 0) throw new Error("Invalid recording or unsupported audio codec.");
      const result = await bounded(ffmpeg.readFile(output), 15000, "Could not read MP3 output.");
      if (!(result instanceof Uint8Array) || !result.byteLength ||
          result.byteLength > maxOutputBytes) {
        throw new Error("MP3 output is empty or exceeds 10 MB.");
      }
      return result;
    } finally {
      // Worker termination also discards its in-memory filesystem.
      try { if (ffmpeg) ffmpeg.terminate(); } finally { busy = false; }
    }
  };
})();
