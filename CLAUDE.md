# Sandbox Playground

## プロジェクト概要
いろいろ試す実験場。ツールやプロトタイプを自由にサブルートとして追加するハブサイト。
Next.js 16 静的エクスポート、GitHub Pages でホスティング。

公開URL: `https://koya-cn.github.io/my-sandbox-playground/`

## ツール一覧

| パス | ツール | 仕様書 |
|------|--------|--------|
| `/permission-generator` | Claude Code Permission Generator | `docs/claude-code-permission-generator-spec.md` |

新しいツールを追加する場合:
1. `src/app/<tool-name>/page.tsx` を作成
2. `src/app/page.tsx` の `tools` 配列にエントリを追加
3. 仕様書を `docs/<tool-name>-spec.md` に作成

## 開発ルール

### 仕様書との同期
- **セッション中に発生した追加要望・設計判断・UI改善は、実装と同時に仕様書にも反映すること**
- 仕様書に記載されていない変更を実装した場合、そのセッション内で仕様書を更新する
- 「あとで仕様書を更新して」とユーザーに言わせない

### JSON出力のフィールド順序
- メタ情報（`_schemaVersion`, `_generatedAt`, `_generatorVersion`）は常にJSONの最上部に配置する
- 設定本体（`permissions`, `permissionMode`, `sandbox`, `autoMode`）はメタ情報の後に配置する

### UI設計原則
- 各セクションのカードヘッダーに公式ドキュメントへの InfoLink を配置する（`code.claude.com/docs/en/` 配下）
- 初心者にもわかるよう、各セクションに説明文を含める
- リスクの高い設定（bypassPermissions 等）には警告アラートを表示する
- パス入力時に構文警告を表示する（`/` 始まりに対する `//` プレフィックスの注意等）
- Select コンポーネントは親幅いっぱい（`w-full`）、テキストオーバーフローは `truncate` で処理

### SSR/Hydration
- 動的な値（タイムスタンプ等）は `useEffect` でクライアント側のみで生成する
- Zustand ストアの関数参照ではなく、データ（`settings` 等）を `useEffect` の依存配列に含める

## 技術スタック
- Next.js 16 (App Router, static export)
- TypeScript strict
- Tailwind CSS 4
- shadcn/ui (base-ui ベース — `asChild` ではなく `render` prop を使用)
- Zustand（状態管理）
- Zod（スキーマバリデーション）
- micromatch（Glob マッチング）

## デプロイ
- **本番**: GitHub Pages（main push で自動デプロイ、`.github/workflows/deploy.yml`）
- **プレビュー**: Vercel（PR ごとに自動プレビューURL）
- `basePath` は本番時のみ `/my-sandbox-playground` を付与

## ディレクトリ構成
```
src/
├── app/
│   ├── page.tsx                  # ツール一覧ハブページ
│   ├── permission-generator/     # Permission Generator ツール
│   │   └── page.tsx
│   ├── layout.tsx
│   └── globals.css
├── components/
│   ├── ui/           # shadcn/ui + info-link.tsx
│   ├── preset-selector/
│   ├── rule-editor/
│   ├── mode-selector/
│   ├── sandbox-config/
│   ├── dry-run/
│   ├── output-preview/
│   └── scope-selector/
├── lib/
│   ├── schema/       # Zod スキーマ + プリセット定義
│   ├── engine/       # rule-evaluator, path-expander, validator, settings-generator
│   └── utils/        # glob-matcher
├── stores/           # Zustand ストア
└── types/            # 型定義
```

## コマンド
```bash
npm run dev    # 開発サーバー (http://localhost:3000)
npm run build  # 静的エクスポート (out/)
```
