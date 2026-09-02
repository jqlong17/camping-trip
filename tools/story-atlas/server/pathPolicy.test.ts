import { mkdtempSync, mkdirSync, realpathSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { createPathPolicy } from "./pathPolicy";

function fixture() {
  const root = mkdtempSync(join(tmpdir(), "story-atlas-"));
  mkdirSync(join(root, "game", "assets"), { recursive: true });
  writeFileSync(join(root, "game", "assets", "p1.png"), "pixel");
  return root;
}

describe("本地文件白名单", () => {
  it("允许仓库内资源", () => {
    const root = fixture();
    const policy = createPathPolicy(root);
    expect(policy.resolveRepoFile("game/assets/p1.png")).toBe(
      realpathSync(join(root, "game", "assets", "p1.png"))
    );
  });

  it("拒绝绝对路径与目录穿越", () => {
    const policy = createPathPolicy(fixture());
    expect(() => policy.resolveRepoFile("/etc/passwd")).toThrow();
    expect(() => policy.resolveRepoFile("game/../docs/file.png")).toThrow();
  });

  it("拒绝逃出仓库的符号链接", () => {
    const root = fixture();
    symlinkSync("/etc/passwd", join(root, "game", "assets", "outside"));
    const policy = createPathPolicy(root);
    expect(() => policy.resolveRepoFile("game/assets/outside")).toThrow();
  });
});
