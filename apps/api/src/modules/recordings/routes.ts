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
import { cameraId } from "../cameras/schemas.js";
import { RecordingRepository, type RecordingFilter } from "./repository.js";
import { sendFragmentedRecording } from "./fragmented-media.js";

const cameraIds = z
  .string()
  .min(1)
  .transform((value) => value.split(","))
  .pipe(z.array(cameraId).min(1));

const pagination = z
  .object({
    page: z.coerce.number().int().min(1).default(1),
    pageSize: z.coerce.number().int().min(1).max(100).default(25),
    from: z.string().datetime({ offset: true }).optional(),
    to: z.string().datetime({ offset: true }).optional(),
    cameraIds: cameraIds.optional(),
  })
  .superRefine((value, context) => {
    if (
      value.from &&
      value.to &&
      Date.parse(value.from) > Date.parse(value.to)
    ) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        message: "From must not be after to",
      });
    }
  });
const maximumTimelineWindowMs = 31 * 24 * 60 * 60 * 1000;
const timelineItemLimit = 5000;
const timelineQuery = z
  .object({
    from: z.string().datetime({ offset: true }),
    to: z.string().datetime({ offset: true }),
    cameraIds: cameraIds.optional(),
  })
  .superRefine((value, context) => {
    const from = Date.parse(value.from);
    const to = Date.parse(value.to);
    if (from >= to || to - from > maximumTimelineWindowMs) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        message: "Timeline window must be positive and at most 31 days",
      });
    }
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

function registerRecordingListRoute(
  app: FastifyInstance,
  repository: RecordingRepository,
) {
  app.get("/", async (request, reply) => {
    const parsed = pagination.safeParse(request.query);
    if (!parsed.success)
      return reply.code(400).send({
        code: "VALIDATION_ERROR",
        message: "Invalid recording filters",
      });
    const offset = (parsed.data.page - 1) * parsed.data.pageSize;
    const filter: RecordingFilter = {};
    if (parsed.data.from) filter.from = new Date(parsed.data.from);
    if (parsed.data.to) filter.to = new Date(parsed.data.to);
    if (parsed.data.cameraIds) filter.cameraIds = parsed.data.cameraIds;
    const [items, totalItems] = await Promise.all([
      repository.list(parsed.data.pageSize, offset, filter),
      repository.count(filter),
    ]);
    return {
      items,
      page: parsed.data.page,
      pageSize: parsed.data.pageSize,
      totalItems,
      totalPages: Math.ceil(totalItems / parsed.data.pageSize),
    };
  });
}

function registerRecordingDetailsRoute(
  app: FastifyInstance,
  repository: RecordingRepository,
) {
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
}

function registerRecordingTimelineRoute(
  app: FastifyInstance,
  repository: RecordingRepository,
) {
  app.get("/timeline", async (request, reply) => {
    const parsed = timelineQuery.safeParse(request.query);
    if (!parsed.success) {
      return reply.code(400).send({
        code: "VALIDATION_ERROR",
        message: "Invalid recording timeline filters",
      });
    }
    const items = await repository.timeline(
      {
        from: new Date(parsed.data.from),
        to: new Date(parsed.data.to),
        ...(parsed.data.cameraIds ? { cameraIds: parsed.data.cameraIds } : {}),
      },
      timelineItemLimit + 1,
    );
    if (items.length > timelineItemLimit) {
      return reply.code(422).send({
        code: "TIMELINE_RESULT_LIMIT",
        message: "Timeline contains too many recordings; narrow the filters",
      });
    }
    return { items };
  });
}

function registerRecordingExpiryRoute(
  app: FastifyInstance,
  repository: RecordingRepository,
) {
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
}

function registerRecordingThumbnailRoute(
  app: FastifyInstance,
  repository: RecordingRepository,
  storagePath: string,
) {
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

    const file = await resolveRecordingFile(
      reply,
      storagePath,
      recording.filePath,
    );
    if (!file) return;
    return sendThumbnail(app, reply, file, parsed.data);
  });
}

const fragmentQuery = z.object({
  startSeconds: z.coerce.number().finite().min(0).max(86400).default(0),
  durationSeconds: z.coerce.number().finite().min(0.1).max(30).default(10),
});

function registerRecordingFragmentRoute(
  app: FastifyInstance,
  repository: RecordingRepository,
  storagePath: string,
) {
  app.get("/:id/fragment", async (request, reply) => {
    const id = recordingId.safeParse((request.params as { id: string }).id);
    const query = fragmentQuery.safeParse(request.query);
    if (!id.success || !query.success) {
      return reply.code(400).send({
        code: "VALIDATION_ERROR",
        message: "Invalid recording fragment request",
      });
    }
    const recording = await repository.findFile(id.data);
    if (!recording || recording.container !== "mp4") {
      return reply.code(404).send({
        code: "NOT_FOUND",
        message: "MP4 recording not found",
      });
    }
    const file = await resolveRecordingFile(reply, storagePath, recording.filePath);
    if (!file) return;
    return sendFragmentedRecording(app, request, reply, file, query.data);
  });
}

function registerRecordingMediaRoute(
  app: FastifyInstance,
  repository: RecordingRepository,
  storagePath: string,
) {
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

    const file = await resolveRecordingFile(
      reply,
      storagePath,
      recording.filePath,
    );
    if (!file) return;
    return sendRecordingMedia(request, reply, file, recording.container);
  });
}

export const recordingRoutes: FastifyPluginAsync<{
  storagePath: string;
}> = async (app, options) => {
  const repository = new RecordingRepository(app.db);
  registerRecordingListRoute(app, repository);
  registerRecordingTimelineRoute(app, repository);
  registerRecordingDetailsRoute(app, repository);
  registerRecordingExpiryRoute(app, repository);
  registerRecordingThumbnailRoute(app, repository, options.storagePath);
  registerRecordingMediaRoute(app, repository, options.storagePath);
  registerRecordingFragmentRoute(app, repository, options.storagePath);
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
