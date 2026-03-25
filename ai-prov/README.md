# ai-prov — AI Provenance ツール

> AIが生成したコードの「文脈（プロンプト・ツール・意図）」をGitコミットに紐付けて記録・追跡するCLIツール

---

## なぜ必要か

[Cloudflareのケース](https://maxemitchell.com/writings/i-read-all-of-cloudflares-claude-generated-commits/)が示すように、AIが実装の90%以上を担うコードベースが現実になりつつあります。しかし、コードを見るだけでは「**なぜそのコードになったのか**」がわかりません。

- どんなプロンプトを送ったのか？
- どのAIツール・モデルを使ったのか？
- 何を解決しようとしていたのか？

`ai-prov` はこの文脈（**AI Provenance**）をGitのコミット履歴と紐付けて保存します。

---

## クイックスタート

```bash
# インストール
bash install.sh

# リポジトリで初期化（一度だけ）
cd your-project
ai-prov init

# AIでコーディングを始める前に
ai-prov record

# ... Claudeや他のAIでコーディング ...

# コミット
git add .
ai-prov commit -m 'feat: 新機能を実装'

# AI Provenance付きログを確認
ai-prov log
```

---

## インストール

```bash
# リポジトリをクローン
git clone <this-repo>
cd ai-prov

# インストール（~/.local/bin/ にシンボリックリンクを作成）
bash install.sh
```

### 前提条件

| ツール | 必須/推奨 | 用途 |
|--------|----------|------|
| bash 4.0+ | 必須 | スクリプト実行 |
| git | 必須 | バージョン管理 |
| jq | **推奨** | JSON処理・詳細表示 |

---

## コマンドリファレンス

### `ai-prov init`

リポジトリをai-provで初期化します。

```bash
ai-prov init
```

- `.ai-prov/` ディレクトリを作成
- Git Hooks（`prepare-commit-msg`, `post-commit`）をインストール
- 設定ファイルを生成

---

### `ai-prov record`

AIセッションを記録します。

```bash
# インタラクティブモード
ai-prov record

# セッション開始（コーディング前）
ai-prov record start

# セッション終了
ai-prov record end

# クイック記録（コーディング後にまとめて記録）
ai-prov record quick

# セッション一覧表示
ai-prov record list

# 特定セッションの詳細
ai-prov record show <session-id>
```

---

### `ai-prov commit`

AI Provenanceメタデータ付きコミットを作成します。

```bash
# 基本（アクティブセッションを自動検出）
ai-prov commit -m 'feat: 機能を追加'

# セッションなしでコミット
ai-prov commit -m 'chore: .gitignoreを更新' --no-session

# 特定のセッションを指定
ai-prov commit -m 'fix: バグを修正' --session <session-id>
```

コミットメッセージに以下のトレーラーが自動追加されます:
```
AI-Session: <session-id>
```

---

### `ai-prov log`

AI Provenance付きgit logを表示します。

```bash
# デフォルト（直近20件）
ai-prov log

# 件数指定
ai-prov log -n 50

# プロンプト内容も表示
ai-prov log -p

# JSON形式
ai-prov log --json

# 一行形式
ai-prov log --oneline
```

**出力例:**
```
● deadbeef  2026-03-19  feat: JWT認証のloginエンドポイントを実装
  🤖 AI Provenance
  ツール: claude-code / claude-sonnet-4-6
  概要:   JWTトークン発行とリフレッシュトークンの仕組みを実装
  タグ:   feature, authentication

○ abc12345  2026-03-18  chore: .gitignoreを更新
```

---

### `ai-prov export`

Provenanceデータをレポートとしてエクスポートします。

```bash
# Markdown形式（デフォルト）
ai-prov export

# HTML形式（ブラウザで表示可能）
ai-prov export --format html

# JSON形式（API・スクリプト連携用）
ai-prov export --format json

# CSV形式（Excel・スプレッドシート用）
ai-prov export --format csv

# 出力先指定
ai-prov export --format html -o report.html

# 対象件数指定
ai-prov export -n 100
```

---

### `ai-prov status`

現在の状態と統計を表示します。

```bash
ai-prov status
```

---

## ワークフロー

### 基本ワークフロー

```
┌─────────────────────────────────────┐
│  1. ai-prov record (セッション開始)   │
│     AIツール・問題を記録               │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  2. AIでコーディング                  │
│     Claude Code / Cursor / ブラウザ  │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  3. git add .                        │
│  4. ai-prov commit -m '...'          │
│     ↓ セッション自動紐付け             │
│     ↓ コミットメッセージにトレーラー追加 │
│     ↓ git notes にJSON保存            │
└─────────────────────────────────────┘
```

### 詳細なワークフローデモ

```bash
bash examples/basic-workflow.sh
```

---

## ストレージ設計

ai-prov は **二重ストレージ** を採用しています:

| 保存先 | 内容 | 目的 |
|--------|------|------|
| `.ai-prov/sessions/*.json` | セッション全情報 | チーム共有・クエリ |
| `git notes (refs/notes/ai-provenance)` | セッション全情報 | バックアップ・復元 |
| コミットメッセージトレーラー | セッションIDのみ | 軽量なリンク |

詳細は [docs/architecture.md](docs/architecture.md) を参照してください。

---

## 環境変数

| 変数名 | 説明 | デフォルト |
|--------|------|-----------|
| `AI_PROV_TOOL` | AIツール名を手動指定（自動検出を上書き） | 自動検出 |

```bash
# 例: Claude Codeを使用していることを明示
export AI_PROV_TOOL=claude-code
```

---

## ディレクトリ構造

```
.ai-prov/                   # リポジトリのProvenance データ
├── config.json             # ツール設定
├── active_session          # 現在アクティブなセッションID
├── sessions/               # セッションJSONファイル群
│   ├── <uuid>.json
│   └── ...
└── exports/                # エクスポートファイル（.gitignore対象）
    └── ...
```

---

## git notes の活用

```bash
# ai-provのnotesをgit logに表示
git config notes.displayRef "refs/notes/ai-provenance"
git log --notes=refs/notes/ai-provenance

# チームへのプッシュ
git push origin refs/notes/ai-provenance

# チームからのフェッチ
git fetch origin refs/notes/ai-provenance:refs/notes/ai-provenance
```

---

## セッション仕様

[docs/format-spec.md](docs/format-spec.md) を参照してください。

---

## ライセンス

MIT
