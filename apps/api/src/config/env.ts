import { z } from "zod";

const schema = z.object({
  AEGIVUE_API_HOST: z.string().default("0.0.0.0"),
  AEGIVUE_API_PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  AEGIVUE_DATABASE_URL: z.string().url().startsWith("postgres"),
  AEGIVUE_LOG_LEVEL: z
    .enum(["fatal", "error", "warn", "info", "debug", "trace", "silent"])
    .default("info"),
  AEGIVUE_MEDIA_URL: z.string().url().default("http://aegivue-media:3010"),
  AEGIVUE_STORAGE_PATH: z.string().min(1).default("/data/recordings"),
  AEGIVUE_TRUST_PROXY: z
    .enum(["true", "false"])
    .default("false")
    .transform((value) => value === "true"),
});

export type Config = z.infer<typeof schema>;
export const loadConfig = (env: NodeJS.ProcessEnv = process.env): Config =>
  schema.parse(env);
