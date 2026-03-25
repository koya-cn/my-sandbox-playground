#!/usr/bin/env bash
# lib/commands/record.sh - ai-prov record コマンド
# AIセッションの開始・終了を記録する

cmd_record() {
  require_initialized

  local mode="${1:-start}"  # start | end | quick

  case "$mode" in
    start|new)  record_start ;;
    end|close)  record_end "$2" ;;
    quick|q)    record_quick ;;
    show)       record_show "${2:-}" ;;
    list)       record_list ;;
    *)
      # 引数なしはインタラクティブモード
      record_interactive
      ;;
  esac
}

# ---- インタラクティブモード（引数なし）----
record_interactive() {
  echo ""
  bold "=== AI セッション記録 ==="
  echo ""

  local action
  action=$(prompt_select "何をしますか？" \
    "新しいセッションを開始" \
    "進行中のセッションを終了" \
    "クイック記録（過去のやり取りをまとめて記録）" \
    "セッション一覧を表示")

  case "$action" in
    "新しいセッションを開始")     record_start ;;
    "進行中のセッションを終了")   record_end "" ;;
    "クイック記録（過去のやり取りをまとめて記録）") record_quick ;;
    "セッション一覧を表示")       record_list ;;
  esac
}

# ---- セッション開始 ----
record_start() {
  local session_id
  session_id="$(generate_id)"
  local session_file
  session_file="$(session_path "$session_id")"

  echo ""
  bold "=== AIセッション開始記録 ==="
  echo ""

  # AIツール選択
  local detected_tool
  detected_tool="$(detect_ai_tool)"
  local tool
  tool=$(prompt_select "使用するAIツールを選択してください" \
    "claude-code" \
    "cursor" \
    "github-copilot" \
    "chatgpt-browser" \
    "claude-browser" \
    "gemini" \
    "other")

  # モデル名（任意）
  local model
  model=$(prompt_input "モデル名（任意）" "")

  # このセッションで解決したい問題
  echo ""
  echo -e "${CYAN}このAIセッションで解決したい問題・タスクを説明してください:${RESET}"
  echo "（複数行入力可。空行を2回入力で確定）"
  local problem
  problem=$(read_multiline)

  # 関連ファイル
  local changed_files
  changed_files=$(git --no-pager diff --name-only HEAD 2>/dev/null | tr '\n' ',' | sed 's/,$//')

  # セッション記録ファイルを作成
  mkdir -p "$(sessions_dir)"
  cat > "$session_file" << EOF
{
  "session_id": "${session_id}",
  "status": "active",
  "started_at": "$(now_iso)",
  "ended_at": null,
  "tool": "${tool}",
  "model": "${model}",
  "problem_statement": $(json_escape "$problem"),
  "summary": null,
  "prompts": [],
  "context": {
    "files_at_start": $(files_to_json "$changed_files"),
    "files_at_end": null,
    "branch": "$(git --no-pager rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')",
    "base_commit": "$(git --no-pager rev-parse HEAD 2>/dev/null || echo 'unknown')"
  },
  "commit_hash": null,
  "tags": []
}
EOF

  # アクティブセッションとして保存
  echo "$session_id" > "$(prov_dir)/active_session"

  echo ""
  success "セッションを開始しました"
  echo "  セッションID: ${BOLD}${session_id}${RESET}"
  echo "  ファイル: ${session_file}"
  echo ""
  echo "  AIとのやり取りが終わったら:"
  echo "    ${BOLD}ai-prov record end${RESET}"
  echo "  または、コミット時に自動で終了されます:"
  echo "    ${BOLD}ai-prov commit -m 'コミットメッセージ'${RESET}"
}

