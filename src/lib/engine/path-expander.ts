import type { PermissionRule, ToolName } from "@/types/settings";

const SENSITIVE_TOOLS: ToolName[] = ["Read", "Edit"];

/**
 * 機密ファイルパターンから4パターンの deny ルールを自動生成する。
 * 1. 相対パス（カレントディレクトリ）: .env
 * 2. 相対パス（再帰的）: **\/.env
 * 3. 絶対パス（Permission Rules用）: //.env
 * 4. 拡張子バリエーション: **\/.env.*
 */
export function expandDenyPatterns(filename: string): PermissionRule[] {
  const rules: PermissionRule[] = [];
  const basename = filename.startsWith("**/")
    ? filename.slice(3)
    : filename.startsWith("./")
      ? filename.slice(2)
      : filename;

  for (const tool of SENSITIVE_TOOLS) {
    // 1. カレントディレクトリ
    rules.push({ tool, path: basename });
    // 2. 再帰的マッチ
    rules.push({ tool, path: `**/${basename}` });
    // 3. 絶対パス（Permission Rules用 // プレフィックス）
    rules.push({ tool, path: `//${basename}` });
    // 4. 拡張子バリエーション（.env → .env.*）
    if (!basename.includes("*")) {
      rules.push({ tool, path: `**/${basename}.*` });
    }
  }

  return rules;
}

/**
 * 重複ルールを除去する
 */
export function deduplicateRules(rules: PermissionRule[]): PermissionRule[] {
  const seen = new Set<string>();
  return rules.filter((rule) => {
    const key = `${rule.tool}:${rule.path ?? ""}:${rule.command ?? ""}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}
