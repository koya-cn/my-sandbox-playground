Claude Code 権限ルールジェネレーター構成仕様書 (Spec.md)

1. 開発の背景と戦略的意義：爆発半径（Blast Radius）の制御

AIエージェントがターミナル上で自律的に動作する現代、セキュリティの要諦は「AIをルート権限を持つインターンとして扱う」という哲学に集約されます。Claude Codeは、ファイル操作やシェルコマンド実行という強力な能力を持つ一方で、その「自律性」がもたらすリスクは甚大です。

デフォルトの「すべて確認（Ask）」設定は安全ですが、定型操作のたびに人間の介入を強いることで「承認疲れ（Approval Fatigue）」を招き、最終的に開発者が --dangerously-skip-permissions という破壊的な「核の選択肢」に逃げる動機を作ってしまいます。これは、意図しないファイル削除や機密データの外部流出に対するガードレールをすべて撤廃することを意味します。

本ジェネレーターの目的は、この極端な二択を解消し、**「制御された自律性（Controlled Autonomy）」**を確立することです。ゼロトラスト・アーキテクチャに基づき、エージェントの「爆発半径（Blast Radius）」を定義することで、開発効率の向上と組織的なガバナンスの維持を両立させます。次セクションで定義する階層構造は、このガバナンスを支える基盤となります。

2. 権限設定の階層構造（Hierarchy）とデリバリメカニズム

Claude Codeの設定は、複数のスコープにわたる厳格な優先順位を持ちます。ジェネレーターは、ターゲットとなる環境（個人、チーム、組織）に応じて適切な階層にファイルを配置する必要があります。

設定スコープの優先順位と配送パス

| 優先順位 | スコープ名 | 生成・管理対象ファイル | OS別配送パス（Managed）/ 特性 |
|----------|-----------|----------------------|-------------------------------|
| 1 (最高) | Enterprise managed | managed-settings.json | 組織強制: MDMやレジストリで配布。ユーザー上書き不可。Mac: `/Library/Application Support/ClaudeCode/` / Linux・WSL: `/etc/claude-code/` / Win: `C:\Program Files\ClaudeCode\` |
| 2 | Command line | CLI 引数 / フラグ | 一時的: 特定のセッションのみに適用する動的設定。 |
| 3 | Local project | .claude/settings.local.json | 個人用 (Git管理外): 特定環境固有のパス。 |
| 4 | Shared project | .claude/settings.json | チーム共有 (Git管理): プロジェクト標準の権限。 |
| 5 (最低) | User settings | ~/.claude/settings.json | グローバル: 個人の全プロジェクトに適用。 |

戦略的評価

* 組織ガバナンス: IT部門は Managed 層を利用し、~/.ssh へのアクセス拒否や bypassPermissions モードの無効化を全社的に強制すべきです。
* 設定の継承: 配列設定（permissions.allow や sandbox.filesystem.allowWrite 等）は、各階層で結合（Merge）および重複排除されます。下位スコープは上位の設定を補完できますが、上位の deny を覆すことはできません。

3. ルール評価ロジックと「セキュリティの真実」

権限ルールは allow, deny, ask の3アクションで構成され、**「Deny（拒否）は常にAllow（許可）に優先する」**という鉄則に従います。

コア・アクションと評価順序

1. deny (拒否): 最優先。秘密情報や破壊的コマンドを封じ込める「盾」。
2. ask (確認): ルールに一致した場合、強制的にプロンプトを表示。git push 等の不可逆な操作に適用。
3. allow (許可): プロンプトなしで実行。npm test 等の低リスク定型作業。
4. Fallback: どのルールにも一致しない場合、システムはデフォルトで ask を選択します（Fail-closed設計）。

【重要】無視ルールの信頼性欠如

ソースコンテキストによれば、.claudeignore や .gitignore は、Claude Codeが「中身を覗き見る（Peek）」挙動を完全には阻止できないことが報告されています。 ジェネレーターの設計指針: 秘密情報（.env 等）の保護において、ignore ファイルは不十分な制御策です。ジェネレーターは、機密ファイルに対して settings.json 内の deny ルールを強制適用することを推奨し、これを唯一の有効なセキュリティ境界として扱う必要があります。

4. パス指定の構文規則：不備が招く脆弱性

パス指定の誤りは、ルール回避（Vulnerability）に直結します。本ジェネレーターは、以下の二種類の構文を厳密に使い分ける必要があります。

権限ルール vs サンドボックス設定の構文差異

| 適用対象 | 絶対パスの指定方法 | 相対パスの指定方法 |
|----------|-------------------|-------------------|
| Permission Rules (Read / Edit) | ダブルスラッシュ `//` 例: `//Users/admin/.ssh` | シングルスラッシュ `/` または `./` 例: `/src/index.ts` |
| Sandbox Config (allowWrite / denyRead) | シングルスラッシュ `/` 例: `/tmp/build` | `./` または 接頭辞なし 例: `./output` |

