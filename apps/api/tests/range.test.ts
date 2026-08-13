import { describe, expect, it } from "vitest";
import { parseByteRange } from "../src/modules/recordings/routes.js";

describe("recording byte ranges", () => {
  it("parses bounded ranges", () =>
    expect(parseByteRange("bytes=0-1023", 2000)).toEqual({
      start: 0,
      end: 1023,
    }));
  it("parses open-ended ranges", () =>
    expect(parseByteRange("bytes=1024-", 2000)).toEqual({
      start: 1024,
      end: 1999,
    }));
  it("rejects ranges beyond the file", () =>
    expect(() => parseByteRange("bytes=2000-", 2000)).toThrow());
});
