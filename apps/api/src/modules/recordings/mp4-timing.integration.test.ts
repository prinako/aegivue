import { execFileSync, spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { readFragmentTimings } from "./mp4-timing.js";

const ffmpegAvailable =
  spawnSync("ffmpeg", ["-version"], { stdio: "ignore" }).status === 0;
const ffprobeAvailable =
  spawnSync("ffprobe", ["-version"], { stdio: "ignore" }).status === 0;

/** Exercises actual FFmpeg-generated fMP4 (not hand-crafted box fixtures). */
describe.skipIf(!ffmpegAvailable || !ffprobeAvailable)(
  "FFmpeg fragmented MP4 timing integration",
  () => {
    it("agrees with FFprobe packet PTS/DTS and duration for two media fragments", () => {
      const dir = mkdtempSync(join(tmpdir(), "aegivue-fmp4-"));
      try {
        const file = join(dir, "two-fragments.mp4");
        execFileSync(
          "ffmpeg",
          [
            "-hide_banner",
            "-loglevel",
            "error",
            "-nostdin",
            "-f",
            "lavfi",
            "-i",
            "color=c=black:s=160x90:r=10:d=2",
            "-an",
            "-c:v",
            "mpeg4",
            "-g",
            "10",
            "-bf",
            "0",
            "-movflags",
            "frag_keyframe+empty_moov+default_base_moof",
            "-f",
            "mp4",
            file,
          ],
          { timeout: 20000, stdio: "pipe" },
        );

        const parsed = readFragmentTimings(readFileSync(file));
        expect(parsed).toHaveLength(1);
        const track = parsed[0];
        expect(track).toBeDefined();

        const probe = JSON.parse(
          execFileSync(
            "ffprobe",
            [
              "-v",
              "error",
              "-select_streams",
              "v:0",
              "-show_packets",
              "-show_entries",
              "packet=pts_time,dts_time,duration_time",
              "-of",
              "json",
              file,
            ],
            { timeout: 10000, encoding: "utf8" },
          ),
        ) as {
          packets: {
            pts_time: string;
            dts_time: string;
            duration_time: string;
          }[];
        };
        expect(probe.packets.length).toBe(20);
        const firstDts = Math.min(
          ...probe.packets.map((p) => Number(p.dts_time)),
        );
        const firstPts = Math.min(
          ...probe.packets.map((p) => Number(p.pts_time)),
        );
        const lastEnd = Math.max(
          ...probe.packets.map(
            (p) => Number(p.pts_time) + Number(p.duration_time),
          ),
        );
        expect(track?.samples).toBe(probe.packets.length);
        expect(track?.firstDecodeSeconds).toBeCloseTo(firstDts, 4);
        expect(track?.firstPresentationSeconds).toBeCloseTo(firstPts, 4);
        expect(track?.endPresentationSeconds).toBeCloseTo(lastEnd, 4);
      } finally {
        rmSync(dir, { recursive: true, force: true });
      }
    });
  },
);
