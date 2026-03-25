# AI Provenance ツール - アーキテクチャ設計

## 概要

`ai-prov` は、AIを使ったコーディングセッションの文脈（プロンプト、使用ツール、解決しようとした問題）をGitコミットに紐付けて記録・追跡するCLIツールです。

**Cloudflareのケースが示すように**、AIが実装の大部分を担う時代において、「なぜそのコードになったのか」という文脈の保存は将来の保守性に直結します。

---

## 設計原則

### 1. リポジトリを汚さない（Non-Invasive）
- セッションの全データはリポジトリ外（git notes）にも保存
- `.ai-prov/sessions/` はチームで共有できる軽量なJSONファイル
- `exports/` はGit追跡対象外（`.gitignore`）

### 2. 任意参加（Opt-in）
- `--no-session` フラグで従来通りのコミットが可能
- チームメンバーが使わなくてもリポジトリは動作する
- フックは既存フックと共存

### 3. ツール非依存
- Claude Code、Cursor、ブラウザ版など、どのAIツールでも記録可能
- 自動検出を試みるが、手動指定も可能（`AI_PROV_TOOL` 環境変数）

### 4. シンプルなデータ形式
- JSON ベース（人間が読める、jqで処理可能）
- git notes で永続化（ファイルを消してもコミットから復元可能）

---

## ストレージ戦略

ai-prov は **二重ストレージ** を採用しています。

```
コミット
  │
  ├── コミットメッセージ（トレーラー）
  │     AI-Session: <session-id>
  │     ↓ 軽量なポインタ。git logで常に見える
  │
  └── git notes (refs/notes/ai-provenance)
        セッションJSON全体を保存
        ↓ ファイルを失っても復元可能

.ai-prov/sessions/<session-id>.json
  ↓ チームで共有・クエリ可能なファイルストア
```

### なぜコミットメッセージトレーラーを使うのか
- `git log` で直接確認できる
- GitHub/GitLab のUIでも表示される
- `git log --grep="AI-Session:"` でフィルタリング可能
- バックアップ先（リモートリポジトリ）に自動プッシュされる

### なぜ git notes も使うのか
- セッションのフル情報（プロンプト等）をコミットメッセージに入れると肥大化する
- git notes は別のrefに保存されるため、リポジトリの通常の操作に影響しない
- `git log --notes=ai-provenance` で表示可能
- ファイルを失った場合の復元手段

---

## コンポーネント構成

```
ai-prov/
├── bin/
│   └── ai-prov              # エントリポイント（コマンドディスパッチャー）
│
├── lib/
│   ├── utils.sh             # 共通ユーティリティ（色出力、JSON操作、Git操作）
│   └── commands/
│       ├── init.sh          # init: リポジトリ初期化、フックインストール
│       ├── record.sh        # record: セッション記録（start/end/quick/list）
│       ├── commit.sh        # commit: AI Provenance付きコミット
│       ├── log.sh           # log: Provenance付きgit log表示
│       ├── export.sh        # export: レポート生成（MD/JSON/CSV/HTML）
│       └── status.sh        # status: 状態と統計表示
│
├── hooks/
│   ├── prepare-commit-msg   # コミットメッセージにトレーラーを追加
│   └── post-commit          # コミット後にセッション更新・git notes保存
│
├── templates/
│   └── session.json.tpl     # セッションJSONのテンプレート（手動記録用）
│
├── examples/
│   ├── basic-workflow.sh    # ワークフローデモ
│   └── sample-sessions/     # サンプルセッションJSONファイル
│
└── docs/
    ├── architecture.md      # このファイル
    └── format-spec.md       # セッションJSON仕様
```

---

## データフロー

### 正常フロー（ai-prov record + ai-prov commit）

```
開発者                  ai-prov                 Git
    │                      │                      │
    ├─ ai-prov record ─────►│                      │
    │                      │ セッションJSON作成      │
    │                      │ active_session保存     │
    │                      │                      │
    ├─ AIでコーディング ─────►│（何もしない）           │
    │                      │                      │
    ├─ git add ────────────►│（何もしない）           ├─ ステージング
    │                      │                      │
    ├─ ai-prov commit -m ──►│                      │
    │                      ├─ セッション確認          │
    │                      ├─ メッセージにトレーラー追加│
    │                      ├─ git commit ──────────►│ コミット作成
    │                      │                      │
    │                      │   ←── post-commit ────┤
    │                      ├─ セッションJSON更新      │
    │                      ├─ commit_hash記録        │
    │                      ├─ git notes保存 ────────►│ notes更新
    │                      ├─ active_sessionクリア    │
    │                      │                      │
    ◄── 完了通知 ────────────┤                      │
```

### フックのみフロー（git commit を直接使う場合）

```
開発者                  prepare-commit-msg        post-commit
    │                          │                       │
    ├─ git commit -m ──────────►│                       │
    │                          │ active_sessionを確認   │
    │                          │ トレーラーをメッセージ追加│
    │                          │                       │
    │         コミット実行        │                       │
    │                          │                       ├─ セッション更新
    │                          │                       ├─ git notes保存
    ◄── 完了 ────────────────────────────────────────────┤
```

---

## セッションの状態遷移

```
         ai-prov record start
active_session ファイルに保存
              │
              ▼
         ┌─────────┐
         │  active │
         └────┬────┘
              │  ai-prov record end
              │  または ai-prov commit
              ▼
         ┌───────────┐
         │ completed │  ← コミット前（pending state）
         └─────┬─────┘
               │  git commit 実行後（post-commit hook）
               ▼
         ┌───────────┐
         │ committed │  ← commit_hash が記録された最終状態
         └───────────┘
```

---

## git notes の操作

```bash
# ai-provのnotesを表示するようにgit logを設定
git config notes.displayRef "refs/notes/ai-provenance"

# 特定コミットのProvenance情報を表示
git notes --ref=refs/notes/ai-provenance show <commit-hash>

# リモートへのプッシュ（通常は自動プッシュされない）
git push origin refs/notes/ai-provenance

# リモートからのフェッチ
git fetch origin refs/notes/ai-provenance:refs/notes/ai-provenance
```

---

## 設計上のトレードオフ

### プロンプト全文の保存 vs. 要約のみ

**採用**: 両方（要約は必須、プロンプトはオプション）

- 要約（summary）: 必須。後から検索・フィルタリングに使用
- プロンプト（prompts配列）: 任意。重要なものだけ記録推奨
- **理由**: 全プロンプトを強制保存するとノイズ増加、機密情報混入リスク

### .ai-prov/sessions/ をGit追跡するか否か

**採用**: Git追跡する（チームで共有）

- **メリット**: チームメンバーが `git pull` するだけで全員のセッション情報を取得できる
- **デメリット**: リポジトリサイズが増加する
- **緩和策**: exports/ はGit追跡しない（`.gitignore`）

### SQLite vs. JSON ファイル

**採用**: JSON ファイル

- **理由**: 追加依存なし、Git追跡可能、人間が読める、diff が意味を持つ
- **将来**: セッション数が増えた場合は SQLite への移行を検討
