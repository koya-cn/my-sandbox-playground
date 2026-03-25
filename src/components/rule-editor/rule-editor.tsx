"use client";

import { useGeneratorStore } from "@/stores/generator-store";
import type { PermissionAction } from "@/types/settings";
import { PermissionRow } from "./permission-row";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { InfoLink } from "@/components/ui/info-link";

const actionConfig: Record<
  PermissionAction,
  {
    label: string;
    description: string;
    detail: string;
    variant: "destructive" | "outline" | "default";
    color: string;
  }
> = {
  deny: {
    label: "Deny",
    description: "拒否（最優先）",
    detail:
      "ここに追加したルールは最優先で評価され、マッチした操作は無条件にブロックされます。機密ファイル（.env, .ssh 等）や破壊的コマンド（rm -rf 等）の保護に使います。",
    variant: "destructive",
    color: "text-red-600",
  },
  ask: {
    label: "Ask",
    description: "確認を要求",
    detail:
      "マッチした操作は実行前にユーザーへの確認プロンプトを表示します。git push のような不可逆操作や、pip install のような副作用のある操作に適しています。",
    variant: "outline",
    color: "text-yellow-600",
  },
  allow: {
    label: "Allow",
    description: "自動許可",
    detail:
      "マッチした操作は確認なしで自動実行されます。npm test やファイル読み取りなど、低リスクの定型作業を登録します。",
    variant: "default",
    color: "text-green-600",
  },
};

export function RuleEditor() {
  const { settings, addRule, removeRule, updateRule } = useGeneratorStore();

  const renderRuleList = (action: PermissionAction) => {
    const rules = settings.permissions[action];
    return (
      <div className="space-y-2">
        {rules.map((rule, index) => (
          <PermissionRow
            key={`${action}-${index}`}
            rule={rule}
            onChange={(updated) => updateRule(action, index, updated)}
            onRemove={() => removeRule(action, index)}
          />
        ))}
        {rules.length === 0 && (
          <p className="text-muted-foreground py-6 text-center text-sm">
            ルールが未定義です。下のボタンから追加できます。
          </p>
        )}
        <Button
          variant="outline"
          size="sm"
          className="w-full"
          onClick={() => addRule(action, { tool: "Read", path: "" })}
        >
          + Add Rule
        </Button>
      </div>
    );
  };

  return (
    <Card>
      <CardHeader>
        <div className="flex items-center justify-between">
          <CardTitle>Permission Rules</CardTitle>
          <InfoLink href="permissions#permission-rule-syntax" label="Docs" />
        </div>
        <CardDescription>
          各ツール操作に対する権限ルールを定義します。
          評価順序は <span className="font-medium text-red-500">Deny</span> &gt;{" "}
          <span className="font-medium text-yellow-500">Ask</span> &gt;{" "}
          <span className="font-medium text-green-500">Allow</span> &gt; Fallback (Ask)
          です。どのルールにもマッチしない場合は Ask として扱われます（Fail-closed）。
        </CardDescription>
      </CardHeader>
      <CardContent>
        <Tabs defaultValue="deny">
          <TabsList className="w-full">
            {(["deny", "ask", "allow"] as PermissionAction[]).map((action) => (
              <TabsTrigger
                key={action}
                value={action}
                className="flex-1 gap-2"
              >
                <span className={actionConfig[action].color}>
                  {actionConfig[action].label}
                </span>
                <Badge variant="secondary" className="text-xs">
                  {settings.permissions[action].length}
                </Badge>
              </TabsTrigger>
            ))}
          </TabsList>
          {(["deny", "ask", "allow"] as PermissionAction[]).map((action) => (
            <TabsContent key={action} value={action} className="mt-4">
              <div className="bg-muted/50 rounded-md px-3 py-2 mb-4">
                <p className="text-muted-foreground text-xs leading-relaxed">
                  {actionConfig[action].detail}
                </p>
              </div>
              {renderRuleList(action)}
            </TabsContent>
          ))}
        </Tabs>
      </CardContent>
    </Card>
  );
}
