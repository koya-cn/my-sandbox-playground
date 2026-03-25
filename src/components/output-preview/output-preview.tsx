"use client";

import { useEffect, useState } from "react";
import { useGeneratorStore } from "@/stores/generator-store";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Switch } from "@/components/ui/switch";
import { ScopeSelector } from "@/components/scope-selector/scope-selector";
import { InfoLink } from "@/components/ui/info-link";

export function OutputPreview() {
  const { settings, includeMetadata, generateOutput, validate, validationIssues, selectedScope, setLanguage } =
    useGeneratorStore();
  const [copied, setCopied] = useState(false);
  const [output, setOutput] = useState("{}");

  useEffect(() => {
    setOutput(JSON.stringify(generateOutput(), null, 2));
  }, [settings, includeMetadata, generateOutput]);

  const handleCopy = async () => {
    await navigator.clipboard.writeText(output);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleDownload = () => {
    const blob = new Blob([output], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    const filename = selectedScope.path.split("/").pop() ?? "settings.json";
    a.download = filename;
    a.click();
    URL.revokeObjectURL(url);
  };

  const handleValidate = () => {
    validate();
  };

  const errorCount = validationIssues.filter(
    (i) => i.severity === "error"
  ).length;
  const warningCount = validationIssues.filter(
    (i) => i.severity === "warning"
  ).length;

  return (
    <Card>
      <CardHeader>
        <div className="flex items-center justify-between">
          <CardTitle>Output</CardTitle>
          <InfoLink href="settings#settings-files" label="Settings Files" />
        </div>
        <CardDescription>
          生成された設定ファイルのプレビューです。
          Validate ボタンで論理的な矛盾やセキュリティ上の懸念をチェックできます。
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <ScopeSelector />

        <div className="flex items-center justify-between rounded-md border px-3 py-2">
          <div className="space-y-0.5">
            <label htmlFor="language-toggle" className="text-sm font-medium">
              Language
            </label>
            <p className="text-xs text-muted-foreground">
              応答言語を日本語に設定します
            </p>
          </div>
          <Switch
            id="language-toggle"
            checked={settings.language === "日本語"}
            onCheckedChange={(checked: boolean) =>
              setLanguage(checked ? "日本語" : undefined)
            }
          />
        </div>

        <div className="flex flex-wrap gap-2">
          <Button variant="outline" size="sm" onClick={handleValidate}>
            Validate
            {validationIssues.length > 0 && (
              <Badge variant="secondary" className="ml-1.5">
                {validationIssues.length}
              </Badge>
            )}
          </Button>
          <Button variant="outline" size="sm" onClick={handleCopy}>
            {copied ? "Copied!" : "Copy JSON"}
          </Button>
          <Button variant="outline" size="sm" onClick={handleDownload}>
            Download
          </Button>
        </div>

        {validationIssues.length > 0 && (
          <div className="space-y-2">
            <div className="flex gap-2 text-xs">
              {errorCount > 0 && (
                <Badge variant="destructive">{errorCount} errors</Badge>
              )}
              {warningCount > 0 && (
                <Badge variant="outline">{warningCount} warnings</Badge>
              )}
            </div>
            {validationIssues.map((issue, i) => (
              <Alert
                key={i}
                variant={issue.severity === "error" ? "destructive" : "default"}
              >
                <AlertDescription className="flex items-start gap-2 text-xs">
                  <Badge
                    variant={
                      issue.severity === "error" ? "destructive" : "outline"
                    }
                    className="shrink-0 mt-0.5"
                  >
                    {issue.severity}
                  </Badge>
                  <span>{issue.message}</span>
                </AlertDescription>
              </Alert>
            ))}
          </div>
        )}

        <ScrollArea className="h-80 w-full">
          <pre className="bg-muted rounded-lg p-4 text-xs font-mono leading-relaxed overflow-x-auto break-all">
            <code>{output}</code>
          </pre>
        </ScrollArea>

        <div className="rounded-lg border-2 border-primary/20 bg-primary/5 px-4 py-3 space-y-1.5">
          <div className="flex items-center gap-2">
            <span className="text-sm font-semibold text-primary">Output path</span>
            <Badge variant="outline" className="text-[10px]">
              {selectedScope.label}
            </Badge>
          </div>
          <code className="block text-sm font-mono font-medium text-foreground">
            {selectedScope.path}
          </code>
          <p className="text-xs text-muted-foreground">
            このファイルを上記のパスに配置してください。Git 管理する場合は{" "}
            <code className="font-medium">.claude/settings.json</code>（Shared Project）を使用します。
          </p>
        </div>
      </CardContent>
    </Card>
  );
}
