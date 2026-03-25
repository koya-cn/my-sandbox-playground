import Link from "next/link";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

interface ToolCard {
  title: string;
  description: string;
  href: string;
  status: "stable" | "beta" | "coming-soon";
  tags: string[];
}

const tools: ToolCard[] = [
  {
    title: "Permission Generator",
    description:
      "Claude Code の権限ルール（settings.json）を GUI で直感的に構成し、ダウンロードできるツール。プリセット、Dry Run、バリデーション機能付き。",
    href: "/permission-generator",
    status: "stable",
    tags: ["Security", "Settings", "Claude Code"],
  },
];

const statusConfig = {
  stable: { label: "Stable", className: "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200" },
  beta: { label: "Beta", className: "bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200" },
  "coming-soon": { label: "Coming Soon", className: "bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400" },
};

export default function Home() {
  return (
    <div className="mx-auto w-full max-w-4xl px-4 py-12 sm:px-6 lg:px-8">
      <header className="mb-12 text-center">
        <div className="flex items-center justify-center gap-3 mb-4">
          <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-primary text-primary-foreground font-bold text-xl">
            SB
          </div>
          <h1 className="text-4xl font-bold tracking-tight">
            Sandbox Playground
          </h1>
        </div>
        <p className="text-muted-foreground text-lg max-w-2xl mx-auto">
          いろいろ試す実験場。ツールやプロトタイプを自由に置いています。
        </p>
      </header>

      <div className="grid gap-4 sm:grid-cols-2">
        {tools.map((tool) => {
          const status = statusConfig[tool.status];
          const isClickable = tool.status !== "coming-soon";

          const card = (
            <Card
              className={`transition-all ${isClickable ? "hover:border-primary/50 hover:shadow-md cursor-pointer" : "opacity-60"}`}
            >
              <CardHeader>
                <div className="flex items-center justify-between">
                  <CardTitle className="text-lg">{tool.title}</CardTitle>
                  <span
                    className={`rounded-full px-2.5 py-0.5 text-xs font-medium ${status.className}`}
                  >
                    {status.label}
                  </span>
                </div>
                <CardDescription className="leading-relaxed">
                  {tool.description}
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="flex flex-wrap gap-1.5">
                  {tool.tags.map((tag) => (
                    <Badge key={tag} variant="secondary" className="text-xs">
                      {tag}
                    </Badge>
                  ))}
                </div>
              </CardContent>
            </Card>
          );

          if (!isClickable) return <div key={tool.href}>{card}</div>;

          return (
            <Link key={tool.href} href={tool.href} className="no-underline">
              {card}
            </Link>
          );
        })}

        {/* Placeholder for future tools */}
        <Card className="border-dashed opacity-50">
          <CardHeader>
            <CardTitle className="text-lg text-muted-foreground">
              + New Tool
            </CardTitle>
            <CardDescription>
              次のツールがここに追加されます
            </CardDescription>
          </CardHeader>
        </Card>
      </div>

      <footer className="text-muted-foreground mt-16 text-center text-sm">
        <p>Sandbox Playground</p>
      </footer>
    </div>
  );
}
