"use client";

import { useGeneratorStore } from "@/stores/generator-store";
import type { PermissionMode } from "@/types/settings";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { InfoLink } from "@/components/ui/info-link";

const modeDescriptions: Record<
  PermissionMode,
  { label: string; desc: string; risk: string; detail: string }
> = {
  default: {
    label: "Default",
    desc: "Read のみ自動承認",
    risk: "Low",
    detail: "最も安全。ファイル読み取りのみ自動承認し、編集やコマンドは毎回確認します。通常の開発作業に推奨。",
  },
  plan: {
    label: "Plan",
    desc: "Read のみ（Edit 不可）",
    risk: "Low",
    detail: "調査・設計フェーズ向け。コードの閲覧のみ許可し、一切の変更を禁止します。",
  },
  acceptEdits: {
    label: "Accept Edits",
    desc: "Read + Edit 自動承認",
    risk: "Medium",
    detail: "コード生成・プロトタイピング向け。ファイルの読み書きは自動承認し、シェルコマンドは確認します。",
  },
  auto: {
    label: "Auto",
    desc: "全アクション（AI 評価）",
    risk: "Medium",
    detail: "AI 分類器が各操作のリスクを動的に評価。長時間の自律タスク向け。サンドボックスの併用を強く推奨。",
  },
  dontAsk: {
    label: "Don't Ask",
    desc: "Allow ルールのみ実行",
    risk: "Medium",
    detail: "CI/CD パイプライン向け。Allow に定義されたルールのみ実行し、それ以外はすべて拒否します。",
  },
  bypassPermissions: {
    label: "Bypass Permissions",
    desc: "すべて無制限",
    risk: "Critical",
    detail: "全権限チェックを無効化。Docker コンテナ等の完全に隔離された環境でのみ使用してください。",
  },
};

export function ModeSelector() {
  const { settings, setPermissionMode } = useGeneratorStore();
  const currentMode = settings.permissionMode ?? "default";
  const modeInfo = modeDescriptions[currentMode];

  return (
    <Card>
      <CardHeader>
        <div className="flex items-center justify-between">
          <CardTitle>Permission Mode</CardTitle>
          <InfoLink href="permissions#permission-modes" />
        </div>
        <CardDescription>
          エージェントの自動承認範囲を制御するモード
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-3">
        <Select
          value={currentMode}
          onValueChange={(v) => v && setPermissionMode(v as PermissionMode)}
        >
          <SelectTrigger>
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {Object.entries(modeDescriptions).map(([mode, info]) => (
              <SelectItem key={mode} value={mode}>
                <div className="flex items-center gap-2 min-w-0">
                  <span className="font-medium shrink-0">{info.label}</span>
                  <span className="text-muted-foreground text-xs truncate">
                    {info.desc}
                  </span>
                </div>
              </SelectItem>
            ))}
          </SelectContent>
        </Select>

        <div className="flex items-center gap-2 text-sm">
          <span className="text-muted-foreground">Risk:</span>
          <span
            className={
              modeInfo.risk === "Critical"
                ? "font-bold text-red-600"
                : modeInfo.risk === "Medium"
                  ? "font-semibold text-yellow-600"
                  : "font-semibold text-green-600"
            }
          >
            {modeInfo.risk}
          </span>
        </div>

        <p className="text-muted-foreground text-xs leading-relaxed">
          {modeInfo.detail}
        </p>

        {currentMode === "bypassPermissions" && (
          <Alert variant="destructive">
            <AlertDescription className="text-xs">
              このモードはすべてのセキュリティチェックを無効化します。隔離された環境以外では絶対に使用しないでください。
            </AlertDescription>
          </Alert>
        )}
      </CardContent>
    </Card>
  );
}
