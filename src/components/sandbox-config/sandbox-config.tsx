"use client";

import { useState } from "react";
import { useGeneratorStore } from "@/stores/generator-store";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Switch } from "@/components/ui/switch";
import { Label } from "@/components/ui/label";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { InfoLink } from "@/components/ui/info-link";

export function SandboxConfig() {
  const { settings, setSandboxEnabled, setSandboxHosts } = useGeneratorStore();
  const [newHost, setNewHost] = useState("");

  const hosts = settings.sandbox?.allowedHosts ?? [];
  const isEnabled = settings.sandbox?.enabled ?? false;

  const addHost = () => {
    const trimmed = newHost.trim();
    if (trimmed && !hosts.includes(trimmed)) {
      setSandboxHosts([...hosts, trimmed]);
      setNewHost("");
    }
  };

  const removeHost = (host: string) => {
    setSandboxHosts(hosts.filter((h) => h !== host));
  };

  return (
    <Card>
      <CardHeader>
        <div className="flex items-center justify-between">
          <CardTitle>Sandbox</CardTitle>
          <InfoLink href="sandboxing" label="Docs" />
        </div>
        <CardDescription>
          OS レベルでファイルシステムとネットワークを隔離します。
          データ流出防止の重要な防御層です。
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="flex items-center gap-3">
          <Switch
            id="sandbox-enabled"
            checked={isEnabled}
            onCheckedChange={setSandboxEnabled}
          />
          <Label htmlFor="sandbox-enabled">
            {isEnabled ? "Enabled" : "Disabled"}
          </Label>
        </div>

        {isEnabled && (
          <div className="space-y-3">
            <div>
              <Label className="text-sm font-medium">Allowed Hosts</Label>
              <p className="text-muted-foreground text-xs mt-0.5">
                エージェントが通信可能なホストのホワイトリスト。未設定時はすべての外部通信がブロックされます。
              </p>
            </div>
            <div className="flex flex-wrap gap-1.5">
              {hosts.map((host) => (
                <Badge
                  key={host}
                  variant="secondary"
                  className="cursor-pointer gap-1 transition-colors hover:bg-destructive/20"
                  onClick={() => removeHost(host)}
                >
                  {host}
                  <span className="text-muted-foreground ml-1">x</span>
                </Badge>
              ))}
              {hosts.length === 0 && (
                <span className="text-muted-foreground text-xs italic">
                  ホスト未設定（全外部通信ブロック）
                </span>
              )}
            </div>
            <div className="flex gap-2">
              <Input
                value={newHost}
                onChange={(e) => setNewHost(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && addHost()}
                placeholder="例: registry.npmjs.org"
                className="flex-1"
              />
              <Button variant="outline" size="sm" onClick={addHost}>
                Add
              </Button>
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
