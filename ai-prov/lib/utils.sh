#!/usr/bin/env bash
# lib/utils.sh - 共通ユーティリティ関数

set -euo pipefail

# ---- 定数 ----
readonly AI_PROV_VERSION="0.1.0"
readonly AI_PROV_NOTES_REF="refs/notes/ai-provenance"
readonly AI_PROV_DIR_NAME=".ai-prov"
readonly SESSION_TRAILER="AI-Session"

# ---- カラー出力 ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${BLUE}[ai-prov]${RESET} $*"; }
success() { echo -e "${GREEN}[ai-prov]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[ai-prov] WARNING:${RESET} $*"; }
error()   { echo -e "${RED}[ai-prov] ERROR:${RESET} $*" >&2; }
bold()    { echo -e "${BOLD}$*${RESET}"; }

# ---- Git ユーティリティ ----

# Gitリポジトリのルートを取得
git_root() {
  git rev-parse --show-toplevel 2>/dev/null || {
    error "Gitリポジトリが見つかりません"
    return 1
  }
}

# ai-prov 設定ディレクトリのパス
prov_dir() {
  echo "$(git_root)/${AI_PROV_DIR_NAME}"
}

# セッションストレージのパス
sessions_dir() {
  echo "$(prov_dir)/sessions"
}

# 初期化済みか確認
is_initialized() {
  [[ -d "$(prov_dir)" ]]
}

require_initialized() {
  if ! is_initialized; then
    error "ai-prov が初期化されていません。先に 'ai-prov init' を実行してください。"
    exit 1
  fi
}

# ---- UUID 生成 ----
generate_id() {
  if command -v uuidgen &>/dev/null; then
    uuidgen | tr '[:upper:]' '[:lower:]'
  else
    # uuidgen がない場合のフォールバック
    printf '%08x-%04x-%04x-%04x-%012x' \
      $RANDOM $RANDOM $RANDOM $RANDOM $((RANDOM * RANDOM * RANDOM))
  fi
}

# ---- タイムスタンプ ----
now_iso() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

now_human() {
  date "+%Y-%m-%d %H:%M:%S %Z"
}

# ---- AI ツール検出 ----
detect_ai_tool() {
  # 環境変数で指定されていればそれを使用
  if [[ -n "${AI_PROV_TOOL:-}" ]]; then
    echo "$AI_PROV_TOOL"
    return
  fi

  # Claude Code の検出
  if [[ -n "${CLAUDE_CODE_SESSION:-}" ]] || [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    echo "claude-code"
    return
  fi

  # Cursor の検出（環境変数やプロセスで判定）
  if [[ -n "${CURSOR_TRACE_ID:-}" ]] || pgrep -x "cursor" &>/dev/null 2>&1; then
    echo "cursor"
    return
  fi

  # GitHub Copilot の検出
  if [[ -n "${GITHUB_COPILOT_SESSION:-}" ]]; then
    echo "github-copilot"
    return
  fi

  echo "unknown"
}

# ---- JSON ユーティリティ ----

# jq が利用可能かチェック
has_jq() {
  command -v jq &>/dev/null
}

# 文字列をJSON安全にエスケープ
json_escape() {
  local str="$1"
  if has_jq; then
    echo "$str" | jq -Rs '.'
  else
    # jq なしの簡易エスケープ
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\t'/\\t}"
    echo "\"${str}\""
  fi
}

# セッションJSONを整形して表示
pretty_json() {
  if has_jq; then
    jq '.'
  else
    cat
  fi
}

# ---- セッションファイル管理 ----

session_path() {
  local session_id="$1"
  echo "$(sessions_dir)/${session_id}.json"
}

# セッションIDの一覧を取得（新しい順）
list_session_ids() {
  local dir
  dir="$(sessions_dir)"
  if [[ -d "$dir" ]]; then
    ls -t "${dir}"/*.json 2>/dev/null | xargs -I{} basename {} .json
  fi
}

# セッションJSONからフィールドを取得
session_field() {
  local session_file="$1"
  local field="$2"

  if has_jq; then
    jq -r ".${field} // empty" "$session_file"
  else
    # 簡易grep版（フォールバック）
    grep -o "\"${field}\": *\"[^\"]*\"" "$session_file" | \
      sed 's/.*": *"\(.*\)"/\1/' | head -1
  fi
}

# ---- Git Notes ユーティリティ ----

# コミットにノートを追加
add_note() {
  local commit_hash="$1"
  local content="$2"
  git notes --ref="$AI_PROV_NOTES_REF" add -f -m "$content" "$commit_hash" 2>/dev/null
}

# コミットのノートを取得
get_note() {
  local commit_hash="$1"
  git notes --ref="$AI_PROV_NOTES_REF" show "$commit_hash" 2>/dev/null || echo ""
}

# ---- コミットメッセージトレーラー ----

# トレーラーを追加したコミットメッセージを返す
add_trailer() {
  local msg="$1"
  local session_id="$2"
  printf '%s\n\n%s: %s\n' "$msg" "$SESSION_TRAILER" "$session_id"
}

# コミットメッセージからセッションIDを抽出
extract_session_id() {
  local msg="$1"
  echo "$msg" | grep -oP "(?<=${SESSION_TRAILER}: )[a-f0-9-]+" | head -1
}

# ---- インタラクティブ入力 ----

# プロンプトして入力を受け取る（デフォルト値付き）
prompt_input() {
  local question="$1"
  local default="${2:-}"
  local answer

  if [[ -n "$default" ]]; then
    echo -en "${CYAN}${question}${RESET} [${default}]: "
  else
    echo -en "${CYAN}${question}${RESET}: "
  fi

  read -r answer
  echo "${answer:-$default}"
}

# 選択肢から選ぶ
prompt_select() {
  local question="$1"
  shift
  local options=("$@")

  echo -e "${CYAN}${question}${RESET}"
  for i in "${!options[@]}"; do
    echo "  $((i+1)). ${options[$i]}"
  done
  echo -en "選択 [1-${#options[@]}]: "

  local choice
  read -r choice
  echo "${options[$((choice-1))]}"
}

# Yes/No 確認
confirm() {
  local question="$1"
  local default="${2:-y}"
  local answer

  if [[ "$default" == "y" ]]; then
    echo -en "${CYAN}${question}${RESET} [Y/n]: "
  else
    echo -en "${CYAN}${question}${RESET} [y/N]: "
  fi

  read -r answer
  answer="${answer:-$default}"
  [[ "$answer" =~ ^[Yy]$ ]]
}
