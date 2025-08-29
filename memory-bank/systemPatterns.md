# System Patterns

## アーキテクチャパターン

### MCP Server Pattern
```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│    Cline    │───▶│ MCP Server  │───▶│ Gemini API  │
│   Client    │    │   (stdio)   │    │   Service   │
└─────────────┘    └─────────────┘    └─────────────┘
```

### 責任分離
- **Cline**: ユーザーインターフェース、プロンプト生成
- **MCP Server**: プロトコル変換、画像処理、API呼び出し
- **Gemini API**: 画像解析、自然言語生成

## 設計パターン

### Single Responsibility Pattern
各コンポーネントは単一の責任を持つ：
- **ImageProcessor**: 画像ファイルの読み込みとエンコード
- **GeminiClient**: API通信とレスポンス処理
- **MCPHandler**: MCPプロトコルの実装

### Error Handling Pattern
```typescript
try {
  // 画像処理
  const imageData = await processImage(imagePath);
  // API呼び出し
  const result = await callGeminiAPI(imageData, prompt);
  return { success: true, data: result };
} catch (error) {
  return { success: false, error: error.message };
}
```

### Configuration Pattern
環境変数による設定管理：
```typescript
const config = {
  apiKey: process.env.GEMINI_API_KEY,
  model: 'gemini-2.5-flash-image-preview',
  maxImageSize: 4 * 1024 * 1024 // 4MB
};
```

## データフローパターン

### Request Processing Flow
1. **入力検証**: パラメータの型チェック
2. **画像読み込み**: ファイル存在確認とBase64変換
3. **API呼び出し**: Gemini APIリクエスト
4. **レスポンス処理**: 結果の整形と返却

### Error Propagation Flow
```
File Error → Validation Error → API Error → Client Error
     ↓              ↓              ↓           ↓
  File Not     Invalid Params   API Failure  MCP Error
   Found         Format         Network      Response
```

## 通信パターン

### MCP Protocol Pattern
```typescript
// Tool Definition
{
  name: 'gemini_image_chat',
  description: 'Gemini 2.5 Flash Image Previewで画像分析',
  inputSchema: {
    type: 'object',
    properties: {
      image_path: { type: 'string' },
      prompt: { type: 'string' }
    },
    required: ['image_path', 'prompt']
  }
}

// Tool Execution
async function handleToolCall(request) {
  const { image_path, prompt } = request.params.arguments;
  // 処理実行
  return { content: [{ type: 'text', text: result }] };
}
```

### Stdio Transport Pattern
- **入力**: JSON-RPC over stdin
- **出力**: JSON-RPC over stdout
- **エラー**: stderr for logging

## セキュリティパターン

### API Key Management
```typescript
// 環境変数からの安全な読み込み
const apiKey = process.env.GEMINI_API_KEY;
if (!apiKey) {
  throw new Error('GEMINI_API_KEY environment variable is required');
}

// APIキーのマスキング
console.log(`Using API key: ${apiKey.substring(0, 8)}...`);
```

### Input Validation Pattern
```typescript
function validateImagePath(path: string): boolean {
  // パス検証
  if (!path || typeof path !== 'string') return false;
  // ファイル存在確認
  if (!fs.existsSync(path)) return false;
  // 拡張子チェック
  const validExtensions = ['.jpg', '.jpeg', '.png', '.webp'];
  return validExtensions.some(ext => path.toLowerCase().endsWith(ext));
}
```

## パフォーマンスパターン

### Lazy Loading Pattern
```typescript
class GeminiImageServer {
  private geminiClient?: GoogleGenerativeAI;
  
  private getGeminiClient() {
    if (!this.geminiClient) {
      this.geminiClient = new GoogleGenerativeAI(this.apiKey);
    }
    return this.geminiClient;
  }
}
```

### Resource Management Pattern
```typescript
async function processImage(imagePath: string) {
  let fileHandle;
  try {
    fileHandle = await fs.open(imagePath, 'r');
    const buffer = await fileHandle.readFile();
    return buffer.toString('base64');
  } finally {
    await fileHandle?.close();
  }
}
```

## 拡張パターン

### Plugin Architecture
将来的な機能拡張のための設計：
```typescript
interface ImageProcessor {
  process(imagePath: string): Promise<string>;
}

class Base64ImageProcessor implements ImageProcessor {
  async process(imagePath: string): Promise<string> {
    // Base64エンコード実装
  }
}

class CompressedImageProcessor implements ImageProcessor {
  async process(imagePath: string): Promise<string> {
    // 圧縮 + Base64エンコード実装
  }
}
