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

Permission Rules のパスパターン仕様（公式ドキュメント準拠）

Claude Code 公式ドキュメント（`code.claude.com/docs/en/permissions`）に基づくパスパターンは以下の4種類:

| パターン | 意味 | 例 | マッチ対象 |
|----------|------|-----|-----------|
| `//path` | ファイルシステムルートからの**絶対パス** | `Read(//Users/alice/secrets/**)` | `/Users/alice/secrets/**` |
| `~/path` | **ホームディレクトリ**からのパス | `Read(~/Documents/*.pdf)` | `/Users/alice/Documents/*.pdf` |
| `/path` | **プロジェクトルート**からの相対パス | `Edit(/src/**/*.ts)` | `<project root>/src/**/*.ts` |
| `path` or `./path` | **カレントディレクトリ**からの相対パス | `Read(*.env)` | `<cwd>/*.env` |

**注意**: `/Users/alice/file` は絶対パスではなく、プロジェクトルートからの相対パスとして解釈される。絶対パスには必ず `//` プレフィックスが必要。

Permission Rules のルール文字列フォーマット

Claude Code の設定ファイルでは、権限ルールは `Tool(specifier)` 形式の文字列として記述する:

```json
{
  "permissions": {
    "allow": [
      "Bash(npm run *)",
      "Read(src/**)",
      "Edit(/src/**/*.ts)"
    ],
    "deny": [
      "Bash(git push *)",
      "Read(*.env)",
      "Read(**/.env)",
      "Read(//Users/alice/.ssh/**)"
    ]
  }
}
```

ジェネレーターは内部的にはオブジェクト形式 `{ tool, path?, command? }` で管理するが、最終出力時には上記の文字列フォーマットに変換すること。

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
  * Python バックエンド: pytest / mypy / ruff 許可、pip publish 拒否。
  * Go バックエンド: go test / build / vet 許可。
  * Rust: cargo test / build / clippy / fmt 許可。
  * Laravel: php artisan / composer 許可、.env・DB破壊系コマンドは制御。
  * Laravel Sail: sail コマンド許可、artisan/composer は sail 経由で制御。

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

**Laravel プリセット**

| カテゴリ | ルール | アクション |
|----------|--------|-----------|
| Bash: `php artisan test *` | テスト実行 | allow |
| Bash: `php artisan make:*` | スキャフォールド生成 | allow |
| Bash: `php artisan route:list *` | ルート一覧 | allow |
| Bash: `php artisan config:cache/clear *` | 設定キャッシュ | allow |
| Bash: `php artisan cache:clear *` | キャッシュクリア | allow |
| Bash: `php artisan view:clear *` | ビュークリア | allow |
| Bash: `php artisan migrate` | マイグレーション実行 | ask |
| Bash: `php artisan migrate:*` | マイグレーション管理 (fresh/rollback 等) | ask |
| Bash: `php artisan db:seed *` | シーダー実行 | ask |
| Bash: `php artisan down *` | メンテナンスモード | deny |
| Bash: `composer install` | 依存関係インストール | allow |
| Bash: `composer dump-autoload *` | オートローダー再生成 | allow |
| Bash: `composer require *` | パッケージ追加 | ask |
| Bash: `composer update *` | パッケージ更新 | ask |
| Edit: `app/**` | アプリケーションコード | allow (acceptEdits モード) |
| Edit: `resources/**` | ビュー・アセット | allow |
| Edit: `routes/**` | ルート定義 | allow |
| Edit: `tests/**` | テストコード | allow |
| Edit: `database/migrations/**` | マイグレーション | allow |
| Edit: `database/seeders/**` | シーダー | allow |
| Edit: `database/factories/**` | ファクトリ | allow |
| Edit: `config/**` | 設定ファイル | ask |
| Edit: `composer.json` | 依存関係定義 | ask |
| Read/Edit: `.env`, `**/.env`, `**/.env.*` | 環境変数ファイル (APP_KEY, DB credentials 等) | deny |
| 動作モード | acceptEdits | — |

