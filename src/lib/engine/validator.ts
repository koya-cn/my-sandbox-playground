import type { ClaudeCodeSettings, PermissionRule } from "@/types/settings";
import { isValidGlob } from "@/lib/utils/glob-matcher";

export interface ValidationIssue {
  severity: "error" | "warning";
  message: string;
  path?: string;
}

function ruleKey(rule: PermissionRule): string {
  return `${rule.tool}:${rule.path ?? rule.command ?? "*"}`;
}

/**
 * 設定の論理整合性チェック
 */
export function validateSettings(
  settings: ClaudeCodeSettings
): ValidationIssue[] {
  const issues: ValidationIssue[] = [];

  // 1. allow と deny の競合チェック
  const denyKeys = new Set(settings.permissions.deny.map(ruleKey));
  for (const rule of settings.permissions.allow) {
    const key = ruleKey(rule);
    if (denyKeys.has(key)) {
      issues.push({
        severity: "warning",
        message: `同一ルール "${key}" が allow と deny の両方に定義されています。deny が優先されるため、allow ルールは無効です。`,
        path: `permissions.allow`,
      });
    }
  }

  // 2. Glob パターンの妥当性チェック
  const allRules = [
    ...settings.permissions.allow,
    ...settings.permissions.deny,
    ...settings.permissions.ask,
  ];
  for (const rule of allRules) {
    const pattern = rule.path ?? rule.command;
    if (pattern && !isValidGlob(pattern)) {
      issues.push({
        severity: "error",
        message: `無効な Glob パターン: "${pattern}"`,
        path: `permissions`,
      });
    }
  }

  // 3. sandbox の deny/allow 矛盾チェック
  if (settings.sandbox?.filesystem) {
    const fs = settings.sandbox.filesystem;
    const allowWrite = new Set(fs.allowWrite ?? []);
    for (const denyPath of settings.permissions.deny) {
      if (denyPath.path && allowWrite.has(denyPath.path)) {
        issues.push({
          severity: "warning",
          message: `"${denyPath.path}" が permissions.deny と sandbox.filesystem.allowWrite の両方に含まれています。`,
        });
      }
    }
  }

  // 4. bypassPermissions モードの警告
  if (settings.permissionMode === "bypassPermissions") {
    issues.push({
      severity: "warning",
      message:
        "bypassPermissions モードはすべての権限チェックを無効化します。隔離されたコンテナ環境でのみ使用してください。",
    });
  }

  // 5. auto モードで sandbox が無効の場合の警告
  if (settings.permissionMode === "auto" && !settings.sandbox?.enabled) {
    issues.push({
      severity: "warning",
      message:
        "auto モードではサンドボックスの有効化を推奨します。エージェントの自律的な操作に対するOSレベルの制限が追加されます。",
    });
  }

  // 6. 機密ファイルが deny されていない場合の警告
  const sensitivePatterns = [".env", ".ssh", ".aws/credentials"];
  const denyPaths = settings.permissions.deny
    .map((r) => r.path)
    .filter(Boolean);
  for (const sensitive of sensitivePatterns) {
    const hasDeny = denyPaths.some(
      (p) => p && (p.includes(sensitive) || p === sensitive)
    );
    if (!hasDeny) {
      issues.push({
        severity: "warning",
        message: `機密パス "${sensitive}" に対する deny ルールが設定されていません。セキュリティ強化のため追加を推奨します。`,
      });
    }
  }

  return issues;
}
