# Technical Context

## 技術スタック

### Core Technologies
- **Node.js**: JavaScript実行環境
- **TypeScript**: 型安全性とコード品質向上
- **MCP SDK**: Model Context Protocol実装
- **Google Generative AI SDK**: Gemini API接続

### API & Services
- **Gemini 2.5 Flash Image Preview**: 画像解析専用モデル
- **Google AI Studio**: APIキー管理
- **MCP Transport**: stdio通信プロトコル

## 開発環境

### 必要なツール
```bash
Node.js >= 18.0.0
npm >= 8.0.0
TypeScript >= 5.0.0
```

### 依存関係
```json
{
  "@modelcontextprotocol/sdk": "latest",
  "@google/generative-ai": "latest",
  "typescript": "^5.0.0"
}
```

### ビルド設定
- **出力ディレクトリ**: `build/`
- **エントリーポイント**: `src/index.ts`
- **実行可能ファイル**: `build/index.js`

## アーキテクチャ

### システム構成
```
Cline → MCP Client → stdio → MCP Server → Gemini API
```

### データフロー
1. **入力**: 画像パス + プロンプト
2. **処理**: 画像読み込み + Base64エンコード
3. **API呼び出し**: Gemini APIリクエスト
4. **出力**: 解析結果のテキスト

### エラーハンドリング
- **ファイル読み込みエラー**: 画像パス検証
- **API エラー**: Gemini API応答エラー
- **ネットワークエラー**: 接続タイムアウト
- **認証エラー**: APIキー検証

## セキュリティ

### 認証
- **APIキー**: 環境変数 `GEMINI_API_KEY`
- **スコープ**: 画像解析のみ
- **ローカル実行**: 外部ネットワーク接続なし（Gemini API除く）

### データ保護
- **画像データ**: ローカルファイルのみ処理
- **一時データ**: メモリ内処理、永続化なし
- **ログ**: 機密情報の除外

## パフォーマンス

### 制約事項
- **画像サイズ**: Gemini API制限に準拠
- **同時接続**: 単一リクエスト処理
- **レスポンス時間**: Gemini API依存

### 最適化
- **画像圧縮**: 必要に応じてリサイズ
- **キャッシュ**: 実装予定なし（ステートレス）
- **並行処理**: 単一スレッド実行

## 設定管理

### MCP設定
```json
{
  "mcpServers": {
    "gemini-image-chat": {
      "command": "node",
      "args": ["C:/Users/koya.yamamoto/Documents/Cline/MCP/gemini-image-chat/build/index.js"],
      "env": {
        "GEMINI_API_KEY": "user-provided-api-key"
      }
    }
  }
}
```

### 環境変数
- `GEMINI_API_KEY`: 必須、Gemini API認証
- `NODE_ENV`: オプション、開発/本番環境切り替え
