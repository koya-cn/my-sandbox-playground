"use client";

import { PresetSelector } from "@/components/preset-selector/preset-selector";
import { RuleEditor } from "@/components/rule-editor/rule-editor";
import { ModeSelector } from "@/components/mode-selector/mode-selector";
import { SandboxConfig } from "@/components/sandbox-config/sandbox-config";
import { DryRun } from "@/components/dry-run/dry-run";
import { OutputPreview } from "@/components/output-preview/output-preview";
import { Separator } from "@/components/ui/separator";
import { InfoLink } from "@/components/ui/info-link";

export default function Home() {
  return (
    <div className="mx-auto w-full max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      {/* Hero Header */}
      <header className="mb-10">
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-primary text-primary-foreground font-bold text-lg">
              CC
            </div>
            <h1 className="text-3xl font-bold tracking-tight">
              Claude Code Permission Generator
            </h1>
          </div>
          <div className="flex items-center gap-3">
            <InfoLink href="permissions" label="Permissions" />
            <InfoLink href="settings" label="Settings" />
            <InfoLink href="sandboxing" label="Sandbox" />
          </div>
        </div>
        <p className="text-muted-foreground max-w-3xl leading-relaxed">
          Claude Code の権限設定（<code className="text-sm bg-muted px-1.5 py-0.5 rounded">settings.json</code>）を
          GUI で直感的に構成し、ダウンロードできるツールです。
          生成はすべてブラウザ上で完結し、入力データが外部に送信されることはありません。
        </p>
        <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-3">
          <HowItWorksStep
            step={1}
            title="プリセットを選ぶ or ルールを手動追加"
            desc="開発環境に合ったプリセットでベースを設定。カスタムルールの追加も可能です。"
          />
          <HowItWorksStep
            step={2}
            title="モードとサンドボックスを調整"
            desc="動作モード（default / auto / acceptEdits 等）とネットワーク制限を設定します。"
          />
          <HowItWorksStep
            step={3}
            title="Validate & Download"
            desc="設定の整合性を検証し、Dry Run で動作を確認。JSON をコピーまたはダウンロード。"
          />
        </div>
      </header>

      <Separator className="mb-8" />

      <div className="grid gap-8 lg:grid-cols-[1fr_1fr]">
        {/* Left column: Configuration */}
        <div className="space-y-8">
          <SectionHeading
            title="1. Configure"
            desc="権限ルールの構成を設定します"
          />
          <PresetSelector />
          <div className="grid gap-6 sm:grid-cols-2">
            <ModeSelector />
            <SandboxConfig />
          </div>
          <RuleEditor />
        </div>

        {/* Right column: Output & Testing */}
        <div className="space-y-8">
          <SectionHeading
            title="2. Review & Export"
            desc="生成結果の確認とテスト"
          />
          <OutputPreview />
          <DryRun />
        </div>
      </div>

      <footer className="text-muted-foreground mt-16 border-t pt-6 text-center text-sm">
        <p>
          Claude Code Permission Generator v1.0.0 — Client-side only, zero
          external requests.
        </p>
        <p className="mt-1">
          権限の評価順序:{" "}
          <span className="font-medium text-red-500">Deny</span>
          {" > "}
          <span className="font-medium text-yellow-500">Ask</span>
          {" > "}
          <span className="font-medium text-green-500">Allow</span>
          {" > "}
          <span className="font-medium text-muted-foreground">Fallback (Ask)</span>
        </p>
      </footer>
    </div>
  );
}

function HowItWorksStep({
  step,
  title,
  desc,
}: {
  step: number;
  title: string;
  desc: string;
}) {
  return (
    <div className="rounded-lg border bg-card p-4">
      <div className="flex items-center gap-2 mb-1.5">
        <span className="flex h-6 w-6 items-center justify-center rounded-full bg-primary text-primary-foreground text-xs font-bold">
          {step}
        </span>
        <span className="font-medium text-sm">{title}</span>
      </div>
      <p className="text-muted-foreground text-xs leading-relaxed">{desc}</p>
    </div>
  );
}

function SectionHeading({ title, desc }: { title: string; desc: string }) {
  return (
    <div>
      <h2 className="text-lg font-semibold">{title}</h2>
      <p className="text-muted-foreground text-sm">{desc}</p>
    </div>
  );
}
