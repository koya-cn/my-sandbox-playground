#!/usr/bin/env bash
# lib/commands/commit.sh - ai-prov commit コマンド
# AI Provenanceメタデータを含むコミットを作成する

cmd_commit() {
  require_initialized

  # 引数を git commit と同様に受け取る
  local git_args=("$@")
  local message=""
  local session_id=""
  local no_session=false
  local amend=false

  # 引数をパース
  local i=0
  while [[ $i -lt ${#git_args[@]} ]]; do
    case "${git_args[$i]}" in
      -m|--message)
        i=$((i + 1))
        message="${git_args[$i]}"
        ;;
      --session)
        i=$((i + 1))
        session_id="${git_args[$i]}"
        ;;
      --no-session)
        no_session=true
        ;;
      --amend)
        amend=true
        ;;
    esac
    i=$((i + 1))
  done

  # ステージングエリアに変更があるか確認
  if ! git diff --cached --quiet 2>/dev/null; then
    : # 変更あり、続行
  elif $amend; then
    : # amendは変更なしでも可
  else
    warn "ステージングエリアに変更がありません"
    echo "  ${BOLD}git add <files>${RESET} でファイルをステージングしてください"
    return 1
  fi

  # コミットメッセージが未指定ならエディタで入力（将来拡張）
  if [[ -z "$message" ]]; then
    error "-m オプションでコミットメッセージを指定してください"
    echo "  例: ai-prov commit -m 'feat: 新機能を追加'"
    return 1
  fi

  # セッション確認
  if ! $no_session; then
    session_id="$(resolve_session "$session_id")"
  fi

  # ---- コミット実行 ----
  echo ""
  info "コミットを実行します..."
  echo "  メッセージ: ${message}"
  [[ -n "$session_id" ]] && echo "  セッション: ${session_id:0:8}..."
  echo ""

  # セッションIDをトレーラーとして追加
  local final_message="$message"
  if [[ -n "$session_id" ]]; then
    final_message="$(add_trailer "$message" "$session_id")"
  fi

  # git commit 実行
  if $amend; then
    git commit --amend -m "$final_message"
  else
    git commit -m "$final_message"
  fi

  # コミット成功後の処理
  local commit_hash
  commit_hash=$(git --no-pager rev-parse HEAD)

  if [[ -n "$session_id" ]]; then
    # セッションファイルにコミットハッシュを記録
    link_session_to_commit "$session_id" "$commit_hash"

    # git notes にセッション情報を保存
    save_note "$session_id" "$commit_hash"

    # アクティブセッションをクリア
    rm -f "$(prov_dir)/active_session"
  fi

  echo ""
  success "コミット完了: ${BOLD}${commit_hash:0:8}${RESET}"
  [[ -n "$session_id" ]] && echo "  AI Provenance: セッション ${BOLD}${session_id:0:8}...${RESET} と紐付けました"
  echo ""
}

# ---- セッションを解決（既存セッション or 新規作成）----
resolve_session() {
  local requested_id="${1:-}"

  # 明示的に指定された場合
  if [[ -n "$requested_id" ]]; then
    if [[ -f "$(session_path "$requested_id")" ]]; then
      echo "$requested_id"
      return
    else
      error "指定されたセッションが見つかりません: ${requested_id}"
      return 1
    fi
  fi

  # アクティブセッションがあればそれを使用
  local active_file
  active_file="$(prov_dir)/active_session"
  if [[ -f "$active_file" ]]; then
    local active_id
    active_id=$(cat "$active_file")
    if [[ -f "$(session_path "$active_id")" ]]; then
      local summary
      summary=$(session_field "$(session_path "$active_id")" "summary")
      [[ -z "$summary" ]] && summary=$(session_field "$(session_path "$active_id")" "problem_statement")

      echo ""
      info "アクティブセッションを検出しました:"
      echo "  ID: ${active_id:0:8}..."
      echo "  概要: ${summary:0:80}"
      echo ""
      if confirm "このセッションを使用しますか？" "y"; then
        echo "$active_id"
        return
      fi
    fi
  fi

  # セッションが未記録 → クイック記録を促す
  echo ""
  warn "AIセッションが記録されていません"
  echo ""
  if confirm "今すぐクイック記録しますか？（コミットに含めるAIコンテキストを記録）" "y"; then
    record_quick
    if [[ -f "$active_file" ]]; then
      cat "$active_file"
      return
    fi
  fi

  # セッションなしでコミット
  echo ""
  warn "セッションなしでコミットします（AI Provenanceは記録されません）"
  echo ""
}

# ---- セッションとコミットを紐付け ----
link_session_to_commit() {
  local session_id="$1"
  local commit_hash="$2"
  local session_file
  session_file="$(session_path "$session_id")"

  if [[ ! -f "$session_file" ]]; then
    return
  fi

  if has_jq; then
    local tmp_file="${session_file}.tmp"
    jq \
      --arg hash "$commit_hash" \
      --arg ended "$(now_iso)" \
      '.commit_hash = $hash | .status = "committed" | (.ended_at //= $ended)' \
      "$session_file" > "$tmp_file" && mv "$tmp_file" "$session_file"
  fi
}

# ---- git notes にセッション情報を保存 ----
save_note() {
  local session_id="$1"
  local commit_hash="$2"
  local session_file
  session_file="$(session_path "$session_id")"

  if [[ ! -f "$session_file" ]]; then
    return
  fi

  # git notes に JSON を保存
  local note_content
  note_content=$(cat "$session_file")
  add_note "$commit_hash" "$note_content"
}
