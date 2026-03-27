# Sandbox Playground

いろいろ試す実験場。ツールやプロトタイプを自由にサブルートとして追加できるハブサイト。

**公開URL**: https://koya-cn.github.io/my-sandbox-playground/

## ツール一覧

| ツール | パス | ステータス |
|--------|------|-----------|
| [Permission Generator](#permission-generator) | `/permission-generator` | Stable |

### Permission Generator

Claude Code の権限ルール（`settings.json`）を GUI で直感的に構成し、ダウンロードできるツール。

**主な機能:**
- プリセット選択（Minimal / Standard / Strict / Custom）
- スコープ選択（User / Project / Enterprise managed）
- Allow / Deny / Ask ルールの GUI 編集
- Glob パターンのバリデーションと構文警告
- Dry Run（実際のファイルシステムに対してルールをテスト）
- JSON プレビューとダウンロード

## 技術スタック

| 項目 | 詳細 |
|------|------|
| フレームワーク | Next.js 16 (App Router, static export) |
| 言語 | TypeScript (strict) |
| スタイル | Tailwind CSS 4 |
| UI コンポーネント | shadcn/ui (base-ui ベース) |
| 状態管理 | Zustand |
| バリデーション | Zod |
| Glob マッチング | micromatch |

## セットアップ

```bash
# 依存関係のインストール
npm install

# 開発サーバー起動
npm run dev
# → http://localhost:3000

# 静的ビルド
npm run build
# → out/ ディレクトリに出力
```

## デプロイ

- **本番 (GitHub Pages)**: `main` ブランチへの push で自動デプロイ（`.github/workflows/deploy.yml`）
- **プレビュー (Vercel)**: PR ごとに自動でプレビュー URL を生成

## 新しいツールの追加

1. `src/app/<tool-name>/page.tsx` を作成
2. `src/app/page.tsx` の `tools` 配列にエントリを追加
3. 仕様書を `docs/<tool-name>-spec.md` に作成

## ディレクトリ構成

```
src/
├── app/
│   ├── page.tsx                  # ツール一覧ハブページ
│   ├── permission-generator/     # Permission Generator ツール
│   ├── layout.tsx
│   └── globals.css
├── components/
│   ├── ui/                       # shadcn/ui + info-link.tsx
│   ├── preset-selector/
│   ├── rule-editor/
│   ├── mode-selector/
│   ├── sandbox-config/
│   ├── dry-run/
│   ├── output-preview/
│   └── scope-selector/
├── lib/
│   ├── schema/                   # Zod スキーマ + プリセット定義
│   ├── engine/                   # rule-evaluator, path-expander, validator, settings-generator
│   └── utils/                    # glob-matcher
├── stores/                       # Zustand ストア
└── types/                        # 型定義
docs/
└── claude-code-permission-generator-spec.md
```
