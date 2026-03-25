{
  "session_id": "{{SESSION_ID}}",
  "status": "active",
  "started_at": "{{STARTED_AT}}",
  "ended_at": null,

  // 使用したAIツール
  // 選択肢: claude-code, cursor, github-copilot, chatgpt-browser,
  //         claude-browser, gemini, other
  "tool": "{{TOOL}}",

  // モデル名（任意）
  // 例: claude-sonnet-4-6, gpt-4o, gemini-2.0-flash
  "model": "{{MODEL}}",

  // このセッションで解決しようとした問題・タスク
  "problem_statement": "{{PROBLEM_STATEMENT}}",

  // セッション終了時に記入する概要（1文）
  "summary": null,

  // AIとのプロンプトのやり取り（任意、重要なものだけ記録推奨）
  "prompts": [
    // {
    //   "role": "user",             // "user" or "assistant"
    //   "content": "プロンプト内容",
    //   "timestamp": "ISO8601"
    // }
  ],

  // コンテキスト情報
  "context": {
    // セッション開始時に変更されていたファイル
    "files_at_start": [],

    // セッション終了時に変更されたファイル
    "files_at_end": [],

    // 作業ブランチ
    "branch": "{{BRANCH}}",

    // セッション開始時のコミットハッシュ
    "base_commit": "{{BASE_COMMIT}}"
  },

  // 紐付けられたコミットハッシュ（コミット後に自動設定）
  "commit_hash": null,

  // タグ（フィルタリングや検索用）
  // 例: ["feature", "refactor", "bugfix", "performance"]
  "tags": []
}
