#!/usr/bin/env bash
# install.sh - ai-prov グローバルインストールスクリプト

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
INSTALL_DIR="${HOME}/.local/bin"

# ---- カラー出力 ----
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${GREEN}[install]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[install] WARNING:${RESET} $*"; }
error()   { echo -e "${RED}[install] ERROR:${RESET} $*" >&2; exit 1; }

echo ""
echo -e "${BOLD}AI Provenance ツール インストーラー${RESET}"
echo "========================================"
echo ""

# ---- 前提条件の確認 ----
info "前提条件を確認中..."

# bash バージョン確認
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  error "Bash 4.0以上が必要です（現在: ${BASH_VERSION}）"
fi
info "✓ Bash ${BASH_VERSION}"

# git 確認
if ! command -v git &>/dev/null; then
  error "git がインストールされていません"
fi
info "✓ git $(git --version | grep -oP '\d+\.\d+\.\d+')"

# jq 確認（オプション）
if command -v jq &>/dev/null; then
  info "✓ jq $(jq --version)"
else
  warn "jq が見つかりません。一部機能が制限されます。"
  echo "  インストール推奨: sudo apt install jq  または  brew install jq"
fi

echo ""

# ---- インストール先の確認 ----
info "インストール先: ${INSTALL_DIR}"

# インストール先ディレクトリが存在しない場合は作成
if [[ ! -d "$INSTALL_DIR" ]]; then
  mkdir -p "$INSTALL_DIR"
  info "ディレクトリを作成しました: ${INSTALL_DIR}"
fi

# PATH に含まれているか確認
if ! echo "$PATH" | tr ':' '\n' | grep -q "^${INSTALL_DIR}$"; then
  warn "${INSTALL_DIR} が PATH に含まれていません"
  echo ""
  echo "  以下をシェルの設定ファイル（~/.bashrc, ~/.zshrc）に追加してください:"
  echo -e "  ${BOLD}export PATH=\"\${HOME}/.local/bin:\${PATH}\"${RESET}"
  echo ""
fi

# ---- シンボリックリンクの作成 ----
local_bin="${SCRIPT_DIR}/bin/ai-prov"
chmod +x "$local_bin"

# シンボリックリンク作成
ln -sf "$local_bin" "${INSTALL_DIR}/ai-prov"
info "シンボリックリンクを作成しました: ${INSTALL_DIR}/ai-prov -> ${local_bin}"

# ---- lib/ のパーミッション設定 ----
find "${SCRIPT_DIR}/lib" -name "*.sh" -exec chmod +x {} \;
find "${SCRIPT_DIR}/hooks" -name "*" -type f -exec chmod +x {} \;

echo ""
echo -e "${GREEN}========================================"
echo -e "  インストール完了！"
echo -e "========================================${RESET}"
echo ""
echo "  使用方法:"
echo -e "  ${BOLD}ai-prov --help${RESET}    ヘルプを表示"
echo -e "  ${BOLD}ai-prov init${RESET}      リポジトリを初期化"
echo ""
echo "  クイックスタート:"
echo -e "  ${BOLD}cd <your-git-repo>${RESET}"
echo -e "  ${BOLD}ai-prov init${RESET}"
echo -e "  ${BOLD}ai-prov record${RESET}"
echo ""

# ---- シェルの再読み込みが必要か確認 ----
if ! command -v ai-prov &>/dev/null; then
  warn "シェルを再起動するか、以下を実行してください:"
  echo -e "  ${BOLD}source ~/.bashrc${RESET}  または  ${BOLD}source ~/.zshrc${RESET}"
  echo ""
fi
