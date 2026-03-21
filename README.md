# Azure WebApp Monorepo

Azure 上で動作する一般的な Web アプリのインフラ一式 (Terraform) とアプリケーション。

## 構成

```
├── app/          # Go Web アプリケーション (最小構成)
├── infra/        # Terraform (Azure インフラ)
├── Makefile      # 共通コマンド
└── .gitignore
```

## Azure リソース構成

| リソース | 用途 |
|----------|------|
| Resource Group | リソースのグループ化 |
| VNet + Subnets | ネットワーク分離 |
| App Service (Linux) | コンテナベースの Web アプリ実行 |
| Azure Container Registry | Docker イメージ管理 |
| PostgreSQL Flexible Server | データベース |
| Key Vault | シークレット管理 |
| Application Insights | 監視・ログ |
| Log Analytics Workspace | ログ集約 |

## セットアップ

### 前提条件

- Terraform >= 1.5
- Azure CLI (`az login` 済み)
- Go >= 1.22
- Docker

### インフラ構築

```bash
make infra-init       # Terraform 初期化
make infra-plan       # 実行計画の確認
make infra-apply      # リソース作成
```

### アプリデプロイ

```bash
make docker-build     # Docker イメージビルド
make docker-push      # ACR へプッシュ
make deploy           # App Service を更新
```

### 環境設定

`infra/terraform.tfvars` を作成して値を上書き:

```hcl
project     = "myapp"
environment = "prod"
location    = "japaneast"
app_sku_name = "P1v3"
```

## クリーンアップ

```bash
make infra-destroy
```
