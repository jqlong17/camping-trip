import { existsSync, realpathSync } from "node:fs";
import { isAbsolute, relative, resolve, sep } from "node:path";

const ALLOWED_PREFIXES = ["game", "docs", "cia", "scripts", "tools/story-atlas"];

export function createPathPolicy(repoRoot: string) {
  const root = realpathSync(repoRoot);

  function resolveRepoFile(requestedPath: string): string {
    if (
      !requestedPath ||
      requestedPath.includes("\0") ||
      isAbsolute(requestedPath) ||
      requestedPath.split(/[\\/]/).includes("..")
    ) {
      throw new Error("路径必须是仓库内的相对路径");
    }

    const normalized = requestedPath.replaceAll("\\", "/").replace(/^\.\/+/, "");
    if (!ALLOWED_PREFIXES.some((prefix) => normalized === prefix || normalized.startsWith(`${prefix}/`))) {
      throw new Error("该目录不在允许访问的白名单中");
    }

    const candidate = resolve(root, normalized);
    if (candidate !== root && !candidate.startsWith(`${root}${sep}`)) {
      throw new Error("路径越过仓库边界");
    }
    if (!existsSync(candidate)) {
      throw new Error("文件不存在");
    }

    const actual = realpathSync(candidate);
    if (actual !== root && !actual.startsWith(`${root}${sep}`)) {
      throw new Error("符号链接指向仓库外部");
    }
    return actual;
  }

  function toRepoPath(absolutePath: string): string {
    return relative(root, absolutePath).split(sep).join("/");
  }

  return { resolveRepoFile, toRepoPath };
}