Globパターンとセキュリティ実装

* **/* (再帰的マッチ) や *.key 等、.gitignore ライクな構文をサポート。
* Security Vulnerability 回避策: AIが相対パス（./.env）の拒否ルールを、絶対パス（//absolute/path/.env）でアクセスすることで回避するリスクがあります。ジェネレーターは、拒否設定時に相対・絶対両方のパターンを自動生成する機能を実装すべきです。

Deny ルール自動生成の具体的ルール

ユーザーが機密ファイルパターン（例: `.env`）を拒否対象として指定した場合、ジェネレーターは以下の4パターンを自動的に生成する。

1. **相対パス（カレントディレクトリ）**: `.env`
2. **相対パス（再帰的）**: `**/.env`
3. **絶対パス（Permission Rules用）**: `//.env`（`//` プレフィックス）
4. **絶対パス（Sandbox Config用）**: `/.env`（`/` プレフィックス）

Glob パターンとの組み合わせ例:

```json
{
  "permissions": {
    "deny": [
      { "tool": "Read", "path": ".env" },
      { "tool": "Read", "path": "**/.env" },
      { "tool": "Read", "path": "**/.env.*" },
      { "tool": "Read", "path": "//.env" },
      { "tool": "Edit", "path": ".env" },
      { "tool": "Edit", "path": "**/.env" },
      { "tool": "Edit", "path": "**/.env.*" },
      { "tool": "Edit", "path": "//.env" }
    ]
  }
}
```

この自動展開により、パス記法の差異を意識せずに網羅的な拒否ルールを適用できる。

5. MCP サーバーのツール権限制御

Claude Code は MCP（Model Context Protocol）サーバーを介して外部ツールを接続できます。MCP ツールの呼び出しも `permissions.allow` / `permissions.deny` の評価対象となるため、ジェネレーターはこれを明示的に扱う必要があります。

MCP ツール権限の構文

MCP ツールは `mcp__<server_name>__<tool_name>` の形式でツール名が構成されます。

```json
{
  "permissions": {
    "allow": [
      { "tool": "mcp__filesystem__read_file" },
      { "tool": "mcp__github__search_repositories" }
    ],
    "deny": [
      { "tool": "mcp__filesystem__write_file", "path": "**/.env" },
      { "tool": "mcp__*__*" }
    ]
  }
}
```

MCP 権限設計の原則

* **デフォルト拒否**: MCP ツールはサードパーティが提供するため、明示的に許可されない限り `ask` または `deny` とすべきである。ジェネレーターは MCP ツールに対して `allow` を設定する際に警告を表示する。
* **サーバー単位の一括制御**: `mcp__<server_name>__*` のワイルドカードで、特定サーバーの全ツールをまとめて制御できる。
* **データ流出リスク**: MCP サーバーは外部サービスと通信する可能性があるため、ファイルパスを引数に取る MCP ツールには、Permission Rules と同様のパスベース deny ルールを適用すること。

ジェネレーターでの実装要件

* MCP サーバーが設定ファイル（`mcpServers` セクション）に登録されている場合、そのサーバーが提供するツール一覧を読み取り、権限ルールの候補として UI に表示する。
* MCP サーバーが未登録の場合でも、手動でサーバー名・ツール名を入力して deny/allow ルールを定義できること。

6. 動作モード（Permission Modes）の構成定義

2026年3月に導入された auto モードを含む、作業コンテキスト別の定義です。

| モード | 自動承認範囲 | 最適なユースケース | コスト / リスク |
|--------|------------|-------------------|----------------|
| default | Readのみ | 通常の開発、高セキュリティ | 標準 / 低 |
| plan | Readのみ (Edit不可) | 調査、リファクタリングの設計 | 標準 / 低 |
| acceptEdits | Read + Edit | 連続的なコード生成、プロト | 標準 / 中 |
| auto | 全アクション (AI評価) | 長時間の自律タスク、定型処理 | 高 (トークン増) / 中 |
| dontAsk | Allowルールのみ | CI/CD、ロックダウン環境 | 標準 / 中 |
| bypassPermissions | すべて (無制限) | 隔離されたコンテナ内での実行 | 標準 / 極高 |

