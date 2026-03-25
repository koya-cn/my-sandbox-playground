"use client";

import { presets } from "@/lib/schema/presets";
import { useGeneratorStore } from "@/stores/generator-store";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { InfoLink } from "@/components/ui/info-link";

const categoryLabels: Record<string, string> = {
  frontend: "Frontend",
  backend: "Backend",
  security: "Security",
  experimental: "Experimental",
  addon: "Add-on",
};

const categoryColors: Record<string, string> = {
  frontend: "bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200",
  backend: "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200",
  security: "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200",
  experimental:
    "bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-200",
  addon: "bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-200",
};

const basePresets = presets.filter((p) => p.type !== "addon");
const addonPresets = presets.filter((p) => p.type === "addon");

export function PresetSelector() {
  const { selectedPresetId, appliedAddonIds, applyPreset, mergePreset, unmergePreset, clearAll } =
    useGeneratorStore();

  return (
    <Card>
      <CardHeader>
        <div className="flex items-center justify-between">
          <CardTitle>Presets</CardTitle>
          <InfoLink href="permissions#example-configurations" label="Examples" />
        </div>
        <CardDescription>
          開発環境に合ったプリセットを選択すると、推奨される権限ルールが自動設定されます。
          プリセット適用後にルールの追加・削除も可能です。
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
          {basePresets.map((preset) => {
            const isSelected = selectedPresetId === preset.id;
            const ruleCount =
              preset.settings.permissions.allow.length +
              preset.settings.permissions.deny.length +
              preset.settings.permissions.ask.length;
            return (
              <Button
                key={preset.id}
                variant={isSelected ? "default" : "outline"}
                size="sm"
                className="h-auto flex-col items-start gap-1.5 py-3 text-left overflow-hidden whitespace-normal"
                onClick={() => applyPreset(preset.id)}
              >
                <div className="flex w-full items-center justify-between gap-1 min-w-0">
                  <span className="font-medium truncate">{preset.name}</span>
                  <span
                    className={`shrink-0 rounded px-1.5 py-0.5 text-[10px] font-medium ${categoryColors[preset.category]}`}
                  >
                    {categoryLabels[preset.category]}
                  </span>
                </div>
                <span className="text-muted-foreground text-xs font-normal leading-relaxed">
                  {preset.description}
                </span>
                <Badge variant="secondary" className="text-[10px] mt-0.5">
                  {ruleCount} rules
                </Badge>
              </Button>
            );
          })}
        </div>

        {addonPresets.length > 0 && (
          <div className="space-y-2">
            <p className="text-xs font-medium text-muted-foreground">
              Add-on — 既存ルールにマージして追加できます
            </p>
            <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
              {addonPresets.map((preset) => {
                const isApplied = appliedAddonIds.includes(preset.id);
                const ruleCount =
                  preset.settings.permissions.allow.length +
                  preset.settings.permissions.deny.length +
                  preset.settings.permissions.ask.length;
                return (
                  <Button
                    key={preset.id}
                    variant={isApplied ? "default" : "outline"}
                    size="sm"
                    className="h-auto flex-col items-start gap-1.5 py-3 text-left overflow-hidden whitespace-normal"
                    onClick={() =>
                      isApplied
                        ? unmergePreset(preset.id)
                        : mergePreset(preset.id)
                    }
                  >
                    <div className="flex w-full items-center justify-between gap-1 min-w-0">
                      <span className="font-medium truncate">
                        {isApplied ? "- " : "+ "}
                        {preset.name}
                      </span>
                      <span
                        className={`shrink-0 rounded px-1.5 py-0.5 text-[10px] font-medium ${categoryColors[preset.category]}`}
                      >
                        {categoryLabels[preset.category]}
                      </span>
                    </div>
                    <span className="text-muted-foreground text-xs font-normal leading-relaxed">
                      {preset.description}
                    </span>
                    <Badge variant="secondary" className="text-[10px] mt-0.5">
                      {ruleCount} rules
                    </Badge>
                  </Button>
                );
              })}
            </div>
          </div>
        )}

        <Button
          variant="ghost"
          size="sm"
          className="w-full"
          onClick={clearAll}
        >
          Clear All
        </Button>
      </CardContent>
    </Card>
  );
}