**Laravel Sail プリセット**

Laravel Sail（Docker ベースの開発環境）を使用するプロジェクト向け。コマンドはすべて `./vendor/bin/sail` 経由で実行する。

| カテゴリ | ルール | アクション |
|----------|--------|-----------|
| Bash: `./vendor/bin/sail up/down *` | コンテナ起動・停止 | allow |
| Bash: `./vendor/bin/sail artisan test *` | テスト実行 | allow |
| Bash: `./vendor/bin/sail artisan make:*` | スキャフォールド生成 | allow |
| Bash: `./vendor/bin/sail artisan config:cache/clear *` | 設定キャッシュ | allow |
| Bash: `./vendor/bin/sail artisan cache:clear *` | キャッシュクリア | allow |
| Bash: `./vendor/bin/sail artisan view:clear *` | ビュークリア | allow |
| Bash: `./vendor/bin/sail artisan migrate` | マイグレーション実行 | ask |
| Bash: `./vendor/bin/sail artisan migrate:*` | マイグレーション管理 | ask |
| Bash: `./vendor/bin/sail artisan db:seed *` | シーダー実行 | ask |
| Bash: `./vendor/bin/sail artisan down *` | メンテナンスモード | deny |
| Bash: `./vendor/bin/sail composer install` | 依存関係インストール | allow |
| Bash: `./vendor/bin/sail composer dump-autoload *` | オートローダー再生成 | allow |
| Bash: `./vendor/bin/sail composer require *` | パッケージ追加 | ask |
| Bash: `./vendor/bin/sail composer update *` | パッケージ更新 | ask |
| Bash: `./vendor/bin/sail npm *` | Node.js 操作 | allow |
| Bash: `./vendor/bin/sail shell *` | コンテナシェル | allow |
| Edit: `app/**`, `resources/**`, `routes/**`, `tests/**` | アプリケーションコード | allow (acceptEdits モード) |
| Edit: `database/migrations/**`, `seeders/**`, `factories/**` | DB 定義 | allow |
| Edit: `config/**` | 設定ファイル | ask |
| Edit: `composer.json` | 依存関係定義 | ask |
| Edit: `docker-compose.yml` | Sail 環境設定 | ask |
| Read/Edit: `.env`, `**/.env`, `**/.env.*` | 環境変数ファイル | deny |
| 動作モード | acceptEdits | — |

Add-on プリセット（マージ合成）

ベースプリセット（Frontend, Hardened Security 等）に加え、特定のツールチェーン用の **Add-on プリセット** を提供する。Add-on はベースプリセットを置換せず、既存ルールに重複なくマージ（合成）される。

**プリセットの型定義**:
* `type: "base"` — 従来のプリセット。適用時に既存ルールを置換する（デフォルト）
* `type: "addon"` — 既存ルールにマージして追加。複数の Add-on を同時に適用可能

**組み込み Add-on プリセット**:

| Add-on | allow | ask | 用途 |
|--------|-------|-----|------|
| **Git Operations** | `git *` | `git commit *`, `git push *` | Git 操作全般を許可し、コミット・プッシュは確認 |
| **Docker Operations** | `docker ps *`, `docker logs *`, `docker compose up *`, `docker compose down *`, `docker build *` | `docker rm *`, `docker rmi *`, `docker system prune *`, `docker push *` | Docker 操作の許可と破壊系の確認 |

**マージの動作**:
* ベースプリセット適用時、適用済みの Add-on は自動的に再マージされる（Add-on が外れない）
* Add-on のトグルオフ時は、該当 Add-on のルールのみが除去される
* ルールの重複判定は `tool` + `path` + `command` の完全一致で行う
* Clear All 時はベースプリセットと全 Add-on がリセットされる

