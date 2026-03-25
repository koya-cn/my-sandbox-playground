#!/usr/bin/env bash
# examples/basic-workflow.sh
# ai-prov の基本的なワークフローを示すデモスクリプト
#
# 実行方法: bash examples/basic-workflow.sh
# ※ このスクリプトは実際にGitコミットを行わず、説明とコマンド例を表示します

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
DIM='\033[2m'
RESET='\033[0m'

step() {
  echo ""
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}Step $1: $2${RESET}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

cmd() {
  echo -e "${CYAN}\$ $*${RESET}"
}

comment() {
  echo -e "${DIM}# $*${RESET}"
}

note() {
  echo -e "${YELLOW}💡 $*${RESET}"
}

echo ""
echo -e "${BOLD}================================================${RESET}"
echo -e "${BOLD}  AI Provenance ツール - 基本ワークフローデモ  ${RESET}"
echo -e "${BOLD}================================================${RESET}"
echo ""
echo "このデモでは、AIを使ったコーディングセッションの"
echo "記録からコミットまでの流れを説明します。"

# ============================================================
step "1" "初期化（リポジトリで一度だけ実行）"
# ============================================================

echo ""
comment "Gitリポジトリのルートで実行"
cmd "cd /path/to/your-project"
cmd "ai-prov init"
echo ""
echo "これによって以下が設定されます:"
echo "  ✓ .ai-prov/ ディレクトリの作成（セッション保存場所）"
echo "  ✓ .git/hooks/prepare-commit-msg のインストール"
echo "  ✓ .git/hooks/post-commit のインストール"
echo "  ✓ .ai-prov/config.json の作成"

# ============================================================
step "2" "AIでコーディングを始める前にセッション記録を開始"
# ============================================================

echo ""
comment "パターンA: インタラクティブモード（推奨）"
cmd "ai-prov record"
echo ""
echo "  質問内容："
echo "  1. 使用するAIツール（claude-code, cursor, etc.）"
echo "  2. 解決したい問題・タスクの説明"
echo ""
comment "パターンB: クイック開始"
cmd "ai-prov record start"
echo ""
note "セッションIDが発行され .ai-prov/active_session に保存されます"

# ============================================================
step "3" "AIでコーディングを実施"
# ============================================================

echo ""
echo "  ... Claude Code、Cursor、ブラウザ版Claude等を使って..."
echo "  ... コーディング、デバッグ、レビューを実施 ..."
echo ""
note "このフェーズではai-provは何もしません。普通にAIと会話してください。"

# ============================================================
step "4" "変更をステージングしてコミット"
# ============================================================

echo ""
comment "通常のgit addは普通通り"
cmd "git add src/auth/login.js src/auth/middleware.js tests/auth.test.js"
echo ""
comment "ai-prov commit で AI Provenance 付きコミット"
cmd "ai-prov commit -m 'feat: JWT認証のloginエンドポイントを実装'"
echo ""
echo "内部動作:"
echo "  1. アクティブセッションを自動検出"
echo "  2. セッションを確認・終了"
echo "  3. コミットメッセージにトレーラーを追加:"
echo "     AI-Session: a1b2c3d4-e5f6-7890-abcd-ef1234567890"
echo "  4. git commit 実行"
echo "  5. セッションファイルにコミットハッシュを記録"
echo "  6. git notes にセッション全情報を保存"

# ============================================================
step "5" "AI Provenance付きログを確認"
# ============================================================

echo ""
cmd "ai-prov log"
echo ""
echo "  出力例:"
echo -e "  ${GREEN}●${RESET} deadbeef  2026-03-19  feat: JWT認証のloginエンドポイントを実装"
echo -e "    ${GREEN}🤖 AI Provenance${RESET}"
echo "    ツール: claude-code / claude-sonnet-4-6"
echo "    概要:   JWT認証のloginエンドポイントとmiddlewareを実装した"
echo "    タグ:   feature, authentication, security"
echo ""
echo -e "  ${CYAN}○${RESET} abc12345  2026-03-18  chore: package.jsonを更新"
echo ""
comment "プロンプト内容も表示"
cmd "ai-prov log -p"
echo ""
comment "JSON形式で出力（CI/CDツールとの連携用）"
cmd "ai-prov log --json | jq '.[] | select(.session != null)'"

# ============================================================
step "6" "レポートをエクスポート"
# ============================================================

echo ""
comment "HTMLレポートを生成（チームへの共有用）"
cmd "ai-prov export --format html -o report.html"
cmd "open report.html  # または xdg-open report.html"
echo ""
comment "Markdown形式（ドキュメントに含める場合）"
cmd "ai-prov export --format markdown -o docs/ai-provenance.md"
echo ""
comment "CSV形式（スプレッドシート分析用）"
cmd "ai-prov export --format csv | grep 'true' | wc -l"
comment "→ AI支援コミットの数を表示"

# ============================================================
step "7" "応用: 複数セッションにまたがる作業"
# ============================================================

echo ""
echo "大きなリファクタリングなど、複数のコミットが必要な場合:"
echo ""
comment "1日目: リポジトリパターンの基本構造を実装"
cmd "ai-prov record start"
cmd "# ... Claude Code でコーディング ..."
cmd "git add src/repositories/BaseRepository.js"
cmd "ai-prov commit -m 'refactor: BaseRepositoryクラスを追加'"
echo ""
comment "2日目: 各エンティティのリポジトリを実装"
cmd "ai-prov record quick  # 前日の続きをクイック記録"
cmd "git add src/repositories/UserRepository.js"
cmd "ai-prov commit -m 'refactor: UserRepositoryを実装'"
echo ""
note "各コミットに独立したセッションIDが紐付くので、"
note "「このコミットのAIとの会話」を後から追跡できます"

# ============================================================
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}  ワークフロー まとめ${RESET}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo "  AIコーディング前  →  ${BOLD}ai-prov record${RESET}"
echo "  コーディング      →  普通にAIと会話"
echo "  コミット時        →  ${BOLD}ai-prov commit -m '...'${RESET}"
echo "  ログ確認          →  ${BOLD}ai-prov log${RESET}"
echo "  チーム共有        →  ${BOLD}ai-prov export --format html${RESET}"
echo ""
echo "  その他:"
echo "    状態確認:        ${BOLD}ai-prov status${RESET}"
echo "    セッション一覧:  ${BOLD}ai-prov record list${RESET}"
echo ""
