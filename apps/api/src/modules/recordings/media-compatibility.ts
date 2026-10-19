import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

export interface MediaStreamSignature {
  codec_type: string;
  codec_name: string;
  profile?: string;
  level?: number;
  width?: number;
  height?: number;
  pix_fmt?: string;
  sample_rate?: string;
  channels?: number;
  extradata_hash?: string;
}

export interface MediaSignature {
  streams: MediaStreamSignature[];
}

/**
 * Use stream configuration, not just codec names: even two H.264 recordings
 * may have incompatible AVC decoder configuration records (SPS/PPS).
 */
export function compatibleMedia(
  previous: MediaSignature,
  next: MediaSignature,
): { compatible: boolean; reason?: string } {
  const relevant = (media: MediaSignature) =>
    media.streams.filter(
      (stream) =>
        stream.codec_type === "video" || stream.codec_type === "audio",
    );
  const a = relevant(previous);
  const b = relevant(next);
  if (a.length === 0 || a.length !== b.length)
    return { compatible: false, reason: "Stream layout differs" };

  const fields: (keyof MediaStreamSignature)[] = [
    "codec_type",
    "codec_name",
    "profile",
    "level",
    "width",
    "height",
    "pix_fmt",
    "sample_rate",
    "channels",
    "extradata_hash",
  ];
  for (let i = 0; i < a.length; i++) {
    const first = a[i];
    const second = b[i];
    if (!first || !second)
      return { compatible: false, reason: "Stream layout differs" };
    // Missing decoder configuration must never be treated as compatible.
    if (!first.extradata_hash || !second.extradata_hash)
      return { compatible: false, reason: "Decoder configuration unavailable" };
    for (const field of fields) {
      if (first[field] !== second[field])
        return {
          compatible: false,
          reason: `Stream ${String(i)}: ${field} differs`,
        };
    }
  }
  return { compatible: true };
}

/** Probe finalized media with a bounded subprocess; no transcoding involved. */
export async function probeMedia(file: string): Promise<MediaSignature> {
  const { stdout } = await execFileAsync(
    "ffprobe",
    [
      "-v",
      "error",
      "-show_streams",
      "-show_data_hash",
      "sha256",
      "-of",
      "json",
      file,
    ],
    { timeout: 10000, maxBuffer: 1024 * 1024 },
  );
  const parsed: unknown = JSON.parse(stdout);
  if (
    !parsed ||
    typeof parsed !== "object" ||
    !("streams" in parsed) ||
    !Array.isArray(parsed.streams)
  )
    throw new Error("Invalid ffprobe output");
  return { streams: parsed.streams as MediaStreamSignature[] };
}