# ---- セッション終了 ----
record_end() {
  local session_id="${1:-}"

  # 引数なしならアクティブセッションを使用
  if [[ -z "$session_id" ]]; then
    local active_file
    active_file="$(prov_dir)/active_session"
    if [[ -f "$active_file" ]]; then
      session_id=$(cat "$active_file")
    else
      error "アクティブなセッションが見つかりません"
      echo "セッションIDを指定してください: ai-prov record end <session-id>"
      return 1
    fi
  fi

  local session_file
  session_file="$(session_path "$session_id")"

  if [[ ! -f "$session_file" ]]; then
    error "セッションファイルが見つかりません: ${session_id}"
    return 1
  fi

  echo ""
  bold "=== AIセッション終了記録 ==="
  echo ""

  # セッション概要
  echo -e "${CYAN}このセッションで行ったことの概要を入力してください:${RESET}"
  echo "（ワンライナーで簡潔に）"
  local summary
  read -r summary

  # 主要プロンプトを記録（任意）
  echo ""
  if confirm "主要なプロンプト/指示を記録しますか？（後で参照できます）" "y"; then
    record_prompts "$session_file"
  fi

  # タグ
  local tags
  tags=$(prompt_input "タグ（カンマ区切り、任意）" "")

  # 変更されたファイルを更新
  local changed_files
  changed_files=$(git --no-pager diff --name-only HEAD 2>/dev/null | tr '\n' ',' | sed 's/,$//')

  # セッションファイルを更新
  if has_jq; then
    local tmp_file="${session_file}.tmp"
    jq \
      --arg ended "$(now_iso)" \
      --arg summary "$summary" \
      --arg tags "$tags" \
      --argjson files "$(files_to_json "$changed_files")" \
      '.status = "completed" |
       .ended_at = $ended |
       .summary = $summary |
       .context.files_at_end = $files |
       .tags = ($tags | split(",") | map(ltrimstr(" ") | rtrimstr(" ")) | map(select(length > 0)))' \
      "$session_file" > "$tmp_file" && mv "$tmp_file" "$session_file"
  else
    # jq なしの簡易更新
    sed -i "s/\"status\": \"active\"/\"status\": \"completed\"/" "$session_file"
  fi

  # アクティブセッションファイルを削除
  rm -f "$(prov_dir)/active_session"

  echo ""
  success "セッションを終了しました"
  echo "  セッションID: ${BOLD}${session_id}${RESET}"
  echo "  概要: ${summary}"
}

# ---- クイック記録（過去のやり取りをまとめて記録）----
record_quick() {
  local session_id
  session_id="$(generate_id)"
  local session_file
  session_file="$(session_path "$session_id")"

  echo ""
  bold "=== クイックAIセッション記録 ==="
  echo "（AIとのやり取りが完了した後の一括記録）"
  echo ""

  # AIツール
  local tool
  tool=$(prompt_select "使用したAIツール" \
    "claude-code" "cursor" "github-copilot" "chatgpt-browser" "claude-browser" "gemini" "other")

  # モデル
  local model
  model=$(prompt_input "モデル名（任意）" "")

  # 概要（必須）
  echo ""
  echo -e "${CYAN}AIセッションの概要（何をAIに頼んだか）:${RESET}"
  local summary
  read -r summary

  # 主要プロンプト（任意）
  echo ""
  echo -e "${CYAN}主要なプロンプトを貼り付けてください（任意、空行2回でスキップ）:${RESET}"
  local main_prompt
  main_prompt=$(read_multiline)

  # タグ
  local tags
  tags=$(prompt_input "タグ（例: feature, bugfix, refactor）" "")

  # 変更ファイル
  local changed_files
  changed_files=$(git --no-pager diff --staged --name-only 2>/dev/null | tr '\n' ',' | sed 's/,$//')

  # セッションファイル作成
  mkdir -p "$(sessions_dir)"

  local prompts_json="[]"
  if [[ -n "$main_prompt" ]]; then
    prompts_json=$(printf '[{"role": "user", "content": %s, "timestamp": "%s"}]' \
      "$(json_escape "$main_prompt")" "$(now_iso)")
  fi

  cat > "$session_file" << EOF
{
  "session_id": "${session_id}",
  "status": "completed",
  "started_at": "$(now_iso)",
  "ended_at": "$(now_iso)",
  "tool": "${tool}",
  "model": "${model}",
  "problem_statement": $(json_escape "$summary"),
  "summary": $(json_escape "$summary"),
  "prompts": ${prompts_json},
  "context": {
    "files_at_start": null,
    "files_at_end": $(files_to_json "$changed_files"),
    "branch": "$(git --no-pager rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')",
    "base_commit": "$(git --no-pager rev-parse HEAD 2>/dev/null || echo 'unknown')"
  },
  "commit_hash": null,
  "tags": $(tags_to_json "$tags")
}
EOF

  # アクティブセッションとしてセット
  echo "$session_id" > "$(prov_dir)/active_session"

  echo ""
  success "セッションを記録しました"
  echo "  セッションID: ${BOLD}${session_id}${RESET}"
  echo ""
  echo "  コミット時にこのセッションが自動で紐付けられます:"
  echo "    ${BOLD}ai-prov commit -m 'コミットメッセージ'${RESET}"
}

