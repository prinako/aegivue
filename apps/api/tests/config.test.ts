import { describe, expect, it } from "vitest";
import { loadConfig } from "../src/config/env.js";
describe("configuration", () => {
  it("applies safe defaults", () =>
    expect(
      loadConfig({
        VIGILO_DATABASE_URL: "postgres://localhost/vigilo",
      }).VIGILO_API_PORT,
    ).toBe(3000));
  it("rejects invalid ports", () =>
    expect(() =>
      loadConfig({
        VIGILO_DATABASE_URL: "postgres://localhost/vigilo",
        VIGILO_API_PORT: "0",
      }),
    ).toThrow());
});
