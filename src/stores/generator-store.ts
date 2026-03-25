import { create } from "zustand";
import type {
  ClaudeCodeSettings,
  DryRunInput,
  DryRunResult,
  PermissionAction,
  PermissionMode,
  PermissionRule,
  SettingsScope,
} from "@/types/settings";
import { presets } from "@/lib/schema/presets";
import { evaluateRules } from "@/lib/engine/rule-evaluator";
import { validateSettings, type ValidationIssue } from "@/lib/engine/validator";
import { generateSettingsJson } from "@/lib/engine/settings-generator";

export const SCOPES: SettingsScope[] = [
  {
    id: "user",
    label: "User (グローバル)",
    path: "~/.claude/settings.json",
  },
  {
    id: "shared-project",
    label: "Shared Project (チーム共有)",
    path: ".claude/settings.json",
  },
  {
    id: "local-project",
    label: "Local Project (個人用)",
    path: ".claude/settings.local.json",
  },
  {
    id: "enterprise",
    label: "Enterprise (組織強制)",
    path: "/etc/claude-code/managed-settings.json",
  },
];

interface GeneratorState {
  // 設定データ
  settings: ClaudeCodeSettings;
  selectedPresetId: string | null;
  selectedScope: SettingsScope;
  includeMetadata: boolean;

  // ドライラン
  dryRunInput: DryRunInput;
  dryRunResult: DryRunResult | null;

  // バリデーション
  validationIssues: ValidationIssue[];

  // アクション
  applyPreset: (presetId: string) => void;
  clearAll: () => void;
  setPermissionMode: (mode: PermissionMode) => void;
  addRule: (action: PermissionAction, rule: PermissionRule) => void;
  removeRule: (action: PermissionAction, index: number) => void;
  updateRule: (
    action: PermissionAction,
    index: number,
    rule: PermissionRule
  ) => void;
  setSandboxEnabled: (enabled: boolean) => void;
  setSandboxHosts: (hosts: string[]) => void;
  setScope: (scope: SettingsScope) => void;
  setIncludeMetadata: (include: boolean) => void;
  runDryRun: (input: DryRunInput) => void;
  setDryRunInput: (input: Partial<DryRunInput>) => void;
  validate: () => ValidationIssue[];
  generateOutput: () => Record<string, unknown>;
}

const emptySettings: ClaudeCodeSettings = {
  permissions: {
    allow: [],
    deny: [],
    ask: [],
  },
  permissionMode: "default",
  sandbox: {
    enabled: false,
    allowedHosts: [],
    filesystem: {
      allowWrite: [],
      denyWrite: [],
      allowRead: [],
      denyRead: [],
    },
    excludedCommands: [],
  },
};

export const useGeneratorStore = create<GeneratorState>((set, get) => ({
  settings: { ...emptySettings },
  selectedPresetId: null,
  selectedScope: SCOPES[0],
  includeMetadata: true,

  dryRunInput: { action: "Read", path: "", command: "" },
  dryRunResult: null,

  validationIssues: [],

  applyPreset: (presetId: string) => {
    const preset = presets.find((p) => p.id === presetId);
    if (!preset) return;
    set({
      settings: {
        ...emptySettings,
        ...preset.settings,
        permissions: {
          allow: [...preset.settings.permissions.allow],
          deny: [...preset.settings.permissions.deny],
          ask: [...preset.settings.permissions.ask],
        },
        sandbox: preset.settings.sandbox
          ? { ...emptySettings.sandbox, ...preset.settings.sandbox }
          : emptySettings.sandbox,
      },
      selectedPresetId: presetId,
      validationIssues: [],
      dryRunResult: null,
    });
  },

  clearAll: () => {
    set({
      settings: { ...emptySettings },
      selectedPresetId: null,
      validationIssues: [],
      dryRunResult: null,
    });
  },

  setPermissionMode: (mode: PermissionMode) => {
    set((state) => ({
      settings: { ...state.settings, permissionMode: mode },
      selectedPresetId: null,
    }));
  },

  addRule: (action: PermissionAction, rule: PermissionRule) => {
    set((state) => ({
      settings: {
        ...state.settings,
        permissions: {
          ...state.settings.permissions,
          [action]: [...state.settings.permissions[action], rule],
        },
      },
      selectedPresetId: null,
    }));
  },

  removeRule: (action: PermissionAction, index: number) => {
    set((state) => ({
      settings: {
        ...state.settings,
        permissions: {
          ...state.settings.permissions,
          [action]: state.settings.permissions[action].filter(
            (_, i) => i !== index
          ),
        },
      },
      selectedPresetId: null,
    }));
  },

  updateRule: (action: PermissionAction, index: number, rule: PermissionRule) => {
    set((state) => {
      const rules = [...state.settings.permissions[action]];
      rules[index] = rule;
      return {
        settings: {
          ...state.settings,
          permissions: {
            ...state.settings.permissions,
            [action]: rules,
          },
        },
        selectedPresetId: null,
      };
    });
  },

  setSandboxEnabled: (enabled: boolean) => {
    set((state) => ({
      settings: {
        ...state.settings,
        sandbox: { ...state.settings.sandbox, enabled },
      },
      selectedPresetId: null,
    }));
  },

  setSandboxHosts: (hosts: string[]) => {
    set((state) => ({
      settings: {
        ...state.settings,
        sandbox: { ...state.settings.sandbox, allowedHosts: hosts },
      },
      selectedPresetId: null,
    }));
  },

  setScope: (scope: SettingsScope) => {
    set({ selectedScope: scope });
  },

  setIncludeMetadata: (include: boolean) => {
    set({ includeMetadata: include });
  },

  runDryRun: (input: DryRunInput) => {
    const { settings } = get();
    const result = evaluateRules(settings, input);
    set({ dryRunResult: result, dryRunInput: input });
  },

  setDryRunInput: (input: Partial<DryRunInput>) => {
    set((state) => ({
      dryRunInput: { ...state.dryRunInput, ...input },
    }));
  },

  validate: () => {
    const { settings } = get();
    const issues = validateSettings(settings);
    set({ validationIssues: issues });
    return issues;
  },

  generateOutput: () => {
    const { settings, includeMetadata } = get();
    return generateSettingsJson(settings, { includeMetadata });
  },
}));
