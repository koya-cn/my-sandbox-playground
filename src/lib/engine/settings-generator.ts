import type { ClaudeCodeSettings } from "@/types/settings";

/**
 * 設定オブジェクトから最終的な JSON 出力を生成する
 */
export function generateSettingsJson(
  settings: ClaudeCodeSettings
): Record<string, unknown> {
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

  return body;
}
