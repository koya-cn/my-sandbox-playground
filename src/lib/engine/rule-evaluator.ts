import type {
  ClaudeCodeSettings,
  DryRunInput,
  DryRunResult,
  PermissionAction,
  PermissionRule,
} from "@/types/settings";
import { isGlobMatch } from "@/lib/utils/glob-matcher";

function matchesRule(rule: PermissionRule, input: DryRunInput): boolean {
  // ツール名チェック（ワイルドカード対応: mcp__*__* 等）
  if (rule.tool !== input.action) {
    if (rule.tool.includes("*")) {
      if (!isGlobMatch(input.action, rule.tool)) return false;
    } else {
      return false;
    }
  }

  // パスベースのマッチング
  if (rule.path && input.path) {
    return isGlobMatch(input.path, rule.path);
  }

  // コマンドベースのマッチング
  if (rule.command && input.command) {
    return isGlobMatch(input.command, rule.command);
  }

  // パスもコマンドも指定なし → ツール名のみでマッチ
  if (!rule.path && !rule.command) {
    return true;
  }

  return false;
}

function findMatchingRule(
  rules: PermissionRule[],
  input: DryRunInput
): { rule: PermissionRule; index: number } | null {
  for (let i = 0; i < rules.length; i++) {
    if (matchesRule(rules[i], input)) {
      return { rule: rules[i], index: i };
    }
  }
  return null;
}

/**
 * deny > ask > allow > fallback(ask) の優先順位でルールを評価する
 */
export function evaluateRules(
  settings: ClaudeCodeSettings,
  input: DryRunInput
): DryRunResult {
  // 1. deny チェック（最優先）
  const denyMatch = findMatchingRule(settings.permissions.deny, input);
  if (denyMatch) {
    return {
      decision: "deny",
      matchedRule: denyMatch.rule,
      ruleSource: `permissions.deny[${denyMatch.index}]`,
    };
  }

  // 2. ask チェック
  const askMatch = findMatchingRule(settings.permissions.ask, input);
  if (askMatch) {
    return {
      decision: "ask",
      matchedRule: askMatch.rule,
      ruleSource: `permissions.ask[${askMatch.index}]`,
    };
  }

  // 3. allow チェック
  const allowMatch = findMatchingRule(settings.permissions.allow, input);
  if (allowMatch) {
    return {
      decision: "allow",
      matchedRule: allowMatch.rule,
      ruleSource: `permissions.allow[${allowMatch.index}]`,
    };
  }

  // 4. Fallback: ask（Fail-closed設計）
  return {
    decision: "ask",
    matchedRule: null,
    ruleSource: null,
  };
}

export function getDecisionColor(decision: PermissionAction): string {
  switch (decision) {
    case "deny":
      return "text-red-600";
    case "ask":
      return "text-yellow-600";
    case "allow":
      return "text-green-600";
  }
}

export function getDecisionBadgeVariant(
  decision: PermissionAction
): "destructive" | "outline" | "default" {
  switch (decision) {
    case "deny":
      return "destructive";
    case "ask":
      return "outline";
    case "allow":
      return "default";
  }
}
