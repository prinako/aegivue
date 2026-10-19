import { spawn } from "node:child_process";
import { stat } from "node:fs/promises";
import type { FastifyReply, FastifyRequest } from "fastify";
import { readFragmentTimings } from "./mp4-timing.js";
import type { FragmentQuery } from "./fragmented-media.js";

const maxBytes = 32 * 1024 * 1024;
const maxConcurrent = 2;
let active = 0;

/**
 * Opt-in endpoint: remux into bounded memory, inspect the EXACT response bytes,
 * then return the fMP4 with measured per-track timing in an HTTP header.
 * The original streaming endpoint is deliberately unchanged.
 */
export async function sendMeasuredFragment(
  request: FastifyRequest,
  reply: FastifyReply,
  file: string,
  query: FragmentQuery,
) {
  try {
    const info = await stat(file);
    if (!info.isFile() || !info.size || !file.endsWith(".mp4")) {
      return reply.code(404).send({ code: "FILE_NOT_FOUND" });
    }
  } catch {
    return reply.code(404).send({ code: "FILE_NOT_FOUND" });
  }

  if (active >= maxConcurrent) {
    return reply.code(503).header("Retry-After", "1")
      .send({ code: "REMUX_BUSY" });
  }
  active++;
  try {
    const bytes = await new Promise<Buffer>((resolve, reject) => {
      const child = spawn("ffmpeg", [
        "-hide_banner", "-loglevel", "error", "-nostdin",
        "-ss", String(query.startSeconds),
        "-i", file, "-t", String(query.durationSeconds),
        "-map", "0:v:0", "-map", "0:a?",
        "-c", "copy",
        "-movflags", "frag_keyframe+empty_moov+default_base_moof",
        "-f", "mp4", "pipe:1",
      ], { stdio: ["ignore", "pipe", "pipe"] });
      let settled = false;
      let size = 0;
      const chunks: Buffer[] = [];
      const finish = (error?: Error) => {
        if (settled) return;
        settled = true;
        clearTimeout(timeout);
        request.raw.off("aborted", abort);
        reply.raw.off("close", abort);
        if (error) {
          child.kill("SIGKILL");
          reject(error);
        } else resolve(Buffer.concat(chunks, size));
      };
      const abort = () => finish(new Error("CLIENT_ABORTED"));
      const timeout = setTimeout(() => finish(new Error("REMUX_TIMEOUT")), 30000);
      request.raw.once("aborted", abort);
      reply.raw.once("close", abort);
      child.stdout.on("data", (chunk: Buffer) => {
        size += chunk.length;
        if (size > maxBytes) {
          finish(new Error("FRAGMENT_TOO_LARGE"));
          return;
        }
        chunks.push(chunk);
      });
      child.stderr.resume();
      child.on("error", () => finish(new Error("REMUX_FAILED")));
      child.on("close", (code) => {
        if (!settled) finish(code === 0 ? undefined : new Error("REMUX_FAILED"));
      });
    });
    const timings = readFragmentTimings(bytes);
    const metadata = JSON.stringify({
      requestedStartSeconds: query.startSeconds,
      tracks: timings,
    });
    // Encode JSON in base64url to make a safe compact single HTTP header.
    return reply.header("Content-Type", "video/mp4")
      .header("Cache-Control", "private, no-store")
      .header("X-Content-Type-Options", "nosniff")
      .header("X-Recording-Timing-Base64", Buffer.from(metadata).toString("base64url"))
      .send(bytes);
  } catch (error) {
    const message = error instanceof Error ? error.message : "REMUX_FAILED";
    const code = message === "CLIENT_ABORTED" ? 499
      : message === "FRAGMENT_TOO_LARGE" ? 413
      : message === "REMUX_TIMEOUT" ? 504
      : message.includes("MP4") || message.includes("fragment") ? 422 : 502;
    if (reply.raw.destroyed || request.raw.aborted) return;
    return reply.code(code).send({ code: message === "CLIENT_ABORTED" ? message : "FRAGMENT_UNAVAILABLE" });
  } finally {
    active--;
  }
}
