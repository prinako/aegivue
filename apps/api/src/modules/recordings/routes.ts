import type {
  FastifyInstance,
  FastifyPluginAsync,
  FastifyReply,
  FastifyRequest,
} from "fastify";
import { z } from "zod";
import { createReadStream } from "node:fs";
import { stat } from "node:fs/promises";
import { spawn } from "node:child_process";
import { resolve, sep } from "node:path";
import { RecordingRepository } from "./repository.js";

const pagination = z.object({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(25),
});
const recordingId = z.string().uuid();
const expiryUpdate = z.object({
  expiresAt: z.string().datetime().nullable(),
});

async function resolveRecordingFile(
  reply: FastifyReply,
  storagePath: string,
  filePath: string,
): Promise<string | undefined> {
  const root = resolve(storagePath);
  const file = resolve(root, filePath);
  if (!file.startsWith(`${root}${sep}`)) {
    await reply
      .code(400)
      .send({ code: "INVALID_PATH", message: "Invalid recording path" });
    return undefined;
  }
  return file;
}

async function sendThumbnail(
  app: FastifyInstance,
  reply: FastifyReply,
  file: string,
  id: string,
) {
  // move the existing ffmpeg spawn + stderr/close handlers here
  try {
    const metadata = await stat(file);
    if (!metadata.isFile()) throw new Error("not a file");
  } catch {
    return reply.code(404).send({
      code: "FILE_NOT_FOUND",
      message: "Recording file is unavailable",
    });
  }
  const ffmpeg = spawn(
    "ffmpeg",
    [
      "-hide_banner",
      "-loglevel",
      "error",
      "-ss",
      "0.5",
      "-i",
      file,
      "-frames:v",
      "1",
      "-vf",
      "scale=640:-2",
      "-q:v",
      "4",
      "-f",
      "image2pipe",
      "-vcodec",
      "mjpeg",
      "pipe:1",
    ],
    { stdio: ["ignore", "pipe", "pipe"] },
  );
  let diagnostic = "";
  ffmpeg.stderr.setEncoding("utf8");
  ffmpeg.stderr.on("data", (chunk: string) => {
    if (diagnostic.length < 4096) diagnostic += chunk;
  });
  ffmpeg.on("error", (error) => {
    app.log.warn({ error, recordingId: id }, "thumbnail ffmpeg failed");
  });
  ffmpeg.on("close", (code) => {
    if (code !== 0) {
      app.log.warn(
        { code, recordingId: id, diagnostic: diagnostic.trim() },
        "thumbnail extraction failed",
      );
    }
  });
  reply
    .header("Content-Type", "image/jpeg")
    .header("Cache-Control", "public, max-age=604800, immutable");
  return reply.send(ffmpeg.stdout);
}

async function sendRecordingMedia(
  request: FastifyRequest,
  reply: FastifyReply,
  file: string,
  container: string,
) {
  // move the existing stat / parseByteRange / 206 vs full-file send here
  try {
    const metadata = await stat(file);
    if (!metadata.isFile()) throw new Error("not a file");
    let range: { start: number; end: number } | null;
    try {
      range = parseByteRange(request.headers.range, metadata.size);
    } catch {
      return await reply
        .code(416)
        .header("Content-Range", `bytes */${String(metadata.size)}`)
        .send();
    }
    reply
      .header("Accept-Ranges", "bytes")
      .header(
        "Content-Type",
        container === "mp4" ? "video/mp4" : "application/octet-stream",
      );
    if (range) {
      reply
        .code(206)
        .header(
          "Content-Range",
          `bytes ${String(range.start)}-${String(range.end)}/${String(metadata.size)}`,
        )
        .header("Content-Length", String(range.end - range.start + 1));
      return await reply.send(createReadStream(file, range));
    }
    reply.header("Content-Length", String(metadata.size));
    return await reply.send(createReadStream(file));
  } catch {
    return reply.code(404).send({
      code: "FILE_NOT_FOUND",
      message: "Recording file is unavailable",
    });
  }
}

