#!/usr/bin/env bash
# lib/commands/init.sh - ai-prov init コマンド

cmd_init() {
  local root
  root="$(git_root)"
  local prov_dir
  prov_dir="$(prov_dir)"

  info "AI Provenance ツールを初期化しています..."

  # ---- .ai-prov ディレクトリ作成 ----
  mkdir -p "${prov_dir}/sessions"
  mkdir -p "${prov_dir}/exports"

  # ---- 設定ファイル作成 ----
  if [[ ! -f "${prov_dir}/config.json" ]]; then
    cat > "${prov_dir}/config.json" << EOF
{
  "version": "${AI_PROV_VERSION}",
  "initialized_at": "$(now_iso)",
  "settings": {
    "auto_record": false,
    "use_git_notes": true,
    "add_trailer": true,
    "default_tool": "$(detect_ai_tool)",
    "require_session_on_commit": false,
    "session_template": "standard"
  }
}
EOF
    success "設定ファイルを作成しました: ${prov_dir}/config.json"
  else
    warn "設定ファイルは既に存在します（スキップ）"
  fi

  # ---- Git Hooks インストール ----
  local hooks_dir="${root}/.git/hooks"

  install_hook "prepare-commit-msg" "$hooks_dir"
  install_hook "post-commit" "$hooks_dir"

  # ---- .gitignore への追記 ----
  local gitignore="${root}/.gitignore"
  if [[ -f "$gitignore" ]]; then
    if ! grep -q "\.ai-prov/exports" "$gitignore"; then
      echo "" >> "$gitignore"
      echo "# AI Provenance exports (local only)" >> "$gitignore"
      echo ".ai-prov/exports/" >> "$gitignore"
      success ".gitignore に exports を追加しました"
    fi
  fi

  # ---- .ai-prov 自体はリポジトリに含める ----
  # sessions/ と config.json はチームで共有するため追跡対象
  if [[ ! -f "${prov_dir}/.gitkeep" ]]; then
    touch "${prov_dir}/sessions/.gitkeep"
  fi

  echo ""
  success "初期化完了！"
  echo ""
  echo "  次のステップ:"
  echo "    1. AIでコーディングを始める前に: ${BOLD}ai-prov record${RESET}"
  echo "    2. コミット時（自動でセッション紐付け）: ${BOLD}ai-prov commit -m 'メッセージ'${RESET}"
  echo "    3. AIコンテキスト付きログ確認: ${BOLD}ai-prov log${RESET}"
  echo ""
}

install_hook() {
  local hook_name="$1"
  local hooks_dir="$2"
  local hook_source
  # フックのソースファイルは ai-prov/hooks/ に存在
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  hook_source="${script_dir}/../../hooks/${hook_name}"
  local hook_dest="${hooks_dir}/${hook_name}"

  if [[ ! -f "$hook_source" ]]; then
    warn "フックファイルが見つかりません: ${hook_source}"
    return
  fi

  if [[ -f "$hook_dest" ]]; then
    # 既存のフックがあればバックアップして追記
    if grep -q "ai-prov" "$hook_dest"; then
      warn "フック ${hook_name} は既にインストール済みです（スキップ）"
      return
    fi
    warn "既存のフック ${hook_name} を ${hook_name}.backup にバックアップ"
    cp "$hook_dest" "${hook_dest}.backup"
    # 既存フックの末尾にai-provのフックを追記
    echo "" >> "$hook_dest"
    echo "# ai-prov hook" >> "$hook_dest"
    cat "$hook_source" >> "$hook_dest"
  else
    cp "$hook_source" "$hook_dest"
    chmod +x "$hook_dest"
  fi

  success "フックをインストールしました: ${hook_name}"
}
