#!/usr/bin/env bash
# lib/commands/log.sh - ai-prov log コマンド
# AIコンテキスト付きgit logを表示する

cmd_log() {
  local limit=20
  local show_prompts=false
  local show_full=false
  local format="pretty"  # pretty | json | oneline

  # 引数パース
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--count)
        shift; limit="$1" ;;
      -p|--prompts)
        show_prompts=true ;;
      -f|--full)
        show_full=true ;;
      --json)
        format="json" ;;
      --oneline)
        format="oneline" ;;
      --help|-h)
        log_help; return ;;
    esac
    shift
  done

  case "$format" in
    pretty)  log_pretty "$limit" "$show_prompts" "$show_full" ;;
    json)    log_json "$limit" ;;
    oneline) log_oneline "$limit" ;;
  esac
}

# ---- プリティ形式（デフォルト）----
log_pretty() {
  local limit="$1"
  local show_prompts="$2"
  local show_full="$3"

  echo ""

  # git logからコミット一覧を取得
  local commits
  commits=$(git --no-pager log --no-notes --pretty=format:"%H %s" -n "$limit" 2>/dev/null)

  if [[ -z "$commits" ]]; then
    warn "コミットが見つかりません"
    return
  fi

  local ai_count=0
  local total_count=0

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local hash="${line%% *}"
    local subject="${line#* }"
    total_count=$((total_count + 1)) || true

    # セッションIDをコミットメッセージのトレーラーから取得
    local session_id
    session_id=$(git --no-pager log --no-notes -1 --pretty=format:"%B" "$hash" 2>/dev/null | \
      grep -oP "(?<=${SESSION_TRAILER}: )[a-f0-9-]+" | head -1)

    # git notes からも確認
    local note
    note="$(get_note "$hash")"

    # セッションファイルのパス
    local session_file=""
    if [[ -n "$session_id" ]]; then
      session_file="$(session_path "$session_id")"
    fi

    # ---- コミット行の表示 ----
    local date_str
    date_str=$(git --no-pager log --no-notes -1 --pretty=format:"%ad" --date=short "$hash")

    if [[ -n "$session_id" ]] && ([[ -f "$session_file" ]] || [[ -n "$note" ]]); then
      # AI Provenance あり
      ai_count=$((ai_count + 1)) || true
      echo -e "${GREEN}●${RESET} ${BOLD}${hash:0:8}${RESET}  ${date_str}  ${subject}"
      echo -e "  ${GREEN}🤖 AI Provenance${RESET}"

      # セッション情報を表示
      display_session_info "$session_file" "$note" "$show_prompts" "$show_full"
    else
      # Provenance なし
      echo -e "${BLUE}○${RESET} ${BOLD}${hash:0:8}${RESET}  ${date_str}  ${subject}"
    fi

    echo ""
  done <<< "$commits"

  # サマリー
  echo -e "  ${BOLD}${ai_count}/${total_count}${RESET} コミットに AI Provenance があります"
  echo ""
}

# ---- セッション情報の表示 ----
display_session_info() {
  local session_file="$1"
  local note="$2"
  local show_prompts="$3"
  local show_full="$4"

  local source_data=""

  # セッションファイルを優先、なければノートから
  if [[ -f "$session_file" ]]; then
    source_data=$(cat "$session_file")
  elif [[ -n "$note" ]]; then
    source_data="$note"
  else
    echo -e "  ${YELLOW}セッションファイルが見つかりません${RESET}"
    return
  fi

  if has_jq; then
    local tool model summary problem started_at tags
    tool=$(echo "$source_data" | jq -r '.tool // "unknown"')
    model=$(echo "$source_data" | jq -r '.model // ""')
    summary=$(echo "$source_data" | jq -r '.summary // .problem_statement // "（概要なし）"')
    started_at=$(echo "$source_data" | jq -r '.started_at // ""')
    tags=$(echo "$source_data" | jq -r '.tags // [] | join(", ")')

    # ツールとモデル
    local tool_str="${tool}"
    [[ -n "$model" ]] && tool_str="${tool} / ${model}"
    echo -e "  ツール: ${CYAN}${tool_str}${RESET}"

    # 概要
    echo -e "  概要: ${summary:0:100}"

    # タグ
    [[ -n "$tags" ]] && echo -e "  タグ: ${tags}"

    # 日時
    [[ -n "$started_at" ]] && echo -e "  記録日時: ${started_at:0:19}"

    # プロンプト表示（オプション）
    if $show_prompts; then
      local prompt_count
      prompt_count=$(echo "$source_data" | jq '.prompts | length')
      if [[ "$prompt_count" -gt 0 ]]; then
        echo -e "  ${BOLD}プロンプト:${RESET}"
        echo "$source_data" | jq -r '.prompts[] | "    [" + .role + "] " + (.content | split("\n")[0:3] | join("\n    "))' | head -20
      fi
    fi
  else
    echo -e "  ${YELLOW}（詳細表示にはjqが必要です）${RESET}"
    echo "  概要: $(echo "$source_data" | grep -o '"summary": "[^"]*"' | sed 's/.*": "\(.*\)"/\1/' | head -1)"
  fi
}

# ---- JSON 形式 ----
log_json() {
  local limit="$1"
  local result=()

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local hash="${line%% *}"
    local subject="${line#* }"

    local session_id
    session_id=$(git --no-pager log --no-notes -1 --pretty=format:"%B" "$hash" 2>/dev/null | \
      grep -oP "(?<=${SESSION_TRAILER}: )[a-f0-9-]+" | head -1)

    local session_data="null"
    if [[ -n "$session_id" ]]; then
      local session_file
      session_file="$(session_path "$session_id")"
      if [[ -f "$session_file" ]]; then
        session_data=$(cat "$session_file")
      fi
    fi

    local entry
    entry=$(printf '{"commit": "%s", "subject": %s, "session": %s}' \
      "$hash" "$(json_escape "$subject")" "$session_data")
    result+=("$entry")
  done < <(git --no-pager log --no-notes --pretty=format:"%H %s" -n "$limit" 2>/dev/null)

  printf '[%s]' "$(IFS=','; echo "${result[*]}")" | pretty_json
}

# ---- 一行形式 ----
log_oneline() {
  local limit="$1"

  git --no-pager log --no-notes --pretty=format:"%H %s" -n "$limit" 2>/dev/null | \
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local hash="${line%% *}"
    local subject="${line#* }"

    local session_id
    session_id=$(git --no-pager log --no-notes -1 --pretty=format:"%B" "$hash" 2>/dev/null | \
      grep -oP "(?<=${SESSION_TRAILER}: )[a-f0-9-]+" | head -1)

    if [[ -n "$session_id" ]]; then
      echo -e "${GREEN}●${RESET} ${hash:0:8} 🤖 ${subject}"
    else
      echo -e "${BLUE}○${RESET} ${hash:0:8}    ${subject}"
    fi
  done
}

# ---- ヘルプ ----
log_help() {
  cat << EOF

${BOLD}使用方法:${RESET} ai-prov log [オプション]

${BOLD}オプション:${RESET}
  -n, --count <N>   表示するコミット数（デフォルト: 20）
  -p, --prompts     プロンプト内容も表示
  -f, --full        全情報を表示
  --json            JSON形式で出力
  --oneline         一行形式で出力
  -h, --help        このヘルプを表示

${BOLD}凡例:${RESET}
  ${GREEN}●${RESET}  AI Provenance あり
  ${BLUE}○${RESET}  AI Provenance なし

EOF
}
