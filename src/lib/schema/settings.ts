import { z } from "zod";

export const permissionRuleSchema = z.object({
  tool: z.string().min(1, "ツール名は必須です"),
  path: z.string().optional(),
  command: z.string().optional(),
});

export const sandboxConfigSchema = z.object({
  enabled: z.boolean().default(false),
  allowedHosts: z.array(z.string()).default([]),
  filesystem: z
    .object({
      allowWrite: z.array(z.string()).default([]),
      denyWrite: z.array(z.string()).default([]),
      allowRead: z.array(z.string()).default([]),
      denyRead: z.array(z.string()).default([]),
    })
    .default({ allowWrite: [], denyWrite: [], allowRead: [], denyRead: [] }),
  excludedCommands: z.array(z.string()).default([]),
});

export const autoModeConfigSchema = z.object({
  fallback: z.object({
    consecutiveBlockThreshold: z.number().min(1).max(10).default(3),
    sessionBlockThreshold: z.number().min(5).max(100).default(20),
    fallbackAction: z.enum(["ask", "abort"]).default("ask"),
  }),
});

export const permissionModeSchema = z.enum([
  "default",
  "plan",
  "acceptEdits",
  "auto",
  "dontAsk",
  "bypassPermissions",
]);

export const claudeCodeSettingsSchema = z.object({
  _schemaVersion: z.string().optional(),
  _generatedAt: z.string().optional(),
  _generatorVersion: z.string().optional(),
  permissions: z.object({
    allow: z.array(permissionRuleSchema).default([]),
    deny: z.array(permissionRuleSchema).default([]),
    ask: z.array(permissionRuleSchema).default([]),
  }),
  permissionMode: permissionModeSchema.optional(),
  sandbox: sandboxConfigSchema.partial().optional(),
  autoMode: autoModeConfigSchema.optional(),
});

export type ClaudeCodeSettingsInput = z.input<typeof claudeCodeSettingsSchema>;