auto モードの動的フォールバック

auto モードは現行の分類器モデル（Classifier）を使用し、破壊的変更やデータ流出を動的に検知します。分類器のモデルバージョンは Claude Code 本体のアップデートに追従するため、特定バージョンへの依存は避ける設計とします。

* Fallback 閾値: 分類器がアクションを 3回連続、またはセッション内で累計20回ブロック した場合、モードは自動的に解除され、手動承認（ask）へフォールバックします。これは AI の暴走を防ぐ重要な安全弁です。

フォールバック閾値の設定可能性

上記の閾値（連続3回 / 累計20回）はデフォルト値とし、ジェネレーターでは以下の設定項目としてカスタマイズ可能とする。

```json
{
  "autoMode": {
    "fallback": {
      "consecutiveBlockThreshold": 3,
      "sessionBlockThreshold": 20,
      "fallbackAction": "ask"
    }
  }
}
```

* `consecutiveBlockThreshold`: 連続ブロック回数の閾値（最小: 1、最大: 10、デフォルト: 3）
* `sessionBlockThreshold`: セッション累計ブロック回数の閾値（最小: 5、最大: 100、デフォルト: 20）
* `fallbackAction`: フォールバック時の動作。`ask`（手動承認）または `abort`（セッション終了）から選択

設計根拠: デフォルト値は「正常な開発フローでは到達しないが、異常な反復動作は早期に検知できる」バランスに基づく。CI/CD等の自動化環境では閾値を引き上げ、高セキュリティ環境では引き下げることを想定する。

7. ジェネレーターのUI/UX設計要件

開発者のセキュリティ意識を向上させつつ、直感的な操作を実現する要件を定義します。

* プリセットボタン:
  * フロントエンド: npm コマンド許可、src 編集 acceptEdits 設定。
  * Hardened Security: デフォルト Ask、機密パスへの絶対・相対 Deny ルール強制。
  * Vibe Coding: サンドボックス強制有効化 + auto モード推奨。

プリセット詳細定義

**フロントエンド プリセット**

| カテゴリ | ルール | アクション |
|----------|--------|-----------|
| Bash: `npm test` | テスト実行 | allow |
| Bash: `npm run *` | スクリプト実行 | allow |
| Bash: `npm install` | パッケージ追加 | ask |
| Bash: `npm publish` | パッケージ公開 | deny |
| Bash: `npx *` | npx 経由の実行 | ask |
| Edit: `src/**` | ソースコード編集 | allow (acceptEdits モード) |
| Edit: `package.json` | 依存関係変更 | ask |
| Read: `**/*` | 全ファイル読み取り | allow |

**Hardened Security プリセット**

| カテゴリ | ルール | アクション |
|----------|--------|-----------|
| Read/Edit: `.env`, `**/.env`, `**/.env.*` | 環境変数ファイル | deny |
| Read/Edit: `//.ssh/**` | SSH鍵 | deny |
| Read/Edit: `//.aws/credentials` | AWSクレデンシャル | deny |
| Read/Edit: `**/*.key`, `**/*.pem` | 秘密鍵ファイル | deny |
| Bash: `git push *` | リモートプッシュ | ask |
| Bash: `rm -rf *` | 再帰的削除 | deny |
| Bash: `curl *`, `wget *` | 外部通信 | ask |
| 動作モード | default | — |

**Vibe Coding プリセット**

| カテゴリ | ルール | アクション |
|----------|--------|-----------|
| 動作モード | auto | — |
| サンドボックス | 強制有効化 | — |
| Edit: `src/**`, `app/**` | アプリケーションコード | allow |
| Bash: `npm *`, `yarn *`, `pnpm *` | パッケージマネージャ | allow |
| Bash: `git push *` | リモートプッシュ | ask |
| Read/Edit: `.env`, `**/.env` | 環境変数ファイル | deny |
| sandbox.allowedHosts | `localhost`, `127.0.0.1` のみ | — |

Vibe Coding プリセットにおける auto モードのフォールバック: サンドボックスが有効な状態で auto モードがフォールバックした場合、サンドボックス設定は維持されたまま手動承認（ask）モードに遷移する。サンドボックスの無効化には明示的なユーザー操作を必要とする。

**Python バックエンド プリセット**

