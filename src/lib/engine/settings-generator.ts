import type { ClaudeCodeSettings } from "@/types/settings";

const GENERATOR_VERSION = "1.0.0";
const SCHEMA_VERSION = "1.0.0";

/**
 * 設定オブジェクトから最終的な JSON 出力を生成する
 * メタ情報は常に最上部に配置される
 */
export function generateSettingsJson(
  settings: ClaudeCodeSettings,
  options?: { includeMetadata?: boolean }
): Record<string, unknown> {
  const meta: Record<string, unknown> = {};
  if (options?.includeMetadata) {
    meta._schemaVersion = SCHEMA_VERSION;
    meta._generatedAt = new Date().toISOString();
    meta._generatorVersion = GENERATOR_VERSION;
  }

  const body: Record<string, unknown> = {};

  if (settings.language) {
    body.language = settings.language;
  }

  body.permissions = {
    allow: settings.permissions.allow.filter(
      (r) => r.tool && (r.path || r.command)
    ),
    deny: settings.permissions.deny.filter(
      (r) => r.tool && (r.path || r.command)
    ),
    ask: settings.permissions.ask.filter(
      (r) => r.tool && (r.path || r.command)
    ),
  };

  if (settings.permissionMode && settings.permissionMode !== "default") {
    body.permissionMode = settings.permissionMode;
  }

  if (settings.sandbox?.enabled) {
    body.sandbox = { ...settings.sandbox };
  }

  if (settings.autoMode && settings.permissionMode === "auto") {
    body.autoMode = settings.autoMode;
  }

  // メタ情報を先頭、設定本体を後続に配置
  return { ...meta, ...body };
}
