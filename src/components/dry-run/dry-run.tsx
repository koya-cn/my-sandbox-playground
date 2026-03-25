"use client";

import { useGeneratorStore } from "@/stores/generator-store";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { getDecisionBadgeVariant } from "@/lib/engine/rule-evaluator";
import { InfoLink } from "@/components/ui/info-link";

const TOOL_OPTIONS = [
  "Read",
  "Edit",
  "Write",
  "Bash",
  "Glob",
  "Grep",
  "Agent",
  "WebFetch",
];

export function DryRun() {
  const { dryRunInput, dryRunResult, setDryRunInput, runDryRun } =
    useGeneratorStore();

  const isBash = dryRunInput.action === "Bash";

  const handleRun = () => {
    runDryRun(dryRunInput);
  };

  return (
    <Card>
      <CardHeader>
        <div className="flex items-center justify-between">
          <CardTitle>Dry Run</CardTitle>
          <InfoLink href="permissions#manage-permissions" />
        </div>
        <CardDescription>
          設定した権限ルールが特定の操作に対してどう評価されるかをシミュレーションできます。
          ツールとパス（またはコマンド）を入力して Evaluate を押してください。
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-3">
          <div className="space-y-1.5">
            <Label className="text-sm">Tool</Label>
            <Select
              value={dryRunInput.action}
              onValueChange={(v) => v && setDryRunInput({ action: v })}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {TOOL_OPTIONS.map((tool) => (
                  <SelectItem key={tool} value={tool}>
                    {tool}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-1.5">
            <Label className="text-sm">{isBash ? "Command" : "Path"}</Label>
            {isBash ? (
              <Input
                value={dryRunInput.command ?? ""}
                onChange={(e) => setDryRunInput({ command: e.target.value })}
                placeholder="例: npm test"
                onKeyDown={(e) => e.key === "Enter" && handleRun()}
              />
            ) : (
              <Input
                value={dryRunInput.path ?? ""}
                onChange={(e) => setDryRunInput({ path: e.target.value })}
                placeholder="例: .env"
                onKeyDown={(e) => e.key === "Enter" && handleRun()}
              />
            )}
          </div>
        </div>

        <Button onClick={handleRun} className="w-full">
          Evaluate
        </Button>

        {dryRunResult && (
          <div className="rounded-lg border p-4 space-y-3">
            <div className="flex items-center gap-2">
              <span className="text-sm font-medium">Result:</span>
              <Badge
                variant={getDecisionBadgeVariant(dryRunResult.decision)}
                className="text-sm"
              >
                {dryRunResult.decision.toUpperCase()}
              </Badge>
            </div>
            {dryRunResult.matchedRule ? (
              <div className="space-y-1.5">
                <p className="text-xs text-muted-foreground">
                  <span className="font-medium text-foreground">
                    Matched Rule:
                  </span>
                </p>
                <pre className="bg-muted rounded px-3 py-2 text-xs overflow-x-auto break-all whitespace-pre-wrap">
                  {JSON.stringify(dryRunResult.matchedRule, null, 2)}
                </pre>
                <p className="text-xs text-muted-foreground">
                  Source: <code>{dryRunResult.ruleSource}</code>
                </p>
              </div>
            ) : (
              <div className="bg-muted/50 rounded px-3 py-2">
                <p className="text-muted-foreground text-xs">
                  マッチするルールなし。Fail-closed 設計により{" "}
                  <span className="font-medium text-yellow-600">Ask</span>{" "}
                  として評価されます。
                </p>
              </div>
            )}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
