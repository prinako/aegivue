import { z } from 'zod';

const schema = z.object({
  VIGILO_API_HOST: z.string().default('0.0.0.0'),
  VIGILO_API_PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  VIGILO_DATABASE_URL: z.string().url().startsWith('postgres'),
  VIGILO_LOG_LEVEL: z.enum(['fatal','error','warn','info','debug','trace','silent']).default('info'),
  VIGILO_TRUST_PROXY: z.enum(['true','false']).default('false').transform(value => value === 'true'),
});

export type Config = z.infer<typeof schema>;
export const loadConfig = (env: NodeJS.ProcessEnv = process.env): Config => schema.parse(env);