| カテゴリ | ルール | アクション |
|----------|--------|-----------|
| Bash: `python -m pytest *` | テスト実行 | allow |
| Bash: `python -m mypy *` | 型チェック | allow |
| Bash: `python -m ruff *` | リンター | allow |
| Bash: `python *.py` | スクリプト実行 | ask |
| Bash: `pip install *` | パッケージ追加 | ask |
| Bash: `pip install -e .` | 開発インストール | allow |
| Bash: `pip publish *`, `twine upload *` | パッケージ公開 | deny |
| Edit: `src/**`, `app/**`, `**/*.py` | Python ソースコード | allow (acceptEdits モード) |
| Edit: `requirements*.txt`, `pyproject.toml` | 依存関係定義 | ask |
| Read/Edit: `.env`, `**/.env` | 環境変数ファイル | deny |
| 動作モード | acceptEdits | — |

**Go バックエンド プリセット**

| カテゴリ | ルール | アクション |
|----------|--------|-----------|
| Bash: `go test *` | テスト実行 | allow |
| Bash: `go build *` | ビルド | allow |
| Bash: `go vet *` | 静的解析 | allow |
| Bash: `go run *` | プログラム実行 | ask |
| Bash: `go get *` | 依存関係追加 | ask |
| Bash: `go install *` | バイナリインストール | ask |
| Edit: `**/*.go` | Go ソースコード | allow (acceptEdits モード) |
| Edit: `go.mod`, `go.sum` | モジュール定義 | ask |
| Read/Edit: `.env`, `**/.env` | 環境変数ファイル | deny |
| 動作モード | acceptEdits | — |

**Rust プリセット**

| カテゴリ | ルール | アクション |
|----------|--------|-----------|
| Bash: `cargo test *` | テスト実行 | allow |
| Bash: `cargo build *` | ビルド | allow |
| Bash: `cargo clippy *` | リンター | allow |
| Bash: `cargo fmt *` | フォーマッタ | allow |
| Bash: `cargo run *` | プログラム実行 | ask |
| Bash: `cargo add *` | 依存関係追加 | ask |
| Bash: `cargo publish *` | クレート公開 | deny |
| Edit: `src/**/*.rs` | Rust ソースコード | allow (acceptEdits モード) |
| Edit: `Cargo.toml` | マニフェスト | ask |
| Read/Edit: `.env`, `**/.env` | 環境変数ファイル | deny |
| 動作モード | acceptEdits | — |

カスタムプリセットの作成

上記の組み込みプリセットに加え、ユーザーが独自のプリセットを定義・保存・共有できる機能を提供する。

* **保存形式**: プリセットは JSON ファイルとしてエクスポートし、`.claude/presets/` ディレクトリまたは任意のパスに保存
* **共有**: Git リポジトリにプリセットファイルを含めることで、チーム間で統一的な権限設定を適用可能
* **合成（Compose）**: 複数のプリセットを組み合わせて適用可能（例: 「Python バックエンド」+「Hardened Security」）。競合するルールは deny 優先の原則に従い解決
* インテリジェント・ツールチップ:
  * パス入力時、権限ルール（//）とサンドボックス（/）の構文差分をリアルタイムで警告。
* 統合監査機能（Sanity Check）:
  * 新しく deny ルールを追加する際、既に ~/.claude/file-history/ に当該ファイルのコピーが存在しないかスキャンし、削除を促す機能。

8. セキュリティ・ガードレールとベストプラクティス

AIを「信頼できない強力なインターン」として管理するための最終チェックリストです。

* グローバル拒否の強制: .env, .ssh, .aws/credentials に対する絶対パスベースの deny ルールをデフォルトで含めること。
* ファイル履歴の事後クリーンアップ: ~/.claude/file-history/ には編集されたファイルの平文コピーが残ります。deny ルールを設定しても過去のコピーは自動削除されないため、ジェネレーターは rm -rf ~/.claude/file-history/ の実行を促す、あるいはクリーンアップスクリプトを提供する必要があります。
* サンドボックスの有効化: Linux (bubblewrap) や macOS (Seatbelt) のサンドボックスを有効にし、OSレベルでネットワークとファイルシステムを隔離します。docker や git など、サンドボックス外で実行すべきコマンドは excludedCommands に明示的に登録します。
* ネットワーク・アウトバウンド制御: `sandbox.allowedHosts` を使用し、エージェントがアクセス可能な外部ホストを明示的にホワイトリスト化すること。データ流出（Exfiltration）防止の重要な防御層となる。デフォルトでは以下のみを許可する:
  * `localhost` / `127.0.0.1`（ローカル開発サーバー）
  * パッケージレジストリ（`registry.npmjs.org`, `pypi.org` 等、プロジェクトに応じて設定）
  * 任意のホストへの通信は明示的な追加が必要

