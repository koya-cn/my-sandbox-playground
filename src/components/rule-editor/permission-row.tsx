"use client";

import type { PermissionRule } from "@/types/settings";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Button } from "@/components/ui/button";

const TOOL_OPTIONS = [
  { value: "Read", hint: "ファイル読み取り" },
  { value: "Edit", hint: "ファイル編集" },
  { value: "Write", hint: "ファイル新規作成" },
  { value: "Bash", hint: "シェルコマンド実行" },
  { value: "Glob", hint: "ファイル検索" },
  { value: "Grep", hint: "テキスト検索" },
  { value: "Agent", hint: "サブエージェント" },
  { value: "WebFetch", hint: "Web コンテンツ取得" },
  { value: "WebSearch", hint: "Web 検索" },
  { value: "NotebookEdit", hint: "Jupyter ノートブック編集" },
];

interface PermissionRowProps {
  rule: PermissionRule;
  onChange: (rule: PermissionRule) => void;
  onRemove: () => void;
}

export function PermissionRow({ rule, onChange, onRemove }: PermissionRowProps) {
  const isBash = rule.tool === "Bash";
  const isMcp = rule.tool.startsWith("mcp__");

  return (
    <div className="flex items-center gap-2 rounded-md border bg-card p-2 min-w-0">
      {isMcp ? (
        <Input
          value={rule.tool}
          onChange={(e) => onChange({ ...rule, tool: e.target.value })}
          placeholder="mcp__server__tool"
          title="MCP ツール名: mcp__サーバー名__ツール名 (ワイルドカード可: mcp__github__*)"
          className="w-40 shrink-0 font-mono text-xs"
        />
      ) : (
        <Select
          value={rule.tool}
          onValueChange={(value) => {
            if (!value) return;
            if (value === "mcp__custom") {
              onChange({
                ...rule,
                tool: "mcp__",
                path: undefined,
                command: undefined,
              });
              return;
            }
            onChange({
              ...rule,
              tool: value,
              path: value === "Bash" ? undefined : rule.path,
              command: value === "Bash" ? rule.command : undefined,
            });
          }}
        >
          <SelectTrigger className="w-40 shrink-0">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {TOOL_OPTIONS.map((tool) => (
              <SelectItem key={tool.value} value={tool.value}>
                <span className="font-medium shrink-0">{tool.value}</span>
                <span className="text-muted-foreground ml-1.5 text-xs truncate">
                  {tool.hint}
                </span>
              </SelectItem>
            ))}
            <SelectItem value="mcp__custom">
              <span className="font-medium">MCP</span>
              <span className="text-muted-foreground ml-1.5 text-xs">
                外部ツール
              </span>
            </SelectItem>
          </SelectContent>
        </Select>
      )}

      {isBash ? (
        <Input
          value={rule.command ?? ""}
          onChange={(e) => onChange({ ...rule, command: e.target.value })}
          placeholder="例: npm test *"
          title="Glob パターン対応。* で任意の引数にマッチ。例: npm run *, git push *"
          className="flex-1"
        />
      ) : (
        <div className="flex-1 space-y-0.5">
          <Input
            value={rule.path ?? ""}
            onChange={(e) => onChange({ ...rule, path: e.target.value })}
            placeholder="例: src/**/*.ts"
            title="Glob パターン対応。** で再帰マッチ。絶対パスは // プレフィックス。"
          />
          {rule.path?.startsWith("/") && !rule.path?.startsWith("//") && (
            <p className="text-yellow-600 text-[10px] px-1">
              Permission Rules の絶対パスは // プレフィックスです（例:
              //.ssh/**）
            </p>
          )}
        </div>
      )}

      <Button
        variant="ghost"
        size="sm"
        onClick={onRemove}
        className="text-muted-foreground hover:text-destructive shrink-0 h-8 w-8 p-0"
      >
        x
      </Button>
    </div>
  );
}
