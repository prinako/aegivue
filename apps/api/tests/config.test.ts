import { describe, expect, it } from "vitest";
import { loadConfig } from "../src/config/env.js";
describe("configuration", () => {
  it("applies safe defaults", () =>
    expect(
      loadConfig({
        AEGIVUE_DATABASE_URL: "postgres://localhost/aegivue",
      }).AEGIVUE_API_PORT,
    ).toBe(3000));
  it("rejects invalid ports", () =>
    expect(() =>
      loadConfig({
        AEGIVUE_DATABASE_URL: "postgres://localhost/aegivue",
        AEGIVUE_API_PORT: "0",
      }),
    ).toThrow());
});
