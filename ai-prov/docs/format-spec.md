# AI Provenance セッション JSON 仕様

バージョン: 0.1.0

---

## 概要

ai-prov のセッションデータは JSON 形式で保存されます。
ファイルは `.ai-prov/sessions/<session-id>.json` に配置されます。

---

## スキーマ

```json
{
  "session_id": "string (UUID v4)",
  "status": "active | completed | committed",
  "started_at": "string (ISO 8601 UTC)",
  "ended_at": "string (ISO 8601 UTC) | null",
  "tool": "string",
  "model": "string | null",
  "problem_statement": "string",
  "summary": "string | null",
  "prompts": [Prompt],
  "context": Context,
  "commit_hash": "string (40-char hex) | null",
  "tags": ["string"]
}
```

---

## フィールド定義

### `session_id` (必須)
- 型: `string`
- 形式: UUID v4（例: `a1b2c3d4-e5f6-7890-abcd-ef1234567890`）
- セッションの一意識別子。`ai-prov record` で自動生成される。

### `status` (必須)
- 型: `string (enum)`
- 値:
  - `"active"` — セッション進行中（コーディング中）
  - `"completed"` — セッション終了済み（未コミット）
  - `"committed"` — コミット済み（最終状態）

### `started_at` (必須)
- 型: `string`
- 形式: ISO 8601 UTC（例: `"2026-03-19T09:00:00Z"`）
- セッション開始時刻

### `ended_at`
- 型: `string | null`
- 形式: ISO 8601 UTC
- セッション終了時刻。`"active"` 状態では `null`。

### `tool` (必須)
- 型: `string`
- 標準値:
  | 値 | 説明 |
  |----|------|
  | `"claude-code"` | Claude Code CLI |
  | `"cursor"` | Cursor IDE |
  | `"github-copilot"` | GitHub Copilot |
  | `"chatgpt-browser"` | ChatGPT（ブラウザ版）|
  | `"claude-browser"` | Claude.ai（ブラウザ版）|
  | `"gemini"` | Google Gemini |
  | `"other"` | その他 |
  | `"unknown"` | 不明（自動検出失敗）|

### `model`
- 型: `string | null`
- 使用したAIモデル名。任意入力。
- 例: `"claude-sonnet-4-6"`, `"gpt-4o"`, `"gemini-2.0-flash"`

### `problem_statement` (必須)
- 型: `string`
- このセッションで解決しようとした問題・タスクの説明。
- 自然言語で記述。マークダウン可。
- セッション開始時に入力。

### `summary`
- 型: `string | null`
- セッションで実施したことの1文概要。
- セッション終了時に入力。`"active"` 状態では `null`。
- **検索・一覧表示に使用されるため、簡潔に記述すること。**

### `prompts`
- 型: `Prompt[]`（配列）
- AIとのやり取りの記録。任意。重要なプロンプトのみ記録推奨。

#### Prompt オブジェクト
```json
{
  "role": "user | assistant",
  "content": "string",
  "timestamp": "string (ISO 8601 UTC)"
}
```

- `role`: `"user"` はユーザーの入力、`"assistant"` はAIの出力
- `content`: プロンプトの内容
- `timestamp`: そのプロンプトを送った時刻

### `context` (必須)
- 型: `Context` オブジェクト

#### Context オブジェクト
```json
{
  "files_at_start": ["string"] | null,
  "files_at_end": ["string"] | null,
  "branch": "string",
  "base_commit": "string (40-char hex) | 'unknown'"
}
```

- `files_at_start`: セッション開始時に変更されていたファイルのリスト
- `files_at_end`: セッション終了時に変更されたファイルのリスト
- `branch`: 作業ブランチ名
- `base_commit`: セッション開始時の HEAD コミットハッシュ

### `commit_hash`
- 型: `string | null`
- 形式: 40文字の16進数
- 紐付けられたコミットのハッシュ。`post-commit` フックで自動設定。

### `tags`
- 型: `string[]`
- フィルタリングや検索のための任意タグ。
- 推奨タグ: `feature`, `bugfix`, `refactor`, `performance`, `security`, `docs`, `test`

---

## コミットメッセージトレーラー仕様

コミットメッセージには以下のトレーラーが追加されます:

```
<コミットメッセージ>

AI-Session: <session-id>
```

### 例

```
feat: JWT認証のloginエンドポイントを実装

JWTトークンの発行とリフレッシュトークンの仕組みを追加。

AI-Session: a1b2c3d4-e5f6-7890-abcd-ef1234567890
Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

---

## バージョン履歴

| バージョン | 変更内容 |
|-----------|---------|
| 0.1.0     | 初版リリース |

---

## 将来の拡張予定

- `cost_usd`: APIコスト記録
- `token_count`: 使用トークン数
- `parent_session`: 関連するセッションへの参照（ブランチをまたぐ作業）
- `external_ref`: 外部サービス（Linear, Jira等）のチケット参照
