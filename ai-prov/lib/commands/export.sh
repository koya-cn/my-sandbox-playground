#!/usr/bin/env bash
# lib/commands/export.sh - ai-prov export コマンド
# プロベナンスデータをさまざまな形式でエクスポートする

cmd_export() {
  require_initialized

  local format="markdown"  # markdown | json | csv | html
  local output=""
  local limit=50
  local since=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --format|-f) shift; format="$1" ;;
      --output|-o) shift; output="$1" ;;
      -n|--count)  shift; limit="$1" ;;
      --since)     shift; since="$1" ;;
      --help|-h)   export_help; return ;;
    esac
    shift
  done

  local exports_dir
  exports_dir="$(prov_dir)/exports"
  mkdir -p "$exports_dir"

  # デフォルト出力ファイル名
  if [[ -z "$output" ]]; then
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    output="${exports_dir}/ai-provenance_${timestamp}.${format}"
    [[ "$format" == "markdown" ]] && output="${exports_dir}/ai-provenance_${timestamp}.md"
  fi

  info "エクスポートしています... (形式: ${format})"

  case "$format" in
    markdown|md) export_markdown "$output" "$limit" "$since" ;;
    json)        export_json     "$output" "$limit" "$since" ;;
    csv)         export_csv      "$output" "$limit" "$since" ;;
    html)        export_html     "$output" "$limit" "$since" ;;
    *)
      error "不明な形式: ${format}"
      echo "利用可能: markdown, json, csv, html"
      return 1
      ;;
  esac

  success "エクスポート完了: ${output}"
  echo "  サイズ: $(du -h "$output" | cut -f1)"
}

# ---- Markdown エクスポート ----
export_markdown() {
  local output="$1"
  local limit="$2"
  local since="$3"

  local repo_name
  repo_name=$(basename "$(git_root)")
  local export_date
  export_date=$(now_human)

  {
    cat << EOF
# AI Provenance Report: ${repo_name}

> 生成日時: ${export_date}
> このドキュメントは ai-prov によって自動生成されました

---

## サマリー

EOF

    # 統計情報
    local total_commits
    local ai_commits=0
    total_commits=$(git --no-pager log --no-notes --oneline -n "$limit" 2>/dev/null | wc -l)

    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      local hash="${line%% *}"
      local session_id
      session_id=$(git --no-pager log --no-notes -1 --pretty=format:"%B" "$hash" 2>/dev/null | \
        grep -oP "(?<=${SESSION_TRAILER}: )[a-f0-9-]+" | head -1)
      [[ -n "$session_id" ]] && ai_commits=$((ai_commits + 1)) || true
    done < <(git --no-pager log --no-notes --pretty=format:"%H %s" -n "$limit" 2>/dev/null)

    cat << EOF
| 項目 | 値 |
|------|-----|
| 総コミット数 | ${total_commits} |
| AI支援コミット数 | ${ai_commits} |
| AI支援率 | $(( total_commits > 0 ? ai_commits * 100 / total_commits : 0 ))% |
| レポート期間 | 直近 ${limit} コミット |

---

## コミット履歴

EOF

    # 各コミットの詳細
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      local hash="${line%% *}"
      local subject="${line#* }"

      local date_str author
      date_str=$(git --no-pager log --no-notes -1 --pretty=format:"%ad" --date=format:"%Y-%m-%d" "$hash")
      author=$(git --no-pager log --no-notes -1 --pretty=format:"%an" "$hash")

      local session_id
      session_id=$(git --no-pager log --no-notes -1 --pretty=format:"%B" "$hash" 2>/dev/null | \
        grep -oP "(?<=${SESSION_TRAILER}: )[a-f0-9-]+" | head -1)

      echo "### ${hash:0:8} — ${subject}"
      echo ""
      echo "**日時:** ${date_str} | **作者:** ${author}"
      echo ""

      if [[ -n "$session_id" ]]; then
        local session_file
        session_file="$(session_path "$session_id")"

        echo "**🤖 AI Provenance**"
        echo ""

        if [[ -f "$session_file" ]] && has_jq; then
          local tool model summary problem tags
          tool=$(jq -r '.tool // "unknown"' "$session_file")
          model=$(jq -r '.model // ""' "$session_file")
          summary=$(jq -r '.summary // .problem_statement // ""' "$session_file")
          tags=$(jq -r '.tags // [] | join(", ")' "$session_file")

          echo "| 項目 | 値 |"
          echo "|------|-----|"
          echo "| ツール | ${tool}${model:+ / ${model}} |"
          [[ -n "$summary" ]] && echo "| 概要 | ${summary} |"
          [[ -n "$tags" ]]    && echo "| タグ | ${tags} |"
          echo "| セッションID | \`${session_id:0:16}...\` |"
          echo ""

          # プロンプト
          local prompt_count
          prompt_count=$(jq '.prompts | length' "$session_file" 2>/dev/null || echo 0)
          if [[ "$prompt_count" -gt 0 ]]; then
            echo "**プロンプト:**"
            echo ""
            jq -r '.prompts[] | "> **[" + .role + "]** " + .content' "$session_file" | head -20
            echo ""
          fi
        else
          echo "セッションID: \`${session_id}\`"
          echo ""
        fi
      else
        echo "*AI Provenanceなし*"
        echo ""
      fi

      echo "---"
      echo ""
    done < <(git --no-pager log --no-notes --pretty=format:"%H %s" -n "$limit" 2>/dev/null)

  } > "$output"
}