```json
{
  "sandbox": {
    "allowedHosts": [
      "localhost",
      "127.0.0.1",
      "registry.npmjs.org"
    ]
  }
}
```

* CI/CD 環境での推奨設定: `dontAsk` モードを使用する自動化環境では、以下の環境変数とフラグの組み合わせを推奨する:
  * `--permission-mode dontAsk`: Allow ルールに一致する操作のみ自動実行
  * `--settings-file <path>`: CI専用の設定ファイルを明示指定
  * 環境変数 `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1`: テレメトリ等の非必須通信を抑制

```bash
# CI/CD パイプラインでの実行例
claude --permission-mode dontAsk \
  --settings-file .claude/settings.ci.json \
  --print "Run tests and report results"
```

9. 生成設定のバリデーションとテスト

ジェネレーターが出力する設定ファイルの品質を保証するための検証機構を定義します。

スキーマバリデーション

生成されたJSONは、出力前に以下の検証を通過する必要がある。

* **構文検証**: JSON としてパース可能であること
* **スキーマ準拠**: Claude Code が定義する settings.json のスキーマに適合すること
* **論理整合性チェック**:
  * 同一パスに対して `allow` と `deny` が同時に定義されていないこと（`deny` 優先の原則に基づき警告を表示）
  * `permissions.deny` に記載されたパスが `sandbox.filesystem.allowWrite` に含まれていないこと
  * Glob パターンの構文が有効であること（未閉じの `[` や無効な `**` 位置の検出）

設定のドライラン（Dry Run）

生成した権限ルールが意図通りに動作するかを事前検証するため、ジェネレーターはドライラン機能を提供する。

* **シミュレーション入力**: ツール名 + パス（またはコマンド）の組み合わせを入力
* **期待される出力**: 評価結果（`allow` / `deny` / `ask`）と、マッチしたルールの表示

```
# ドライラン例
$ generator dry-run --action Read --path ".env"
Result: DENY
Matched rule: { "tool": "Read", "path": "**/.env" } (permissions.deny[2])

$ generator dry-run --action Bash --command "npm test"
Result: ALLOW
Matched rule: { "tool": "Bash", "command": "npm test" } (permissions.allow[0])

$ generator dry-run --action Edit --path "src/index.ts"
Result: ALLOW
Matched rule: { "tool": "Edit", "path": "src/**" } (permissions.allow[3])
```

10. 技術仕様

アーキテクチャ概要

本ジェネレーターは Next.js の静的エクスポート（Static Export）によるクライアントサイド完結型の Web アプリケーションとして構築する。サーバーサイド処理は不要であり、生成ロジックはすべてブラウザ上で実行される。

技術スタック

| レイヤー | 技術 | 選定理由 |
|----------|------|---------|
| フレームワーク | Next.js 15 (App Router) | 静的エクスポート対応、React Server Components による初期表示の最適化 |
| 言語 | TypeScript (strict mode) | 権限ルールの型安全性を保証。設定スキーマを型として表現 |
| スタイリング | Tailwind CSS 4 | ユーティリティファーストで高速なUI構築。プリセット切り替え時のレスポンシブ対応 |
| UIコンポーネント | shadcn/ui | アクセシブルでカスタマイズ可能。フォーム要素・ツールチップ・アラートが豊富 |
| 状態管理 | Zustand | 軽量。プリセット選択・ルール編集・ドライラン状態の管理に適する |
| バリデーション | Zod | settings.json のスキーマ定義と入力バリデーションを型レベルで統合 |
| Glob マッチング | micromatch | ドライラン機能でのパスマッチング評価に使用 |
| テスト | Vitest + Testing Library | 評価ロジックの単体テスト、UIコンポーネントのインタラクションテスト |
| デプロイ | Vercel / GitHub Pages | 静的エクスポートにより CDN 配信。ゼロサーバーコスト |

ディレクトリ構成