# ---- セッション一覧 ----
record_list() {
  require_initialized

  echo ""
  bold "=== 記録済みAIセッション一覧 ==="
  echo ""

  local count=0
  while IFS= read -r session_id; do
    [[ -z "$session_id" ]] && continue
    local session_file
    session_file="$(session_path "$session_id")"
    [[ ! -f "$session_file" ]] && continue

    local status tool summary started_at
    if has_jq; then
      status=$(jq -r '.status // "unknown"' "$session_file")
      tool=$(jq -r '.tool // "unknown"' "$session_file")
      summary=$(jq -r '.summary // .problem_statement // "（概要なし）"' "$session_file")
      started_at=$(jq -r '.started_at // ""' "$session_file")
    else
      status="unknown"
      tool="unknown"
      summary="（jqが必要です）"
      started_at=""
    fi

    local status_icon="✓"
    local status_color="$GREEN"
    [[ "$status" == "active" ]] && status_icon="●" && status_color="$YELLOW"
    [[ "$status" == "unknown" ]] && status_icon="?" && status_color="$RESET"

    echo -e "  ${status_color}${status_icon}${RESET} ${BOLD}${session_id:0:8}...${RESET}  [${tool}]  ${started_at:0:10}"
    echo -e "      ${summary:0:80}"
    echo ""
    count=$((count + 1)) || true
  done < <(list_session_ids)

  if [[ $count -eq 0 ]]; then
    echo "  記録済みのセッションはありません"
    echo "  ${BOLD}ai-prov record${RESET} で記録を開始してください"
  fi
  echo ""
}

# ---- セッション詳細表示 ----
record_show() {
  local session_id="${1:-}"

  if [[ -z "$session_id" ]]; then
    # アクティブセッションを表示
    if [[ -f "$(prov_dir)/active_session" ]]; then
      session_id=$(cat "$(prov_dir)/active_session")
    else
      error "セッションIDを指定してください"
      return 1
    fi
  fi

  local session_file
  session_file="$(session_path "$session_id")"

  if [[ ! -f "$session_file" ]]; then
    error "セッションが見つかりません: ${session_id}"
    return 1
  fi

  echo ""
  bold "=== AIセッション詳細 ==="
  echo ""
  cat "$session_file" | pretty_json
  echo ""
}

# ---- ヘルパー: 複数行入力 ----
read_multiline() {
  local lines=()
  local line
  local empty_count=0

  while IFS= read -r line; do
    if [[ -z "$line" ]]; then
      empty_count=$((empty_count + 1))
      [[ $empty_count -ge 2 ]] && break
      lines+=("")
    else
      empty_count=0
      lines+=("$line")
    fi
  done

  printf '%s\n' "${lines[@]}"
}

# ---- ヘルパー: プロンプト記録 ----
record_prompts() {
  local session_file="$1"
  local prompts=()

  echo ""
  echo "主要なプロンプトを入力してください"
  echo "（各プロンプトを入力後、空行を2回押して次へ。'done'で完了）"

  local prompt_num=1
  while true; do
    echo ""
    echo -e "${CYAN}プロンプト ${prompt_num} (空行2回でスキップ、'done'で完了):${RESET}"
    local content
    content=$(read_multiline)

    [[ -z "$content" || "$content" == "done" ]] && break

    prompts+=("$(printf '{"role": "user", "content": %s, "timestamp": "%s"}' \
      "$(json_escape "$content")" "$(now_iso)")")
    prompt_num=$((prompt_num + 1))
  done

  if [[ ${#prompts[@]} -gt 0 ]] && has_jq; then
    local prompts_json
    prompts_json=$(printf '%s\n' "${prompts[@]}" | jq -s '.')
    local tmp_file="${session_file}.tmp"
    jq --argjson prompts "$prompts_json" '.prompts = $prompts' \
      "$session_file" > "$tmp_file" && mv "$tmp_file" "$session_file"
  fi
}

# ---- ヘルパー: ファイル配列をJSONに ----
files_to_json() {
  local files_csv="$1"
  if [[ -z "$files_csv" ]]; then
    echo "[]"
    return
  fi

  if has_jq; then
    echo "$files_csv" | tr ',' '\n' | jq -R -s 'split("\n") | map(select(length > 0))'
  else
    echo "[\"${files_csv//,/\",\"}\"]"
  fi
}

# ---- ヘルパー: タグ文字列をJSONに ----
tags_to_json() {
  local tags_csv="$1"
  if [[ -z "$tags_csv" ]]; then
    echo "[]"
    return
  fi

  if has_jq; then
    echo "$tags_csv" | jq -R 'split(",") | map(ltrimstr(" ") | rtrimstr(" ")) | map(select(length > 0))'
  else
    echo "[\"${tags_csv//,/\",\"}\"]"
  fi
}
