import { z } from "zod";

export const cameraId = z.string().regex(/^[a-z0-9][a-z0-9_-]{2,63}$/);
const streamPath = z
  .string()
  .min(1)
  .max(512)
  .refine((v) => v.startsWith("/"), "stream path must start with /");

const connection = z.object({
  protocol: z.literal("rtsp"),
  host: z.string().min(1).max(253),
  port: z.number().int().min(1).max(65535).default(554),
  username: z.string().max(255).optional(),
  password: z.string().max(1024).optional(),
  mainStream: streamPath,
  subStream: streamPath.optional(),
});

const recording = z.object({
  enabled: z.boolean().default(true),
  mode: z.enum(["continuous", "motion"]).default("continuous"),
  preEventSeconds: z.number().int().min(0).max(120).default(5),
  postEventSeconds: z.number().int().min(0).max(600).default(15),
});

const motion = z.object({
  enabled: z.boolean().default(false),
  stream: z.enum(["main", "sub"]).default("sub"),
  fps: z.number().min(0.1).max(30).default(5),
  sensitivity: z.number().min(0).max(1).default(0.65),
});

function validateMotionSubStream(
  value: {
    connection: z.infer<typeof connection>;
    motion: z.infer<typeof motion>;
  },
  ctx: z.RefinementCtx,
) {
  if (
    value.motion.enabled &&
    value.motion.stream === "sub" &&
    !value.connection.subStream
  ) {
    ctx.addIssue({
      code: "custom",
      path: ["connection", "subStream"],
      message: "required when motion uses the sub stream",
    });
  }
}

export const createCamera = z
  .object({
    id: cameraId,
    name: z.string().trim().min(1).max(120),
    enabled: z.boolean().default(true),
    connection,
    recording: recording.default({}),
    motion: motion.default({}),
  })
  .superRefine(validateMotionSubStream);

export const updateCamera = z
  .object({
    name: z.string().trim().min(1).max(120),
    enabled: z.boolean(),
    connection,
    recording,
    motion,
  })
  .superRefine(validateMotionSubStream);

export type CreateCamera = z.infer<typeof createCamera>;
export type UpdateCamera = z.infer<typeof updateCamera>;
