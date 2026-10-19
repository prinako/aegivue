import { spawn } from "node:child_process";
import { stat } from "node:fs/promises";
import { Transform } from "node:stream";
import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";

export interface FragmentQuery {
  startSeconds: number;
  durationSeconds: number;
}

const maximumConcurrentRemuxes = 4;
let activeRemuxes = 0;

/**
 * Returns a bounded, fragmented MP4 by stream-copying a finalized MP4 file.
 * Each response has its own init segment and must NOT be blindly appended to
 * an already-open MSE SourceBuffer. The timeline coordinator is responsible
 * for codec continuity and timestamp mapping across recording boundaries.
 */
export async function sendFragmentedRecording(
  app: FastifyInstance,
  request: FastifyRequest,
  reply: FastifyReply,
  file: string,
  query: FragmentQuery,
) {
  try {
    const metadata = await stat(file);
    if (!metadata.isFile() || metadata.size === 0 || !file.endsWith(".mp4")) {
      return reply.code(404).send({
        code: "FILE_NOT_FOUND",
        message: "Finalized MP4 recording is unavailable",
      });
    }
  } catch {
    return reply.code(404).send({
      code: "FILE_NOT_FOUND",
      message: "Recording file is unavailable",
    });
  }

  if (activeRemuxes >= maximumConcurrentRemuxes) {
    return reply
      .code(503)
      .header("Retry-After", "1")
      .send({ code: "REMUX_BUSY", message: "Media remux capacity reached" });
  }

  activeRemuxes++;
  const ffmpeg = spawn(
    "ffmpeg",
    [
      "-hide_banner", "-loglevel", "error",
      "-ss", String(query.startSeconds),
      "-i", file,
      "-t", String(query.durationSeconds),
      "-map", "0:v:0", "-map", "0:a?",
      "-c", "copy",
      "-movflags", "frag_keyframe+empty_moov+default_base_moof",
      "-f", "mp4", "pipe:1",
    ],
    { stdio: ["ignore", "pipe", "pipe"] },
  );
  let released = false;
  let diagnostic = "";
  const release = () => {
    if (released) return;
    released = true;
    activeRemuxes--;
  };
  const stop = () => {
    if (ffmpeg.exitCode === null && !ffmpeg.killed) ffmpeg.kill("SIGKILL");
  };
  request.raw.once("aborted", stop);
  reply.raw.once("close", () => {
    if (!reply.raw.writableFinished) stop();
  });
  ffmpeg.stderr.setEncoding("utf8");
  ffmpeg.stderr.on("data", (chunk: string) => {
    diagnostic = (diagnostic + chunk).slice(-4096);
  });
  ffmpeg.once("error", (error) => {
    app.log.warn({ error }, "fMP4 remux process error");
    release();
  });
  ffmpeg.once("close", (code) => {
    release();
    if (code !== 0) {
      app.log.warn({ code, diagnostic }, "fMP4 remux failed");
    }
  });
  const output = new Transform({
    transform(chunk, _encoding, callback) {
      callback(null, chunk);
    },
  });
  ffmpeg.stdout.pipe(output);
  output.once("close", stop);
  reply
    .header("Content-Type", "video/mp4")
    .header("Cache-Control", "private, no-store")
    .header("X-Content-Type-Options", "nosniff");
  return reply.send(output);
}