export const recordingRoutes: FastifyPluginAsync<{
  storagePath: string;
}> = async (app, options) => {
  const repository = new RecordingRepository(app.db);
  app.get("/", async (request, reply) => {
    const parsed = pagination.safeParse(request.query);
    if (!parsed.success)
      return reply
        .code(400)
        .send({ code: "VALIDATION_ERROR", message: "Invalid pagination" });
    const offset = (parsed.data.page - 1) * parsed.data.pageSize;
    const [items, totalItems] = await Promise.all([
      repository.list(parsed.data.pageSize, offset),
      repository.count(),
    ]);
    return {
      items,
      page: parsed.data.page,
      pageSize: parsed.data.pageSize,
      totalItems,
      totalPages: Math.ceil(totalItems / parsed.data.pageSize),
    };
  });
  app.get("/:id", async (request, reply) => {
    const parsed = recordingId.safeParse((request.params as { id: string }).id);
    if (!parsed.success)
      return reply
        .code(400)
        .send({ code: "VALIDATION_ERROR", message: "Invalid recording id" });
    const recording = await repository.find(parsed.data);
    return (
      recording ??
      reply
        .code(404)
        .send({ code: "NOT_FOUND", message: "Recording not found" })
    );
  });
  app.patch("/:id/expiry", async (request, reply) => {
    const id = recordingId.safeParse((request.params as { id: string }).id);
    const body = expiryUpdate.safeParse(request.body);
    if (!id.success || !body.success) {
      return reply.code(400).send({
        code: "VALIDATION_ERROR",
        message: "Invalid recording expiry",
      });
    }

    const expiresAt = body.data.expiresAt
      ? new Date(body.data.expiresAt)
      : null;
    if (expiresAt && expiresAt.getTime() <= Date.now()) {
      return reply.code(400).send({
        code: "INVALID_EXPIRY",
        message: "Expiry must be in the future",
      });
    }

    const recording = await repository.setExpiry(id.data, expiresAt);
    return (
      recording ??
      reply
        .code(404)
        .send({ code: "NOT_FOUND", message: "Recording not found" })
    );
  });
  app.get("/:id/thumbnail", async (request, reply) => {
    const parsed = recordingId.safeParse((request.params as { id: string }).id);
    if (!parsed.success)
      return reply
        .code(400)
        .send({ code: "VALIDATION_ERROR", message: "Invalid recording id" });

    const recording = await repository.findFile(parsed.data);
    if (!recording)
      return reply
        .code(404)
        .send({ code: "NOT_FOUND", message: "Recording not found" });

    // const root = resolve(options.storagePath);
    // const file = resolve(root, recording.filePath);
    const file = await resolveRecordingFile(
      reply,
      options.storagePath,
      recording.filePath,
    );
    if (!file) return;
    return sendThumbnail(app, reply, file, parsed.data);
    // if (!file.startsWith(`${root}${sep}`))
    //   return reply
    //     .code(400)
    //     .send({ code: "INVALID_PATH", message: "Invalid recording path" });

    // try {
    //   const metadata = await stat(file);
    //   if (!metadata.isFile()) throw new Error("not a file");
    // } catch {
    //   return reply.code(404).send({
    //     code: "FILE_NOT_FOUND",
    //     message: "Recording file is unavailable",
    //   });
    // }

    // const ffmpeg = spawn(
    //   "ffmpeg",
    //   [
    //     "-hide_banner",
    //     "-loglevel",
    //     "error",
    //     "-ss",
    //     "0.5",
    //     "-i",
    //     file,
    //     "-frames:v",
    //     "1",
    //     "-vf",
    //     "scale=640:-2",
    //     "-q:v",
    //     "4",
    //     "-f",
    //     "image2pipe",
    //     "-vcodec",
    //     "mjpeg",
    //     "pipe:1",
    //   ],
    //   { stdio: ["ignore", "pipe", "pipe"] },
    // );

    // let diagnostic = "";
    // ffmpeg.stderr.setEncoding("utf8");
    // ffmpeg.stderr.on("data", (chunk: string) => {
    //   if (diagnostic.length < 4096) diagnostic += chunk;
    // });
    // ffmpeg.on("error", (error) => {
    //   app.log.warn(
    //     { error, recordingId: parsed.data },
    //     "thumbnail ffmpeg failed",
    //   );
    // });
    // ffmpeg.on("close", (code) => {
    //   if (code !== 0) {
    //     app.log.warn(
    //       { code, recordingId: parsed.data, diagnostic: diagnostic.trim() },
    //       "thumbnail extraction failed",
    //     );
    //   }
    // });

    // reply
    //   .header("Content-Type", "image/jpeg")
    //   .header("Cache-Control", "public, max-age=604800, immutable");
    // return await reply.send(ffmpeg.stdout);
  });

  app.get("/:id/media", async (request, reply) => {
    const parsed = recordingId.safeParse((request.params as { id: string }).id);
    if (!parsed.success)
      return reply
        .code(400)
        .send({ code: "VALIDATION_ERROR", message: "Invalid recording id" });
    const recording = await repository.findFile(parsed.data);
    if (!recording)
      return reply
        .code(404)
        .send({ code: "NOT_FOUND", message: "Recording not found" });

    // const root = resolve(options.storagePath);
    // const file = resolve(root, recording.filePath);
    const file = await resolveRecordingFile(
      reply,
      options.storagePath,
      recording.filePath,
    );
    if (!file) return;
    return sendRecordingMedia(request, reply, file, recording.container);

    // if (!file.startsWith(`${root}${sep}`))
    //   return reply
    //     .code(400)
    //     .send({ code: "INVALID_PATH", message: "Invalid recording path" });
    // try {
    //   const metadata = await stat(file);
    //   if (!metadata.isFile()) throw new Error("not a file");
    //   let range: { start: number; end: number } | null;
    //   try {
    //     range = parseByteRange(request.headers.range, metadata.size);
    //   } catch {
    //     return await reply
    //       .code(416)
    //       .header("Content-Range", `bytes */${String(metadata.size)}`)
    //       .send();
    //   }
    //   reply
    //     .header("Accept-Ranges", "bytes")
    //     .header(
    //       "Content-Type",
    //       recording.container === "mp4"
    //         ? "video/mp4"
    //         : "application/octet-stream",
    //     );
    //   if (range) {
    //     reply
    //       .code(206)
    //       .header(
    //         "Content-Range",
    //         `bytes ${String(range.start)}-${String(range.end)}/${String(metadata.size)}`,
    //       )
    //       .header("Content-Length", String(range.end - range.start + 1));
    //     return await reply.send(createReadStream(file, range));
    //   }
    //   reply.header("Content-Length", String(metadata.size));
    //   return await reply.send(createReadStream(file));
    // } catch {
    //   return reply.code(404).send({
    //     code: "FILE_NOT_FOUND",
    //     message: "Recording file is unavailable",
    //   });
    // }
  });
};

export function parseByteRange(
  header: string | undefined,
  size: number,
): { start: number; end: number } | null {
  if (!header) return null;
  const match = /^bytes=(\d+)-(\d*)$/.exec(header);
  if (!match) throw new Error("invalid range");
  const start = Number(match[1]);
  const end = match[2] ? Number(match[2]) : size - 1;
  if (
    !Number.isSafeInteger(start) ||
    !Number.isSafeInteger(end) ||
    start > end ||
    start >= size
  )
    throw new Error("range not satisfiable");
  return { start, end: Math.min(end, size - 1) };
}