# ---- JSON エクスポート ----
export_json() {
  local output="$1"
  local limit="$2"

  local commits=()

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local hash="${line%% *}"
    local subject="${line#* }"

    local date_str author body
    date_str=$(git --no-pager log --no-notes -1 --pretty=format:"%aI" "$hash")
    author=$(git --no-pager log --no-notes -1 --pretty=format:"%an <%ae>" "$hash")
    body=$(git --no-pager log --no-notes -1 --pretty=format:"%B" "$hash")

    local session_id
    session_id=$(echo "$body" | grep -oP "(?<=${SESSION_TRAILER}: )[a-f0-9-]+" | head -1)

    local session_json="null"
    if [[ -n "$session_id" ]]; then
      local session_file
      session_file="$(session_path "$session_id")"
      [[ -f "$session_file" ]] && session_json=$(cat "$session_file")
    fi

    commits+=("$(printf '{"hash":"%s","subject":%s,"date":"%s","author":%s,"session_id":%s,"session":%s}' \
      "$hash" \
      "$(json_escape "$subject")" \
      "$date_str" \
      "$(json_escape "$author")" \
      "$(json_escape "${session_id:-}")" \
      "${session_json}")")

  done < <(git --no-pager log --no-notes --pretty=format:"%H %s" -n "$limit" 2>/dev/null)

  local joined
  joined=$(IFS=','; echo "${commits[*]}")
  echo "{\"repo\":\"$(basename "$(git_root)")\",\"exported_at\":\"$(now_iso)\",\"commits\":[${joined}]}" | \
    pretty_json > "$output"
}

# ---- CSV エクスポート ----
export_csv() {
  local output="$1"
  local limit="$2"

  {
    echo "commit_hash,date,author,subject,has_ai_provenance,tool,model,summary,session_id"

    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      local hash="${line%% *}"
      local subject="${line#* }"

      local date_str author
      date_str=$(git --no-pager log --no-notes -1 --pretty=format:"%ad" --date=format:"%Y-%m-%d" "$hash")
      author=$(git --no-pager log --no-notes -1 --pretty=format:"%an" "$hash")

      local session_id
      session_id=$(git --no-pager log --no-notes -1 --pretty=format:"%B" "$hash" 2>/dev/null | \
        grep -oP "(?<=${SESSION_TRAILER}: )[a-f0-9-]+" | head -1)

      local has_prov="false"
      local tool="" model="" summary=""

      if [[ -n "$session_id" ]]; then
        has_prov="true"
        local session_file
        session_file="$(session_path "$session_id")"
        if [[ -f "$session_file" ]] && has_jq; then
          tool=$(jq -r '.tool // ""' "$session_file")
          model=$(jq -r '.model // ""' "$session_file")
          summary=$(jq -r '.summary // .problem_statement // ""' "$session_file" | \
            tr ',' '、' | tr '\n' ' ' | head -c 200)
        fi
      fi

      printf '"%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' \
        "$hash" "$date_str" "$author" "$subject" \
        "$has_prov" "$tool" "$model" "$summary" "${session_id:-}"
    done < <(git --no-pager log --no-notes --pretty=format:"%H %s" -n "$limit" 2>/dev/null)
  } > "$output"
}

