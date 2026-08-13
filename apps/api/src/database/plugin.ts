import fp from "fastify-plugin";
import { Pool } from "pg";

declare module "fastify" {
  interface FastifyInstance {
    db: Pool;
  }
}

export const databasePlugin = fp(
  async (app, options: { connectionString: string }) => {
    const pool = new Pool({
      connectionString: options.connectionString,
      max: 10,
    });
    app.decorate("db", pool);
    app.addHook("onClose", async () => pool.end());
  },
);
