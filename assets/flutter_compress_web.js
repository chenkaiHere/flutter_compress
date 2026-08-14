/*
 * flutter_compress — Web engine (WebCodecs + mp4box.js demux + mp4-muxer mux).
 *
 * Pipeline: fetch blob -> mp4box demux -> VideoDecoder -> (canvas rescale) ->
 * VideoEncoder(target bitrate) -> mp4-muxer -> Blob(mp4) -> object URL.
 *
 * v1 transcodes VIDEO only (audio is dropped) — a documented limitation;
 * audio passthrough/re-encode is a follow-up. H.264 output (broadest support).
 *
 * Depends on globals: MP4Box, DataStream (from mp4box.all.min.js), Mp4Muxer.
 */
(function () {
  'use strict';
  // Idempotent: this file is injected by two independent lazy loaders (video and
  // image). Re-running the IIFE would rebuild the namespace and wipe OUTPUT_URLS,
  // silently turning revoke()/revokeAll() into no-ops.
  if (window.flutterCompressWeb) return;
  const NS = {};
  window.flutterCompressWeb = NS;

  const cancelled = new Set();
  /** Ids of runs currently in flight, so `cancelAll` has something to target. */
  const active = new Set();
  NS.cancel = function (id) { if (id) cancelled.add(id); };
  /** Cancel every in-flight run (backs Dart's `cancel()` with no id). */
  NS.cancelAll = function () { for (const id of active) cancelled.add(id); };

  /** Every output object URL we created, so `revokeAll` can free them. */
  const OUTPUT_URLS = new Set();
  function trackUrl(url) { OUTPUT_URLS.add(url); return url; }

  /** Upper bound on waiting for mp4box to deliver every sample. */
  const DEMUX_TIMEOUT_MS = 10000;

  /** Release a WebCodecs encoder/decoder without masking the real error. */
  function closeQuietly(codec) {
    try { if (codec && codec.state !== 'closed') codec.close(); } catch (_) {}
  }

  NS.isSupported = function () {
    return typeof window.VideoEncoder === 'function' &&
      typeof window.VideoDecoder === 'function' &&
      typeof MP4Box !== 'undefined' && typeof Mp4Muxer !== 'undefined';
  };

  async function fetchBuffer(url) {
    const res = await fetch(url);
    if (!res.ok) throw new Error('fetch failed: ' + res.status);
    return await res.arrayBuffer();
  }

  function avcDescription(file, trackId) {
    const trak = file.getTrackById(trackId);
    for (const entry of trak.mdia.minf.stbl.stsd.entries) {
      const box = entry.avcC || entry.hvcC || entry.vpcC || entry.av1C;
      if (box) {
        const stream = new DataStream(undefined, 0, DataStream.BIG_ENDIAN);
        box.write(stream);
        return new Uint8Array(stream.buffer, 8); // strip box header
      }
    }
    return undefined;
  }

  // ---- info --------------------------------------------------------------

  NS.getInfo = function (url) {
    return new Promise(async (resolve, reject) => {
      try {
        const buf = await fetchBuffer(url);
        const sizeBytes = buf.byteLength;
        const file = MP4Box.createFile();
        file.onError = (e) => reject(new Error('mp4box: ' + e));
        file.onReady = (info) => {
          const v = info.videoTracks && info.videoTracks[0];
          if (!v) { reject(new Error('no video track')); return; }
          const durationMs = (info.duration / info.timescale) * 1000;
          const durSec = Math.max(durationMs / 1000, 0.001);
          const fps = v.nb_samples / Math.max(v.movie_duration / v.movie_timescale, 0.001);
          resolve({
            width: v.video ? v.video.width : v.track_width,
            height: v.video ? v.video.height : v.track_height,
            durationMs: Math.round(durationMs),
            sizeBytes: sizeBytes,
            bitrateKbps: Math.round((sizeBytes * 8) / durSec / 1000),
            frameRate: isFinite(fps) ? fps : null,
            codec: v.codec || null,
            rotation: 0,
          });
        };
        // mp4box needs a fileStart offset on the buffer itself; annotate the one
        // we fetched rather than slicing a copy, which would double peak memory.
        buf.fileStart = 0;
        file.appendBuffer(buf);
        file.flush();
      } catch (e) { reject(e); }
    });
  };

  // ---- thumbnail (simple <video> + canvas) -------------------------------

  NS.thumbnail = function (url, positionMs, quality, maxWidth) {
    return new Promise((resolve, reject) => {
      const v = document.createElement('video');
      v.muted = true;
      v.preload = 'auto';
      v.src = url;
      v.onloadedmetadata = () => {
        v.currentTime = Math.min((positionMs || 0) / 1000, (v.duration || 0.1) - 0.01);
      };
      v.onseeked = () => {
        try {
          const scale = (maxWidth && v.videoWidth > maxWidth) ? maxWidth / v.videoWidth : 1;
          const cw = Math.max(1, Math.round(v.videoWidth * scale));
          const ch = Math.max(1, Math.round(v.videoHeight * scale));
          const c = document.createElement('canvas');
          c.width = cw; c.height = ch;
          c.getContext('2d').drawImage(v, 0, 0, cw, ch);
          resolve(c.toDataURL('image/jpeg', (quality || 80) / 100));
        } catch (e) { reject(e); }
      };
      v.onerror = () => reject(new Error('video load error'));
    });
  };

  // ---- compress ----------------------------------------------------------

  // cfg: { id, targetWidth, targetHeight, videoBitrateBps, frameRate,
  //        trimStartMs, trimEndMs, keepOriginalIfLarger, originalSizeBytes }
  // onProgress: (fraction:number, outBytes:number) => void
  NS.compress = async function (url, cfg, onProgress) {
    if (!NS.isSupported()) throw new Error('WebCodecs not supported in this browser');
    const id = cfg.id;
    cancelled.delete(id);
    active.add(id);

    const buf = await fetchBuffer(url);
    const file = MP4Box.createFile();

    const ready = new Promise((resolve, reject) => {
      file.onError = (e) => reject(new Error('mp4box: ' + e));
      file.onReady = (info) => resolve(info);
    });
    // Annotate the fetched buffer instead of slicing a copy (see getInfo).
    buf.fileStart = 0;
    file.appendBuffer(buf);
    file.flush();
    const info = await ready;
    const vTrack = info.videoTracks[0];
    if (!vTrack) throw new Error('no video track');

    const timescale = vTrack.timescale;
    const totalSamples = vTrack.nb_samples;
    const durationMs = Math.round((info.duration / info.timescale) * 1000);
    const tw = cfg.targetWidth, th = cfg.targetHeight;
    const srcW = vTrack.video ? vTrack.video.width : vTrack.track_width;
    const srcH = vTrack.video ? vTrack.video.height : vTrack.track_height;
    const needResize = tw !== srcW || th !== srcH;
    const fps = cfg.frameRate && cfg.frameRate > 0 ? cfg.frameRate : 30;
    // Source facts, reported back verbatim on the skipped path.
    const srcFps = vTrack.nb_samples > 0 && vTrack.movie_duration > 0
      ? vTrack.nb_samples / (vTrack.movie_duration / vTrack.movie_timescale)
      : null;
    const srcHasAudio = (info.audioTracks || []).length > 0;

    // Target-size mode uses constant bitrate so the output actually fills the
    // requested budget; quality mode stays variable (more efficient).
    const bitrateMode = cfg.bitrateMode || 'variable';

    // Pick a supported encoder config: HEVC (H.265) first when requested, with
    // automatic fallback to H.264 where the browser can't encode HEVC — the
    // same policy as the Android/iOS engines.
    let encoderConfig = null, muxerCodec = 'avc', usedCodec = 'h264';
    if (cfg.codec === 'h265') {
      for (const codec of ['hev1.1.6.L93.B0', 'hvc1.1.6.L93.B0']) {
        const c = {
          codec, width: tw, height: th, bitrate: cfg.videoBitrateBps,
          framerate: Math.round(fps), hevc: { format: 'hevc' }, bitrateMode,
        };
        try {
          const sup = await VideoEncoder.isConfigSupported(c);
          if (sup && sup.supported) {
            encoderConfig = c; muxerCodec = 'hevc'; usedCodec = 'h265'; break;
          }
        } catch (_) {}
      }
    }
    if (!encoderConfig) {
      for (const codec of ['avc1.640028', 'avc1.4D0028', 'avc1.42E01E']) {
        const c = {
          codec, width: tw, height: th, bitrate: cfg.videoBitrateBps,
          framerate: Math.round(fps), avc: { format: 'avc' }, bitrateMode,
        };
        try {
          const sup = await VideoEncoder.isConfigSupported(c);
          if (sup && sup.supported) {
            encoderConfig = c; muxerCodec = 'avc'; usedCodec = 'h264'; break;
          }
        } catch (_) {}
      }
    }
    if (!encoderConfig) throw new Error('no supported H.264/H.265 encoder config');

    // Muxer — codec must match what the encoder actually produced.
    const muxer = new Mp4Muxer.Muxer({
      target: new Mp4Muxer.ArrayBufferTarget(),
      video: { codec: muxerCodec, width: tw, height: th },
      fastStart: 'in-memory',
      // Real videos' first frame rarely has DTS/CTS 0 (container offsets);
      // shift all timestamps so the first is zero, as mp4-muxer requires.
      firstTimestampBehavior: 'offset',
    });

    let encodeError = null;
    const encoder = new VideoEncoder({
      output: (chunk, meta) => muxer.addVideoChunk(chunk, meta),
      error: (e) => { encodeError = e; },
    });
    encoder.configure(encoderConfig);

    // Rescale canvas (only if needed)
    let canvas = null, ctx = null;
    if (needResize) {
      canvas = document.createElement('canvas');
      canvas.width = tw; canvas.height = th;
      ctx = canvas.getContext('2d');
    }

    let processed = 0;
    const keyInterval = Math.max(1, Math.round(fps * 2));
    let frameIndex = 0;
    /// Frames the encoder actually accepted — the basis for the real output
    /// duration, so a truncated encode can't be reported as full length.
    let encodedFrames = 0;

    const decoder = new VideoDecoder({
      output: (frame) => {
        if (cancelled.has(id)) { frame.close(); return; }
        let toEncode = frame;
        if (needResize) {
          ctx.drawImage(frame, 0, 0, tw, th);
          toEncode = new VideoFrame(canvas, {
            timestamp: frame.timestamp, duration: frame.duration || undefined,
          });
          frame.close();
        }
        const keyFrame = (frameIndex % keyInterval) === 0;
        frameIndex++;
        encoder.encode(toEncode, { keyFrame });
        toEncode.close();
        encodedFrames++;
        processed++;
        if (onProgress && (processed % 5 === 0)) {
          onProgress(Math.min(processed / totalSamples, 0.99), 0);
        }
      },
      error: (e) => { encodeError = e; },
    });

    const desc = avcDescription(file, vTrack.id);
    decoder.configure({
      codec: vTrack.codec,
      description: desc,
      codedWidth: srcW,
      codedHeight: srcH,
    });

    // Collect samples and feed the decoder.
    let fed = 0;
    const samplesReady = new Promise((resolve, reject) => {
      file.onSamples = (trackId, user, samples) => {
        try {
          for (const s of samples) {
            if (cancelled.has(id)) break;
            decoder.decode(new EncodedVideoChunk({
              type: s.is_sync ? 'key' : 'delta',
              timestamp: (s.cts * 1e6) / timescale,
              duration: (s.duration * 1e6) / timescale,
              data: s.data,
            }));
            fed++;
          }
          if (samples.length && samples[samples.length - 1].number >= totalSamples - 1) {
            resolve();
          }
        } catch (e) { reject(e); }
      };
    });

    try {
      file.setExtractionOptions(vTrack.id, null, { nbSamples: totalSamples });
      file.start();
      // mp4box normally delivers every sample synchronously from start() (the
      // whole file is buffered). Don't assume it: if it ever batches, waiting a
      // single tick would flush the decoder early and silently truncate the
      // output, so poll until every sample is in (bounded).
      await Promise.race([samplesReady, new Promise((r) => setTimeout(r, 0))]);
      const deadline = Date.now() + DEMUX_TIMEOUT_MS;
      while (fed < totalSamples && Date.now() < deadline && !cancelled.has(id)) {
        await new Promise((r) => setTimeout(r, 10));
      }
      // Fail loudly rather than flushing a partial stream: a truncated video that
      // reports success is far worse than an error the caller can retry.
      if (fed < totalSamples && !cancelled.has(id)) {
        throw new Error(
          'demux timed out: fed ' + fed + ' of ' + totalSamples + ' samples');
      }

      await decoder.flush();
      await encoder.flush();
      if (encodeError) throw encodeError;
      if (cancelled.has(id)) { cancelled.delete(id); throw new Error('cancelled'); }

      muxer.finalize();
      const blob = new Blob([muxer.target.buffer], { type: 'video/mp4' });

      if (cfg.keepOriginalIfLarger && cfg.originalSizeBytes > 0 &&
          blob.size >= cfg.originalSizeBytes) {
        return {
          url: url, outputUrl: url, sizeBytes: cfg.originalSizeBytes,
          width: srcW, height: srcH, durationMs,
          // The source is returned untouched, so report *its* codec, not the one
          // we were going to encode with.
          codec: (vTrack.codec || '').startsWith('hev') ? 'h265' : 'h264',
          frameRate: srcFps, hasAudio: srcHasAudio, skipped: true,
        };
      }

      const outUrl = trackUrl(URL.createObjectURL(blob));
      if (onProgress) onProgress(1, blob.size);
      return {
        url: outUrl, outputUrl: outUrl, sizeBytes: blob.size,
        width: tw, height: th,
        // Derived from what was actually encoded, not from the source header.
        durationMs: encodedFrames > 0
          ? Math.round((encodedFrames / Math.max(fps, 1)) * 1000)
          : durationMs,
        codec: usedCodec,
        frameRate: fps,
        // v1 never carries audio through; say so instead of implying otherwise.
        hasAudio: false,
        skipped: false,
      };
    } finally {
      // WebCodecs codecs hold hardware/GPU resources; leaking a pair per run
      // makes the browser refuse to create encoders after a few compressions.
      closeQuietly(decoder);
      closeQuietly(encoder);
      try { file.flush(); } catch (_) {}
      // Don't let ids pile up: cancel() adds unconditionally, including for jobs
      // that had already finished.
      cancelled.delete(id);
      active.delete(id);
    }
  };

  // ---- images (canvas + toBlob; no WebCodecs/MP4 needed) -----------------

  NS.getImageInfo = async function (url) {
    const blob = await (await fetch(url)).blob();
    const bmp = await createImageBitmap(blob);
    const info = {
      path: url, width: bmp.width, height: bmp.height,
      sizeBytes: blob.size,
      format: blob.type ? blob.type.replace('image/', '') : null,
    };
    bmp.close();
    return info;
  };

  // cfg: { format, quality, targetSizeKB, maxWidth, maxHeight, lossless }
  NS.compressImage = async function (url, cfg) {
    const blob = await (await fetch(url)).blob();
    const bmp = await createImageBitmap(blob);

    // A null/absent format keeps the source's format. Canvas can't encode HEIC
    // → JPEG; unknowns → JPEG. Otherwise the requested format is kept.
    let fmt = cfg.format || (blob.type ? blob.type.replace('image/', '') : 'jpeg');
    if (fmt !== 'png' && fmt !== 'webp') fmt = 'jpeg';  // jpeg/jpg/heic/unknown
    const mime = fmt === 'png' ? 'image/png' : fmt === 'webp' ? 'image/webp' : 'image/jpeg';
    const lossy = fmt !== 'png';

    function fitDims(w, h) {
      let fw = w, fh = h;
      if (cfg.maxWidth && fw > cfg.maxWidth) { const s = cfg.maxWidth / fw; fw *= s; fh *= s; }
      if (cfg.maxHeight && fh > cfg.maxHeight) { const s = cfg.maxHeight / fh; fw *= s; fh *= s; }
      return [Math.max(1, Math.round(fw)), Math.max(1, Math.round(fh))];
    }
    function draw(w, h) {
      const c = document.createElement('canvas');
      c.width = w; c.height = h;
      c.getContext('2d').drawImage(bmp, 0, 0, w, h);
      return c;
    }
    function toBlob(canvas, q) {
      return new Promise((res) => canvas.toBlob((b) => res(b), mime, lossy ? q : undefined));
    }
    // Lossless → max quality (1.0); PNG ignores it and stays truly lossless.
    const baseQ = cfg.lossless ? 1 : (cfg.quality || 85) / 100;
    /**
     * Highest-quality blob that fits `target`, plus the quality it used.
     * Tries the ceiling first so an image that already fits costs one encode
     * instead of a full binary search; `minQ` lets a downscale round start from
     * the quality the previous round reached.
     */
    async function fit(canvas, target, minQ) {
      if (!lossy || !target) return { blob: await toBlob(canvas, baseQ), quality: 100 };
      const ceiling = await toBlob(canvas, 1);
      if (ceiling && ceiling.size <= target) return { blob: ceiling, quality: 100 };
      let lo = minQ, hi = 99, best = null, bestQ = minQ;
      while (lo <= hi) {
        const q = Math.floor((lo + hi) / 2);
        const b = await toBlob(canvas, q / 100);
        if (b && b.size <= target) { best = b; bestQ = q; lo = q + 1; } else { hi = q - 1; }
      }
      return { blob: best || await toBlob(canvas, minQ / 100), quality: bestQ };
    }

    // A target size can't be honored losslessly — ignore it in that case.
    const target = cfg.lossless || !cfg.targetSizeKB ? null : cfg.targetSizeKB * 1024;
    try {
      let [w, h] = fitDims(bmp.width, bmp.height);
      let canvas = draw(w, h);
      let fitted = await fit(canvas, target, 1);
      let tries = 0;
      while (target && fitted.blob && fitted.blob.size > target && tries < 5 &&
             canvas.width > 32) {
        w = Math.round(canvas.width * 0.75); h = Math.round(canvas.height * 0.75);
        canvas = draw(w, h);
        // A smaller image fits at least the quality the last round reached.
        fitted = await fit(canvas, target, fitted.quality);
        tries++;
      }
      const out = fitted.blob;
      if (!out) throw new Error('image encode failed');

      // Re-encoding can end up larger than the source (already-compressed input,
      // or lossless). If so, hand back the untouched original.
      const keepOriginal = cfg.keepOriginalIfLarger !== false;
      if (keepOriginal && out.size >= blob.size) {
        return {
          outputPath: url,
          originalSizeBytes: blob.size,
          compressedSizeBytes: blob.size,
          width: bmp.width, height: bmp.height,
          format: blob.type ? blob.type.replace('image/', '') : fmt,
          skipped: true,
        };
      }
      // toBlob silently falls back to PNG when the browser can't encode the
      // requested type (WebP on older Safari), so report what was written.
      const actual = out.type ? out.type.replace('image/', '') : fmt;
      return {
        outputPath: trackUrl(URL.createObjectURL(out)),
        originalSizeBytes: blob.size,
        compressedSizeBytes: out.size,
        width: canvas.width, height: canvas.height, format: actual, skipped: false,
      };
    } finally {
      bmp.close();
    }
  };

  // ---- download / cleanup ------------------------------------------------

  const EXT_BY_MIME = {
    'video/mp4': 'mp4', 'video/quicktime': 'mov', 'video/webm': 'webm',
    'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp',
    'image/heic': 'heic', 'image/heif': 'heic',
  };

  // Derive a sensible name from the blob's own MIME type. Defaulting to .mp4
  // would label a compressed JPEG as a movie.
  async function defaultName(url) {
    let ext = 'bin';
    try {
      const type = (await (await fetch(url)).blob()).type;
      ext = EXT_BY_MIME[type] || (type.split('/')[1] || 'bin');
    } catch (_) {}
    return 'compressed_' + Date.now() + '.' + ext;
  }

  NS.download = async function (url, fileName) {
    const name = fileName || (await defaultName(url));
    const a = document.createElement('a');
    a.href = url;
    a.download = name;
    document.body.appendChild(a);
    a.click();
    a.remove();
    return name;
  };

  NS.revoke = function (url) {
    // Only revoke URLs we minted. When a result is `skipped` its outputUrl *is*
    // the caller's input URL, and revoking that would tear down a blob we don't
    // own — the caller would lose its own source.
    if (!OUTPUT_URLS.delete(url)) return;
    try { URL.revokeObjectURL(url); } catch (_) {}
  };

  /** Revoke every output this engine created (backs Dart's `clearCache`). */
  NS.revokeAll = function () {
    for (const url of OUTPUT_URLS) {
      try { URL.revokeObjectURL(url); } catch (_) {}
    }
    OUTPUT_URLS.clear();
  };
})();
