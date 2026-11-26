import { describe, expect, it } from "vitest";
import { compatibleMedia, type MediaSignature } from "./media-compatibility.js";

const video = {
  codec_type: "video",
  codec_name: "h264",
  profile: "High",
  level: 40,
  width: 1920,
  height: 1080,
  pix_fmt: "yuv420p",
  extradata_hash: "SHA256:abc123",
};

const audio = {
  codec_type: "audio",
  codec_name: "aac",
  profile: "LC",
  sample_rate: "48000",
  channels: 2,
  extradata_hash: "SHA256:audio123",
};

const signature = (streams: MediaSignature["streams"]): MediaSignature => ({
  streams,
});

describe("MSE recording codec compatibility", () => {
  it("accepts identical video and audio decoder configurations", () => {
    expect(
      compatibleMedia(
        signature([video, audio]),
        signature([{ ...video }, { ...audio }]),
      ),
    ).toEqual({
      compatible: true,
    });
  });

  it("rejects different H.264 profiles", () => {
    expect(
      compatibleMedia(
        signature([video]),
        signature([{ ...video, profile: "Baseline" }]),
      ).compatible,
    ).toBe(false);
  });

  it("rejects changed SPS/PPS even when the named codec is identical", () => {
    expect(
      compatibleMedia(
        signature([video]),
        signature([{ ...video, extradata_hash: "SHA256:different" }]),
      ).compatible,
    ).toBe(false);
  });

  it("rejects missing decoder configuration", () => {
    expect(
      compatibleMedia(
        signature([video]),
        signature([{ ...video, extradata_hash: "" }]),
      ).compatible,
    ).toBe(false);
  });

  it("rejects video-only to video-plus-audio transitions", () => {
    expect(
      compatibleMedia(signature([video]), signature([video, audio])).compatible,
    ).toBe(false);
  });

  it("rejects resolution changes", () => {
    expect(
      compatibleMedia(
        signature([video]),
        signature([{ ...video, width: 1280 }]),
      ).compatible,
    ).toBe(false);
  });
});
