#!/usr/bin/env bash
# lib/commands/status.sh - ai-prov status コマンド
# 現在の状態と統計を表示する

cmd_status() {
  require_initialized

  local prov_dir
  prov_dir="$(prov_dir)"
  local root
  root="$(git_root)"

  echo ""
  bold "=== AI Provenance 状態 ==="
  echo ""

  # ---- アクティブセッション ----
  if [[ -f "${prov_dir}/active_session" ]]; then
    local active_id
    active_id=$(cat "${prov_dir}/active_session")
    local active_file
    active_file="$(session_path "$active_id")"

    echo -e "${GREEN}● アクティブセッション${RESET}"
    if [[ -f "$active_file" ]] && has_jq; then
      local tool started_at problem
      tool=$(jq -r '.tool // "unknown"' "$active_file")
      started_at=$(jq -r '.started_at // ""' "$active_file")
      problem=$(jq -r '.problem_statement // ""' "$active_file")
      echo "  ID:     ${active_id:0:16}..."
      echo "  ツール: ${tool}"
      echo "  開始:   ${started_at:0:19}"
      [[ -n "$problem" ]] && echo "  課題:   ${problem:0:80}"
    else
      echo "  ID: ${active_id}"
    fi
  else
    echo -e "${YELLOW}○ アクティブセッションなし${RESET}"
    echo "  ${BOLD}ai-prov record${RESET} でセッションを開始してください"
  fi

  echo ""

  # ---- リポジトリ統計 ----
  bold "リポジトリ統計:"
  local total_sessions
  total_sessions=$(ls "$(sessions_dir)"/*.json 2>/dev/null | wc -l || echo 0)
  local committed_sessions=0
  local pending_sessions=0

  while IFS= read -r session_id; do
    [[ -z "$session_id" ]] && continue
    local session_file
    session_file="$(session_path "$session_id")"
    if has_jq; then
      local status
      status=$(jq -r '.status // "unknown"' "$session_file")
      [[ "$status" == "committed" ]] && committed_sessions=$((committed_sessions + 1)) || true
      [[ "$status" == "completed" ]] && pending_sessions=$((pending_sessions + 1)) || true
    fi
  done < <(list_session_ids)

  echo "  記録済みセッション: ${total_sessions}"
  echo "  コミット済み:       ${committed_sessions}"
  echo "  未コミット:         ${pending_sessions}"

  echo ""

  # ---- 最近のAI支援コミット ----
  bold "最近のAI支援コミット:"
  local ai_count=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local hash="${line%% *}"
    local subject="${line#* }"
    local session_id
    session_id=$(git --no-pager log --no-notes -1 --pretty=format:"%B" "$hash" 2>/dev/null | \
      grep -oP "(?<=${SESSION_TRAILER}: )[a-f0-9-]+" | head -1)

    if [[ -n "$session_id" ]]; then
      local date_str
      date_str=$(git --no-pager log --no-notes -1 --pretty=format:"%ad" --date=short "$hash")
      echo -e "  ${GREEN}●${RESET} ${hash:0:8}  ${date_str}  ${subject:0:60}"
      ai_count=$((ai_count + 1)) || true
      [[ $ai_count -ge 5 ]] && break
    fi
  done < <(git --no-pager log --no-notes --pretty=format:"%H %s" -n 50 2>/dev/null)

  [[ $ai_count -eq 0 ]] && echo "  （まだAI支援コミットはありません）"

  echo ""

  # ---- 設定確認 ----
  bold "設定:"
  if has_jq && [[ -f "${prov_dir}/config.json" ]]; then
    local auto_record add_trailer use_notes
    auto_record=$(jq -r '.settings.auto_record' "${prov_dir}/config.json")
    add_trailer=$(jq -r '.settings.add_trailer' "${prov_dir}/config.json")
    use_notes=$(jq -r '.settings.use_git_notes' "${prov_dir}/config.json")
    echo "  自動記録:     ${auto_record}"
    echo "  トレーラー:   ${add_trailer}"
    echo "  git notes:    ${use_notes}"
  fi

  echo ""
  bold "クイックコマンド:"
  echo "  ai-prov record        セッションを記録"
  echo "  ai-prov commit -m '…' AIコンテキスト付きコミット"
  echo "  ai-prov log           AI Provenance付きログ"
  echo "  ai-prov export        レポートをエクスポート"
  echo ""
}
