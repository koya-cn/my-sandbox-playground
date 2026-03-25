// Claude Code settings.json の型定義

export type PermissionAction = "allow" | "deny" | "ask";

export type ToolName =
  | "Read"
  | "Edit"
  | "Write"
  | "Bash"
  | "Glob"
  | "Grep"
  | "Agent"
  | "NotebookEdit"
  | "WebFetch"
  | "WebSearch"
  | string; // MCP tools: mcp__<server>__<tool>

export type PermissionMode =
  | "default"
  | "plan"
  | "acceptEdits"
  | "auto"
  | "dontAsk"
  | "bypassPermissions";

export interface PermissionRule {
  tool: ToolName;
  path?: string;
  command?: string;
}

export interface SandboxConfig {
  enabled: boolean;
  allowedHosts: string[];
  filesystem: {
    allowWrite: string[];
    denyWrite: string[];
    allowRead: string[];
    denyRead: string[];
  };
  excludedCommands: string[];
}

export interface AutoModeConfig {
  fallback: {
    consecutiveBlockThreshold: number;
    sessionBlockThreshold: number;
    fallbackAction: "ask" | "abort";
  };
}

export interface SettingsScope {
  id: "enterprise" | "user" | "shared-project" | "local-project";
  label: string;
  path: string;
}

export interface ClaudeCodeSettings {
  language?: string;
  permissions: {
    allow: PermissionRule[];
    deny: PermissionRule[];
    ask: PermissionRule[];
  };
  permissionMode?: PermissionMode;
  sandbox?: Partial<SandboxConfig>;
  autoMode?: AutoModeConfig;
}

export interface PresetDefinition {
  id: string;
  name: string;
  description: string;
  category: "frontend" | "backend" | "security" | "experimental" | "addon";
  type?: "base" | "addon"; // default: "base"
  settings: ClaudeCodeSettings;
}

export interface DryRunInput {
  action: ToolName;
  path?: string;
  command?: string;
}

export interface DryRunResult {
  decision: PermissionAction;
  matchedRule: PermissionRule | null;
  ruleSource: string | null;
}
