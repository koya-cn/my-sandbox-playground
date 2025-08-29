# Gemini Image Chat MCP Server

## プロジェクト概要

Clineから利用可能なローカルMCPサーバーを作成し、Gemini 2.5 Flash Image Previewモデルを使用した画像解析機能を提供する。

## 核心要件

### 基本機能
- **画像解析**: ローカル画像ファイルとプロンプトを受け取り、Gemini APIで処理
- **MCPインターフェース**: Clineから直接呼び出し可能なツールとして提供
- **シンプル設計**: 単一ツール `gemini_image_chat` で全機能を提供

### 技術要件
- **API**: Google Generative AI (gemini-2.5-flash-image-preview)
- **プラットフォーム**: Node.js + TypeScript
- **フレームワーク**: MCP SDK
- **認証**: Gemini APIキー（環境変数）

### 使用フロー
1. ユーザーがClineに画像解析を依頼
2. Clineが適切なプロンプトを生成
3. MCPツール `gemini_image_chat` を呼び出し
4. Gemini APIで画像とプロンプトを処理
5. 結果をClineに返却

## 成功基準
- Clineから画像解析が実行できる
- Gemini 2.5 Flash Image Previewが正常に動作
- エラーハンドリングが適切に実装されている
- MCP設定が正しく構成されている

## スコープ外
- 画像生成機能
- 複雑な画像編集
- 他のGeminiモデルとの統合
- ユーザーインターフェース
