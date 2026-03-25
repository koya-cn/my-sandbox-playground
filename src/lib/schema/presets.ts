import type { PresetDefinition } from "@/types/settings";

export const presets: PresetDefinition[] = [
  {
    id: "frontend",
    name: "フロントエンド",
    description: "npm コマンド許可、src 編集 acceptEdits 設定",
    category: "frontend",
    settings: {
      permissions: {
        allow: [
          { tool: "Bash", command: "npm test" },
          { tool: "Bash", command: "npm run *" },
          { tool: "Read", path: "**/*" },
          { tool: "Edit", path: "src/**" },
        ],
        deny: [
          { tool: "Bash", command: "npm publish" },
          { tool: "Read", path: ".env" },
          { tool: "Read", path: "**/.env" },
          { tool: "Read", path: "**/.env.*" },
          { tool: "Edit", path: ".env" },
          { tool: "Edit", path: "**/.env" },
          { tool: "Edit", path: "**/.env.*" },
        ],
        ask: [
          { tool: "Bash", command: "npm install *" },
          { tool: "Bash", command: "npx *" },
          { tool: "Edit", path: "package.json" },
        ],
      },
      permissionMode: "acceptEdits",
    },
  },
  {
    id: "hardened-security",
    name: "Hardened Security",
    description: "デフォルト Ask、機密パスへの絶対・相対 Deny ルール強制",
    category: "security",
    settings: {
      permissions: {
        allow: [],
        deny: [
          { tool: "Read", path: ".env" },
          { tool: "Read", path: "**/.env" },
          { tool: "Read", path: "**/.env.*" },
          { tool: "Read", path: "//.env" },
          { tool: "Edit", path: ".env" },
          { tool: "Edit", path: "**/.env" },
          { tool: "Edit", path: "**/.env.*" },
          { tool: "Edit", path: "//.env" },
          { tool: "Read", path: "//.ssh/**" },
          { tool: "Edit", path: "//.ssh/**" },
          { tool: "Read", path: "//.aws/credentials" },
          { tool: "Edit", path: "//.aws/credentials" },
          { tool: "Read", path: "**/*.key" },
          { tool: "Read", path: "**/*.pem" },
          { tool: "Edit", path: "**/*.key" },
          { tool: "Edit", path: "**/*.pem" },
          { tool: "Bash", command: "rm -rf *" },
        ],
        ask: [
          { tool: "Bash", command: "git push *" },
          { tool: "Bash", command: "curl *" },
          { tool: "Bash", command: "wget *" },
        ],
      },
      permissionMode: "default",
    },
  },
  {
    id: "vibe-coding",
    name: "Vibe Coding",
    description: "サンドボックス強制有効化 + auto モード推奨",
    category: "experimental",
    settings: {
      permissions: {
        allow: [
          { tool: "Edit", path: "src/**" },
          { tool: "Edit", path: "app/**" },
          { tool: "Bash", command: "npm *" },
          { tool: "Bash", command: "yarn *" },
          { tool: "Bash", command: "pnpm *" },
        ],
        deny: [
          { tool: "Read", path: ".env" },
          { tool: "Read", path: "**/.env" },
          { tool: "Edit", path: ".env" },
          { tool: "Edit", path: "**/.env" },
        ],
        ask: [{ tool: "Bash", command: "git push *" }],
      },
      permissionMode: "auto",
      sandbox: {
        enabled: true,
        allowedHosts: ["localhost", "127.0.0.1"],
      },
    },
  },
  {
    id: "python-backend",
    name: "Python バックエンド",
    description: "pytest / mypy / ruff 許可、pip publish 拒否",
    category: "backend",
    settings: {
      permissions: {
        allow: [
          { tool: "Bash", command: "python -m pytest *" },
          { tool: "Bash", command: "python -m mypy *" },
          { tool: "Bash", command: "python -m ruff *" },
          { tool: "Bash", command: "pip install -e ." },
          { tool: "Edit", path: "src/**" },
          { tool: "Edit", path: "app/**" },
          { tool: "Edit", path: "**/*.py" },
        ],
        deny: [
          { tool: "Bash", command: "pip publish *" },
          { tool: "Bash", command: "twine upload *" },
          { tool: "Read", path: ".env" },
          { tool: "Read", path: "**/.env" },
          { tool: "Edit", path: ".env" },
          { tool: "Edit", path: "**/.env" },
        ],
        ask: [
          { tool: "Bash", command: "python *.py" },
          { tool: "Bash", command: "pip install *" },
          { tool: "Edit", path: "requirements*.txt" },
          { tool: "Edit", path: "pyproject.toml" },
        ],
      },
      permissionMode: "acceptEdits",
    },
  },
  {
    id: "go-backend",
    name: "Go バックエンド",
    description: "go test / build / vet 許可",
    category: "backend",
    settings: {
      permissions: {
        allow: [
          { tool: "Bash", command: "go test *" },
          { tool: "Bash", command: "go build *" },
          { tool: "Bash", command: "go vet *" },
          { tool: "Edit", path: "**/*.go" },
        ],
        deny: [
          { tool: "Read", path: ".env" },
          { tool: "Read", path: "**/.env" },
          { tool: "Edit", path: ".env" },
          { tool: "Edit", path: "**/.env" },
        ],
        ask: [
          { tool: "Bash", command: "go run *" },
          { tool: "Bash", command: "go get *" },
          { tool: "Bash", command: "go install *" },
          { tool: "Edit", path: "go.mod" },
          { tool: "Edit", path: "go.sum" },
        ],
      },
      permissionMode: "acceptEdits",
    },
  },
  {
    id: "rust",
    name: "Rust",
    description: "cargo test / build / clippy / fmt 許可",
    category: "backend",
    settings: {
      permissions: {
        allow: [
          { tool: "Bash", command: "cargo test *" },
          { tool: "Bash", command: "cargo build *" },
          { tool: "Bash", command: "cargo clippy *" },
          { tool: "Bash", command: "cargo fmt *" },
          { tool: "Edit", path: "src/**/*.rs" },
        ],
        deny: [
          { tool: "Bash", command: "cargo publish *" },
          { tool: "Read", path: ".env" },
          { tool: "Read", path: "**/.env" },
          { tool: "Edit", path: ".env" },
          { tool: "Edit", path: "**/.env" },
        ],
        ask: [
          { tool: "Bash", command: "cargo run *" },
          { tool: "Bash", command: "cargo add *" },
          { tool: "Edit", path: "Cargo.toml" },
        ],
      },
      permissionMode: "acceptEdits",
    },
  },
];