# ---- HTML エクスポート ----
export_html() {
  local output="$1"
  local limit="$2"

  local repo_name
  repo_name=$(basename "$(git_root)")

  {
    cat << 'HTMLEOF'
<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>AI Provenance Report</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; max-width: 1000px; margin: 0 auto; padding: 20px; color: #333; }
    h1 { color: #1a1a2e; border-bottom: 3px solid #4a90d9; padding-bottom: 10px; }
    .commit { border: 1px solid #e0e0e0; border-radius: 8px; padding: 16px; margin: 12px 0; }
    .commit.has-ai { border-left: 4px solid #27ae60; }
    .commit.no-ai  { border-left: 4px solid #bdc3c7; }
    .commit-hash { font-family: monospace; background: #f5f5f5; padding: 2px 6px; border-radius: 4px; font-size: 0.9em; }
    .ai-badge { background: #27ae60; color: white; padding: 2px 8px; border-radius: 12px; font-size: 0.8em; }
    .meta { color: #666; font-size: 0.85em; margin: 4px 0; }
    table { border-collapse: collapse; width: 100%; margin: 8px 0; }
    th, td { border: 1px solid #ddd; padding: 6px 10px; text-align: left; }
    th { background: #f5f5f5; }
    .prompt-box { background: #f8f9fa; border-left: 3px solid #4a90d9; padding: 8px 12px; margin: 8px 0; font-size: 0.9em; }
    .stats { display: flex; gap: 20px; margin: 20px 0; }
    .stat-card { background: #f5f7fa; border-radius: 8px; padding: 16px 24px; text-align: center; }
    .stat-number { font-size: 2em; font-weight: bold; color: #4a90d9; }
  </style>
</head>
<body>
HTMLEOF

    local total_commits ai_commits=0
    total_commits=$(git --no-pager log --no-notes --oneline -n "$limit" 2>/dev/null | wc -l)

    # 2パス目でai_commitsをカウント
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      local hash="${line%% *}"
      local session_id
      session_id=$(git --no-pager log --no-notes -1 --pretty=format:"%B" "$hash" 2>/dev/null | \
        grep -oP "(?<=${SESSION_TRAILER}: )[a-f0-9-]+" | head -1)
      [[ -n "$session_id" ]] && ai_commits=$((ai_commits + 1)) || true
    done < <(git --no-pager log --no-notes --pretty=format:"%H %s" -n "$limit" 2>/dev/null)

    cat << EOF
  <h1>🤖 AI Provenance Report: ${repo_name}</h1>
  <p class="meta">生成日時: $(now_human)</p>

  <div class="stats">
    <div class="stat-card">
      <div class="stat-number">${total_commits}</div>
      <div>総コミット</div>
    </div>
    <div class="stat-card">
      <div class="stat-number">${ai_commits}</div>
      <div>AI支援コミット</div>
    </div>
    <div class="stat-card">
      <div class="stat-number">$(( total_commits > 0 ? ai_commits * 100 / total_commits : 0 ))%</div>
      <div>AI支援率</div>
    </div>
  </div>

  <h2>コミット履歴</h2>
EOF

    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      local hash="${line%% *}"
      local subject="${line#* }"

      local date_str author
      date_str=$(git --no-pager log --no-notes -1 --pretty=format:"%ad" --date=format:"%Y-%m-%d %H:%M" "$hash")
      author=$(git --no-pager log --no-notes -1 --pretty=format:"%an" "$hash")

      local session_id
      session_id=$(git --no-pager log --no-notes -1 --pretty=format:"%B" "$hash" 2>/dev/null | \
        grep -oP "(?<=${SESSION_TRAILER}: )[a-f0-9-]+" | head -1)

      if [[ -n "$session_id" ]]; then
        echo '<div class="commit has-ai">'
        echo "  <span class='commit-hash'>${hash:0:8}</span> &nbsp; <span class='ai-badge'>🤖 AI</span>"
      else
        echo '<div class="commit no-ai">'
        echo "  <span class='commit-hash'>${hash:0:8}</span>"
      fi

      echo "  <strong>${subject}</strong>"
      echo "  <div class='meta'>${date_str} — ${author}</div>"

      if [[ -n "$session_id" ]]; then
        local session_file
        session_file="$(session_path "$session_id")"
        if [[ -f "$session_file" ]] && has_jq; then
          local tool model summary
          tool=$(jq -r '.tool // "unknown"' "$session_file")
          model=$(jq -r '.model // ""' "$session_file")
          summary=$(jq -r '.summary // .problem_statement // ""' "$session_file")

          echo "  <table>"
          echo "    <tr><th>ツール</th><td>${tool}${model:+ / ${model}}</td></tr>"
          [[ -n "$summary" ]] && echo "    <tr><th>概要</th><td>${summary}</td></tr>"
          echo "  </table>"

          local prompt_count
          prompt_count=$(jq '.prompts | length' "$session_file" 2>/dev/null || echo 0)
          if [[ "$prompt_count" -gt 0 ]]; then
            echo "  <details><summary>プロンプト (${prompt_count}件)</summary>"
            jq -r '.prompts[] | "<div class=\"prompt-box\"><strong>[" + .role + "]</strong><br>" + (.content | gsub("\n"; "<br>")) + "</div>"' "$session_file"
            echo "  </details>"
          fi
        fi
      fi

      echo '</div>'
    done < <(git --no-pager log --no-notes --pretty=format:"%H %s" -n "$limit" 2>/dev/null)

    echo '</body></html>'
  } > "$output"
}

export_help() {
  cat << EOF

${BOLD}使用方法:${RESET} ai-prov export [オプション]

${BOLD}オプション:${RESET}
  -f, --format <形式>   出力形式: markdown, json, csv, html（デフォルト: markdown）
  -o, --output <ファイル> 出力先ファイル（デフォルト: .ai-prov/exports/）
  -n, --count <N>       対象コミット数（デフォルト: 50）
  --since <日付>         指定日以降のコミット（例: 2024-01-01）

${BOLD}例:${RESET}
  ai-prov export                          # Markdown形式でエクスポート
  ai-prov export --format html -o report.html
  ai-prov export --format json -n 100

EOF
}
