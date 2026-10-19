/**
 * Minimal, defensive ISO BMFF timing reader for fragmented MP4.
 * Reads mdhd timescales, tfhd defaults, tfdt decode starts, and trun sample
 * durations/composition offsets. It never mutates incoming media bytes.
 * Unsupported constructs fail closed rather than inventing timestamps.
 */
export interface TrackTiming {
  trackId: number;
  timescale: number;
  firstDecodeSeconds: number;
  firstPresentationSeconds: number;
  endPresentationSeconds: number;
  samples: number;
}
interface Box { type: string; start: number; payload: number; end: number }
const maxBoxes = 100000;

function boxes(data: Buffer, start: number, end: number): Box[] {
  const found: Box[] = [];
  for (let at = start; at < end;) {
    if (end - at < 8) throw new Error("Truncated MP4 box");
    const size32 = data.readUInt32BE(at);
    const type = data.toString("ascii", at + 4, at + 8);
    let size = size32;
    let header = 8;
    if (size32 === 1) {
      if (end - at < 16) throw new Error("Truncated large MP4 box");
      const big = data.readBigUInt64BE(at + 8);
      if (big > BigInt(Number.MAX_SAFE_INTEGER)) throw new Error("Oversized MP4 box");
      size = Number(big);
      header = 16;
    } else if (size32 === 0) {
      size = end - at;
    }
    if (size < header || size > end - at) throw new Error("Invalid MP4 box size");
    found.push({ type, start: at, payload: at + header, end: at + size });
    if (found.length > maxBoxes) throw new Error("Too many MP4 boxes");
    at += size;
  }
  return found;
}
function child(data: Buffer, parent: Box, type: string): Box | undefined {
  return boxes(data, parent.payload, parent.end).find((box) => box.type === type);
}
function full(data: Buffer, box: Box): { version: number; flags: number; offset: number } {
  if (box.end - box.payload < 4) throw new Error("Truncated full box");
  return { version: data.readUInt8(box.payload), flags: data.readUIntBE(box.payload + 1, 3), offset: box.payload + 4 };
}
function u32(data: Buffer, offset: number, end: number): number {
  if (offset + 4 > end) throw new Error("Truncated MP4 field");
  return data.readUInt32BE(offset);
}
function u64(data: Buffer, offset: number, end: number): bigint {
  if (offset + 8 > end) throw new Error("Truncated MP4 field");
  return data.readBigUInt64BE(offset);
}
function idAndScale(data: Buffer, trak: Box): [number, number] {
  const tkhd = child(data, trak, "tkhd");
  const mdia = child(data, trak, "mdia");
  const mdhd = mdia && child(data, mdia, "mdhd");
  if (!tkhd || !mdhd) throw new Error("Missing track headers");
  const t = full(data, tkhd);
  const m = full(data, mdhd);
  if (t.version > 1 || m.version > 1) throw new Error("Unsupported track header version");
  const trackId = u32(data, t.offset + (t.version === 1 ? 16 : 8), tkhd.end);
  const scale = u32(data, m.offset + (m.version === 1 ? 16 : 8), mdhd.end);
  if (!trackId || !scale) throw new Error("Invalid track id or timescale");
  return [trackId, scale];
}
export function readFragmentTimings(data: Buffer): TrackTiming[] {
  if (data.length > 64 * 1024 * 1024) throw new Error("MP4 timing input too large");
  const top = boxes(data, 0, data.length);
  const moov = top.find((box) => box.type === "moov");
  if (!moov) throw new Error("Missing moov initialization box");
  const scales = new Map<number, number>();
  for (const trak of boxes(data, moov.payload, moov.end).filter((b) => b.type === "trak")) {
    const [id, scale] = idAndScale(data, trak);
    if (scales.has(id)) throw new Error("Duplicate track id");
    scales.set(id, scale);
  }
  if (!scales.size) throw new Error("No media tracks");
  // A trun can omit sample durations, relying on tfhd or mvex/trex defaults.
  const trexDefaults = new Map<number, number>();
  const mvex = child(data, moov, "mvex");
  if (mvex) {
    for (const trex of boxes(data, mvex.payload, mvex.end).filter((b) => b.type === "trex")) {
      const header = full(data, trex);
      if (header.version !== 0) throw new Error("Unsupported trex version");
      const trackId = u32(data, header.offset, trex.end);
      const duration = u32(data, header.offset + 8, trex.end);
      if (!scales.has(trackId) || trexDefaults.has(trackId)) throw new Error("Invalid trex track");
      trexDefaults.set(trackId, duration);
    }
  }
  const results = new Map<number, TrackTiming>();
  for (const moof of top.filter((box) => box.type === "moof")) {
    for (const traf of boxes(data, moof.payload, moof.end).filter((b) => b.type === "traf")) {
      const tfhd = child(data, traf, "tfhd");
      const tfdt = child(data, traf, "tfdt");
      if (!tfhd || !tfdt) throw new Error("Missing fragment timing boxes");
      const h = full(data, tfhd);
      const d = full(data, tfdt);
      let pos = h.offset;
      const trackId = u32(data, pos, tfhd.end); pos += 4;
      const scale = scales.get(trackId);
      if (!scale) throw new Error("Unknown fragment track");
      if (h.flags & 0x000001) pos += 8;
      if (h.flags & 0x000002) pos += 4;
      let defaultDuration: number | undefined;
      if (h.flags & 0x000008) {
        defaultDuration = u32(data, pos, tfhd.end);
        pos += 4;
      }
      let decode = d.version === 1 ? u64(data, d.offset, tfdt.end) : BigInt(u32(data, d.offset, tfdt.end));
      if (d.version !== 0 && d.version !== 1) throw new Error("Unsupported tfdt version");
      const initialDecode = decode;
      if (h.flags & 0x000010) pos += 4;
      if (h.flags & 0x000020) pos += 4;
      if (pos > tfhd.end) throw new Error("Truncated tfhd");
      if ((h.flags & 0x000001) && h.offset + 12 > tfhd.end)
        throw new Error("Truncated tfhd base data offset");
      let firstPts: number | undefined;
      let endPts: number | undefined;
      let count = 0;
      for (const trun of boxes(data, traf.payload, traf.end).filter((b) => b.type === "trun")) {
        const r = full(data, trun);
        if (r.version !== 0 && r.version !== 1) throw new Error("Unsupported trun version");
        let p = r.offset;
        const samples = u32(data, p, trun.end); p += 4;
        if (samples > 1000000) throw new Error("Too many samples");
        if (r.flags & 0x000001) p += 4;
        if (r.flags & 0x000004) p += 4;
        for (let i = 0; i < samples; i++) {
          const duration = r.flags & 0x000100 ? u32(data, p, trun.end) : (defaultDuration ?? trexDefaults.get(trackId));
          if (r.flags & 0x000100) p += 4;
          if (duration === undefined || duration === 0) throw new Error("Missing sample duration");
          if (r.flags & 0x000200) p += 4;
          if (r.flags & 0x000400) p += 4;
          let cto = 0;
          if (r.flags & 0x000800) {
            if (p + 4 > trun.end) throw new Error("Truncated composition offset");
            cto = r.version === 1 ? data.readInt32BE(p) : data.readUInt32BE(p); p += 4;
          }
          if (p > trun.end) throw new Error("Truncated sample");
          const pts = Number(decode) + cto;
          firstPts = Math.min(firstPts ?? pts, pts);
          endPts = Math.max(endPts ?? (pts + duration), pts + duration);
          decode += BigInt(duration);
          count++;
        }
      }
      if (!count || firstPts === undefined || endPts === undefined) throw new Error("Empty fragment");
      const before = results.get(trackId);
      results.set(trackId, {
        trackId, timescale: scale,
        firstDecodeSeconds: Math.min(before?.firstDecodeSeconds ?? Infinity, Number(initialDecode) / scale),
        firstPresentationSeconds: Math.min(before?.firstPresentationSeconds ?? Infinity, firstPts / scale),
        endPresentationSeconds: Math.max(before?.endPresentationSeconds ?? -Infinity, endPts / scale),
        samples: (before?.samples ?? 0) + count,
      });
    }
  }
  if (!results.size) throw new Error("No movie fragments");
  return [...results.values()].sort((a, b) => a.trackId - b.trackId);
}