**UI 表示**:
* ベースプリセットと Add-on は分離して表示する
* Add-on ボタンは `+` / `-` のプレフィックスで適用状態を示す
* Add-on カテゴリは `addon` として、専用の配色（amber）で Badge 表示する

カスタムプリセットの作成

上記の組み込みプリセットに加え、ユーザーが独自のプリセットを定義・保存・共有できる機能を提供する。

* **保存形式**: プリセットは JSON ファイルとしてエクスポートし、`.claude/presets/` ディレクトリまたは任意のパスに保存
* **共有**: Git リポジトリにプリセットファイルを含めることで、チーム間で統一的な権限設定を適用可能
* **合成（Compose）**: 複数のプリセットを組み合わせて適用可能（例: 「Python バックエンド」+「Git Operations」Add-on）。競合するルールは deny 優先の原則に従い解決

パス構文のインラインバリデーション

パス入力フィールドでは、以下のリアルタイム警告を表示する:

* **`/` 始まりの検出**: Permission Rules の絶対パスは `//` プレフィックスが必要。`/` で始まるパスを入力した場合、「Permission Rules の絶対パスは `//` プレフィックスです（例: `//.ssh/**`）」と即時警告を表示する。
* **Glob 構文エラー**: 未閉じの `[` や無効な `**` 位置を検出した場合に警告を表示する。

公式ドキュメントへのリンク統合

各UIセクションのカードヘッダーにインフォアイコン（i マーク）を配置し、対応する Claude Code 公式ドキュメントのセクションへ直接リンクする。リンク先はすべて `https://code.claude.com/docs/en/` 配下とする。

| UIセクション | リンク先パス | ラベル |
|-------------|-------------|--------|
| ヘッダー（グローバル） | `permissions` | Permissions |
| ヘッダー（グローバル） | `settings` | Settings |
| ヘッダー（グローバル） | `sandboxing` | Sandbox |
| Presets | `permissions#example-configurations` | Examples |
| Permission Rules | `permissions#permission-rule-syntax` | Docs |
| Permission Mode | `permissions#permission-modes` | — |
| Sandbox | `sandboxing` | Docs |
| Output | `settings#settings-files` | Settings Files |
| Dry Run | `permissions#manage-permissions` | — |

ステップガイドUI

ヘッダー直下に3ステップの操作フローカードを表示し、初回ユーザーが迷わず操作できるようにする:

1. **プリセットを選ぶ or ルールを手動追加** — 開発環境に合ったプリセットでベースを設定。カスタムルールの追加も可能。
2. **モードとサンドボックスを調整** — 動作モード（default / auto / acceptEdits 等）とネットワーク制限を設定。
3. **Validate & Download** — 設定の整合性を検証し、Dry Run で動作を確認。JSON をコピーまたはダウンロード。

各セクションの詳細説明テキスト

各 UI コンポーネントの CardDescription には、以下の情報を含めること:

* **そのセクションが何を制御するか**の一文説明
* **初心者向けのヒント**（例: 「Deny は常に Allow に優先する Fail-closed 設計です」）
* **Permission Mode**: 各モードに対して、推奨ユースケースとリスクレベルに加え、2〜3文の詳細説明を表示する。`bypassPermissions` 選択時は赤い警告アラートを表示する。
* **Rule Editor**: Deny / Ask / Allow の各タブ内に、そのアクションの意味と使用例を背景色付きブロックで表示する。

Language 設定

Output セクションに `language` トグルを配置する。ON にすると生成 JSON に `"language": "日本語"` が含まれ、Claude Code の応答言語が日本語に設定される。

* **配置位置**: Scope セレクタと Validate ボタンの間
* **JSON 出力順序**: `language` フィールドはメタ情報の直後、`permissions` の直前に配置する
* **デフォルト**: OFF（language フィールドを出力しない）

Output Scope の優先度表示

Scope セレクタの各項目に以下の情報を追加表示する:

| スコープ | Priority | 説明 |
|----------|----------|------|
| Enterprise | 1 | 組織全体に強制適用。管理者のみ設定可能 |
| User | 2 | 全プロジェクト共通のユーザー個人設定 |
| Shared Project | 3 | チームで共有。Git で管理可能 |
| Local Project | 4 | 個人用のプロジェクト設定。Git 管理外 |

Output path の表示は、プライマリカラーの枠線・背景色で強調し、スコープ名の Badge を併記する。

リアルタイムプレビュー連動

左カラム（Configure）での設定変更は、右カラム（Output）の JSON プレビューに即時反映される。

* 実装上、Zustand ストアの `settings` オブジェクトを依存配列に含め、変更検知時にJSON出力を再生成する。
* `_generatedAt` 等のタイムスタンプはクライアント側でのみ生成する（SSR/Hydration 不整合の回避）。

統合監査機能（Sanity Check）:
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
│   ├── layout.tsx                # ルートレイアウト
│   ├── page.tsx                  # メインページ（ジェネレーターUI + ステップガイド）
│   └── globals.css
├── components/
│   ├── ui/                       # shadcn/ui ベースコンポーネント
│   │   ├── info-link.tsx         # 公式ドキュメントへのリンクアイコン
│   │   ├── button.tsx, card.tsx, select.tsx, ...
│   ├── preset-selector/          # プリセット選択UI
│   ├── rule-editor/              # 権限ルール編集フォーム
│   │   └── permission-row.tsx    # allow/deny/ask 行（ツール選択 + パス入力 + 構文警告）
│   ├── mode-selector/            # 動作モード選択（詳細説明 + リスク表示）
│   ├── sandbox-config/           # サンドボックス設定（allowedHosts 管理）
│   ├── dry-run/                  # ドライランシミュレータ
│   ├── output-preview/           # JSON出力プレビュー + Copy/Download + バリデーション
│   └── scope-selector/           # 出力先スコープ選択（User/Project/Managed）
├── lib/
│   ├── schema/
│   │   ├── settings.ts           # Zod スキーマ定義
│   │   └── presets.ts            # プリセット定義データ（8プリセット）
│   ├── engine/
│   │   ├── rule-evaluator.ts     # ルール評価エンジン（deny優先ロジック）
│   │   ├── path-expander.ts      # Deny ルール自動展開（4パターン生成）
│   │   ├── validator.ts          # 論理整合性チェック
│   │   └── settings-generator.ts # 最終JSON出力生成（メタデータ付与）
│   └── utils/
│       └── glob-matcher.ts       # micromatch ラッパー
├── stores/
│   └── generator-store.ts        # Zustand ストア（全UI状態の一元管理）
└── types/
    └── settings.ts               # Claude Code settings.json 型定義
```

主要コンポーネントの責務

* **rule-evaluator.ts**: セクション3で定義した deny > ask > allow > fallback(ask) の評価順序を実装。ドライラン機能のコアロジック。MCP ツールのワイルドカードマッチング（`mcp__*__*`）にも対応。
* **path-expander.ts**: セクション4で定義した4パターン自動生成を担当。入力されたパスから Permission Rules 用と Sandbox Config 用の両方の deny ルールを展開。
* **validator.ts**: セクション9のスキーマバリデーション・論理整合性チェックを実行。allow/deny の競合検出、Glob 構文の妥当性検証、機密パス未設定の警告、bypassPermissions/auto モードのリスク警告を含む。
* **settings-generator.ts**: Zustand ストアの内部状態から最終的な JSON 出力を生成。メタデータ（`_schemaVersion`, `_generatedAt`, `_generatorVersion`）の付与、空ルールのフィルタリングを担当。
* **generator-store.ts**: Zustand による全UI状態の一元管理。プリセット適用、ルール CRUD、モード切替、サンドボックス設定、ドライラン実行、バリデーション実行を提供。
* **info-link.tsx**: 各セクションカードに配置する公式ドキュメントへのリンクアイコンコンポーネント。ベースURL `https://code.claude.com/docs/en/` を共通定義し、相対パスで各セクションにリンク。

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

