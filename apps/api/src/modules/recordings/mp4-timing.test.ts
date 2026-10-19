import { describe, expect, it } from "vitest";
import { readFragmentTimings } from "./mp4-timing.js";

const n = (value: number) => { const b = Buffer.alloc(4); b.writeUInt32BE(value); return b; };
const box = (type: string, ...parts: Buffer[]) => {
  const body = Buffer.concat(parts);
  return Buffer.concat([n(8 + body.length), Buffer.from(type, "ascii"), body]);
};
const full = (type: string, version: number, flags: number, ...parts: Buffer[]) =>
  box(type, Buffer.from([version, (flags >> 16) & 255, (flags >> 8) & 255, flags & 255]), ...parts);
const fixture = (compositionOffset = 0) => {
  const tkhd = full("tkhd", 0, 0, n(0), n(0), n(1));
  const mdhd = full("mdhd", 0, 0, n(0), n(0), n(1000));
  const moov = box("moov", box("trak", tkhd, box("mdia", mdhd)));
  const tfhd = full("tfhd", 0, 0x000008, n(1), n(1000));
  const tfdt = full("tfdt", 0, 0, n(5000));
  const cto = Buffer.alloc(4); cto.writeInt32BE(compositionOffset);
  const trun = full("trun", 1, 0x000800, n(2), cto, Buffer.alloc(4));
  const moof = box("moof", box("traf", tfhd, tfdt, trun));
  return Buffer.concat([moov, moof]);
};
describe("fragmented MP4 timing parser", () => {
  it("reads decode and presentation times in track timescale", () => {
    expect(readFragmentTimings(fixture())).toEqual([{
      trackId: 1, timescale: 1000, firstDecodeSeconds: 5,
      firstPresentationSeconds: 5, endPresentationSeconds: 7, samples: 2,
    }]);
  });
  it("supports negative composition offsets from version 1 trun", () => {
    const result = readFragmentTimings(fixture(-250))[0];
    expect(result?.firstPresentationSeconds).toBe(4.75);
    expect(result?.endPresentationSeconds).toBe(6.75);
  });
  it("rejects truncated boxes", () => {
    expect(() => readFragmentTimings(fixture().subarray(0, -2))).toThrow();
  });
  it("rejects unfragmented buffers", () => {
    expect(() => readFragmentTimings(box("ftyp", Buffer.alloc(4)))).toThrow("Missing moov");
  });
});

describe("track-level trex sample-duration defaults", () => {
  const sample = (defaultDuration: number, withTfhdDefault = false) => {
    const tkhd = full("tkhd", 0, 0, n(0), n(0), n(1));
    const mdhd = full("mdhd", 0, 0, n(0), n(0), n(1000));
    const trex = full("trex", 0, 0, n(1), n(1), n(defaultDuration), n(0), n(0));
    const moov = box("moov", box("trak", tkhd, box("mdia", mdhd)), box("mvex", trex));
    const tfhd = full("tfhd", 0, withTfhdDefault ? 0x000008 : 0, n(1),
      ...(withTfhdDefault ? [n(250)] : []));
    const tfdt = full("tfdt", 0, 0, n(1000));
    const trun = full("trun", 0, 0, n(2));
    return Buffer.concat([moov, box("moof", box("traf", tfhd, tfdt, trun))]);
  };

  it("uses trex default durations when tfhd and trun omit them", () => {
    expect(readFragmentTimings(sample(500))[0]).toMatchObject({
      firstDecodeSeconds: 1, firstPresentationSeconds: 1,
      endPresentationSeconds: 2, samples: 2,
    });
  });

  it("gives tfhd sample durations precedence over trex", () => {
    expect(readFragmentTimings(sample(500, true))[0]?.endPresentationSeconds).toBe(1.5);
  });

  it("rejects an unusable zero default duration", () => {
    expect(() => readFragmentTimings(sample(0))).toThrow("Missing sample duration");
  });
});