```
src/
├── app/
│   ├── layout.tsx              # ルートレイアウト
│   ├── page.tsx                # メインページ（ジェネレーターUI）
│   └── globals.css
├── components/
│   ├── preset-selector/        # プリセット選択UI
│   ├── rule-editor/            # 権限ルール編集フォーム
│   │   ├── permission-row.tsx  # allow/deny/ask 行コンポーネント
│   │   ├── path-input.tsx      # パス入力（構文警告付き）
│   │   └── mcp-tool-input.tsx  # MCP ツール名入力
│   ├── mode-selector/          # 動作モード選択
│   ├── sandbox-config/         # サンドボックス設定
│   ├── dry-run/                # ドライランシミュレータ
│   ├── output-preview/         # JSON出力プレビュー + コピー
│   └── scope-selector/         # 出力先スコープ選択（User/Project/Managed）
├── lib/
│   ├── schema/
│   │   ├── settings.ts         # Zod スキーマ定義
│   │   └── presets.ts          # プリセット定義データ
│   ├── engine/
│   │   ├── rule-evaluator.ts   # ルール評価エンジン（deny優先ロジック）
│   │   ├── path-expander.ts    # Deny ルール自動展開（4パターン生成）
│   │   └── validator.ts        # 論理整合性チェック
│   └── utils/
│       └── glob-matcher.ts     # micromatch ラッパー
├── stores/
│   └── generator-store.ts      # Zustand ストア
└── types/
    └── settings.d.ts           # Claude Code settings.json 型定義
```

主要コンポーネントの責務

* **rule-evaluator.ts**: セクション3で定義した deny > ask > allow > fallback(ask) の評価順序を実装。ドライラン機能のコアロジック。
* **path-expander.ts**: セクション4で定義した4パターン自動生成を担当。入力されたパスから Permission Rules 用と Sandbox Config 用の両方の deny ルールを展開。
* **validator.ts**: セクション9のスキーマバリデーション・論理整合性チェックを実行。allow/deny の競合検出、Glob 構文の妥当性検証を含む。
* **output-preview**: 生成された JSON をシンタックスハイライト付きで表示。クリップボードコピーおよびファイルダウンロード（`.json`）を提供。

ビルドと出力

```bash
# 開発サーバー
npm run dev

# 静的エクスポート（output: 'export' を next.config.ts で設定）
npm run build
# → out/ ディレクトリに静的ファイルが生成される

# プレビュー
npx serve out
```

`next.config.ts` の必須設定:

```typescript
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  output: 'export',
  images: {
    unoptimized: true,
  },
}

export default nextConfig
```

セキュリティ上の考慮事項

* **クライアント完結**: 入力された権限設定はブラウザ外に送信されない。外部 API 呼び出しはゼロ。
* **依存関係の最小化**: サプライチェーン攻撃のリスクを低減するため、ランタイム依存は最小限に留める。
* **CSP ヘッダー**: 静的サイトでも Content-Security-Policy を設定し、インラインスクリプトの実行を制限する。

11. 互換性とバージョニング

仕様書および生成設定のバージョン管理

* **仕様書バージョン**: 本仕様書は Semantic Versioning に従い管理する。現在のバージョンは `v1.0.0`。
* **設定スキーマバージョン**: 生成されるJSONに `_schemaVersion` フィールドを付与し、互換性を追跡する。

```json
{
  "_schemaVersion": "1.0.0",
  "_generatedAt": "2026-03-25T00:00:00Z",
  "_generatorVersion": "1.0.0",
  "permissions": { ... }
}
```

Claude Code バージョンとの互換性

| ジェネレーター機能 | 必要な Claude Code バージョン |
|-------------------|----------------------------|
| 基本権限ルール (allow/deny/ask) | 1.0+ |
| サンドボックス設定 | 1.0+ |
| auto モード | 1.0.30+（2026年3月以降） |
| sandbox.allowedHosts | 1.0.20+ |
| Enterprise managed settings | 1.0+ |
| MCP ツール権限制御 | 1.0.10+ |

ジェネレーターは、ターゲットの Claude Code バージョンを入力として受け取り、サポートされていない機能が含まれる場合は警告を表示する。

結論

本仕様書に基づくジェネレーターは、単なる設定ファイルの書き出しツールではなく、Claude Codeが抱える「無視ルールの不備」や「ファイル履歴の残留リスク」を補完するセキュリティ・オーケストレーターとして機能します。多層防御（Defense in Depth）を自動化することで、開発者エクスペリエンスの向上と、エンタープライズレベルの安全性を両立させます。

加えて、MCP ツール権限の明示的な制御（セクション5）、Next.js 静的エクスポートによるクライアント完結型アーキテクチャ（セクション10）、スキーマバリデーション（セクション9）による出力品質の保証、バージョニング（セクション11）による長期的な互換性管理により、プロダクション環境での信頼性を担保します。