const isProd = process.env.NODE_ENV === 'production'

const nextConfig: NextConfig = {
  output: 'export',
  basePath: isProd ? '/my-sandbox-playground' : '',
  images: {
    unoptimized: true,
  },
}

export default nextConfig
```

マルチツール構成とルーティング

本ジェネレーターは複数ツールを収容するハブサイトのサブルートとして配置する:

| パス | 内容 |
|------|------|
| `/` | ツール一覧ハブページ |
| `/permission-generator` | 本ジェネレーター |
| `/another-tool` | 将来のツール（拡張用） |

`basePath` は GitHub Pages のリポジトリ名パス（`/my-sandbox-playground`）に対応し、本番ビルド時のみ付与される。開発時は空文字となる。

デプロイ構成

| 環境 | ホスト | 用途 | トリガー |
|------|--------|------|---------|
| 本番 | GitHub Pages | 公開サイト | `main` ブランチへの push |
| プレビュー | Vercel | PR ごとのプレビューURL | PR 作成・更新時 |

GitHub Pages へのデプロイは GitHub Actions（`.github/workflows/deploy.yml`）で自動化する。`npm run build` の出力（`out/` ディレクトリ）を `actions/upload-pages-artifact` でアップロードし、`actions/deploy-pages` でデプロイする。

公開URL: `https://koya-cn.github.io/my-sandbox-playground/`

レスポンシブ・UI品質要件

* **Select コンポーネント**: トリガー要素は親コンテナの全幅（`w-full`）を占める。ドロップダウンのポップアップはトリガーと同じ幅を最小幅とし、内容が長い場合は自動拡張する。
* **テキストオーバーフロー**: Select 内の説明テキストや長いパス文字列は `truncate`（省略表示）で処理する。プリセットボタン内のテキストは `whitespace-normal` で折り返す。
* **JSON プレビュー**: `break-all whitespace-pre-wrap` で長い文字列を折り返し、横スクロールを最小化する。ScrollArea で縦方向にスクロール可能にする。
* **Permission Row**: flex レイアウトで `min-w-0` を設定し、子要素の縮小を許可。ツール Select は `shrink-0` で固定幅を維持し、パス入力が残りの幅を占める。
* **モバイル対応**: 2カラムレイアウト（Configure / Output）は `lg:` ブレークポイントで切り替え、モバイルでは1カラムにスタックする。

SSR/Hydration 対策

Next.js の静的エクスポートでは、サーバーレンダリング時とクライアント側でHTMLが一致する必要がある（Hydration）。以下の対策を適用する:

* **動的な値**（`new Date().toISOString()` 等のタイムスタンプ）はサーバー側でレンダリングせず、`useEffect` でクライアント側のみで生成する。
* **Zustand ストアの関数参照**: `useEffect` の依存配列には関数参照ではなく、実際のデータ（`settings` オブジェクト等）を含めることで、状態変更時の再レンダリングを確実にする。

セキュリティ上の考慮事項

* **クライアント完結**: 入力された権限設定はブラウザ外に送信されない。外部 API 呼び出しはゼロ。
* **依存関係の最小化**: サプライチェーン攻撃のリスクを低減するため、ランタイム依存は最小限に留める。
* **CSP ヘッダー**: 静的サイトでも Content-Security-Policy を設定し、インラインスクリプトの実行を制限する。

11. 互換性とバージョニング

JSON フィールド順序の規約

`language` フィールドは `permissions` の直前に配置する。

```json
{
  "language": "日本語",
  "permissions": { ... },
  "permissionMode": "...",
  "sandbox": { ... },
  "autoMode": { ... }
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

