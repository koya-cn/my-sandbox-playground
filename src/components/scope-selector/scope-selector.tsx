"use client";

import { useGeneratorStore, SCOPES } from "@/stores/generator-store";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";

export function ScopeSelector() {
  const { selectedScope, setScope, includeMetadata, setIncludeMetadata } =
    useGeneratorStore();

  return (
    <div className="space-y-3">
      <div className="space-y-1.5">
        <Label className="text-sm font-medium">Output Scope</Label>
        <p className="text-muted-foreground text-xs">
          設定ファイルの配置先を選択します。上位スコープほど優先度が高くなります。
        </p>
        <Select
          value={selectedScope.id}
          onValueChange={(v) => {
            if (!v) return;
            const scope = SCOPES.find((s) => s.id === v);
            if (scope) setScope(scope);
          }}
        >
          <SelectTrigger>
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {SCOPES.map((scope) => (
              <SelectItem key={scope.id} value={scope.id}>
                <div className="flex flex-col min-w-0">
                  <span className="font-medium text-sm">{scope.label}</span>
                  <span className="text-muted-foreground text-xs truncate">
                    {scope.path}
                  </span>
                </div>
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>
      <div className="flex items-center gap-2">
        <Switch
          id="include-metadata"
          checked={includeMetadata}
          onCheckedChange={setIncludeMetadata}
        />
        <div>
          <Label htmlFor="include-metadata" className="text-sm">
            Metadata を含める
          </Label>
          <p className="text-muted-foreground text-xs">
            生成日時・バージョン情報を JSON に付与
          </p>
        </div>
      </div>
    </div>
  );
}
