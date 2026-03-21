# 詳細リファレンスガイド

> 本ドキュメントは、このリポジトリで使用している各技術・各 Azure リソースについて、
> Microsoft 公式ドキュメント・HashiCorp 公式ドキュメント・Docker 公式ドキュメントの記載内容に基づいて詳細に解説するものです。

---

## 目次

1. [プロジェクト構成の全体像](#1-プロジェクト構成の全体像)
2. [Terraform（インフラ定義ツール）](#2-terraformインフラ定義ツール)
3. [Azure Resource Group](#3-azure-resource-group)
4. [Azure Virtual Network（VNet）・Subnet・NSG](#4-azure-virtual-networkvnetsubnetnsg)
5. [Azure App Service（Web アプリ実行環境）](#5-azure-app-serviceweb-アプリ実行環境)
6. [Azure Database for PostgreSQL Flexible Server](#6-azure-database-for-postgresql-flexible-server)
7. [Azure Container Registry（ACR）](#7-azure-container-registryacr)
8. [Azure Key Vault](#8-azure-key-vault)
9. [Azure Application Insights / Log Analytics](#9-azure-application-insights--log-analytics)
10. [Go アプリケーション](#10-go-アプリケーション)
11. [Docker / Dockerfile](#11-docker--dockerfile)
12. [Makefile（操作コマンド）](#12-makefile操作コマンド)
13. [Terraform 変数リファレンス](#13-terraform-変数リファレンス)
14. [Terraform 出力値リファレンス](#14-terraform-出力値リファレンス)
15. [セキュリティ設計の解説](#15-セキュリティ設計の解説)
16. [参考リンク集](#16-参考リンク集)

---

## 1. プロジェクト構成の全体像

```
azure-webapp-monorepo/
├── app/                  # Go Web アプリケーション
│   ├── main.go           # エントリポイント（HTTP サーバー）
│   ├── go.mod            # Go モジュール定義
│   └── Dockerfile        # マルチステージビルド用 Dockerfile
├── infra/                # Terraform 構成ファイル群
│   ├── versions.tf       # Terraform・プロバイダのバージョン制約
│   ├── variables.tf      # 入力変数と locals 定義
│   ├── resource_group.tf # リソースグループ
│   ├── network.tf        # VNet / Subnet / NSG / Private DNS Zone
│   ├── app_service.tf    # App Service Plan + Linux Web App
│   ├── database.tf       # PostgreSQL Flexible Server + DB
│   ├── acr.tf            # Azure Container Registry
│   ├── keyvault.tf       # Key Vault + RBAC + シークレット
│   ├── monitoring.tf     # Log Analytics Workspace + Application Insights
│   ├── outputs.tf        # 出力値定義
│   └── terraform.tfvars.example  # 変数ファイルのサンプル
├── Makefile              # 共通操作コマンド
├── .gitignore            # Git 除外ルール
└── README.md             # プロジェクト概要
```

---

## 2. Terraform（インフラ定義ツール）

### 2.1 Terraform とは

HashiCorp 公式ドキュメント（https://developer.hashicorp.com/terraform/intro）による定義：

> HashiCorp Terraform is an infrastructure as code tool that lets you define both cloud and on-prem resources in human-readable configuration files that you can version, reuse, and share.

Terraform は **Infrastructure as Code (IaC)** ツールであり、クラウドやオンプレミスのリソースを人間が読める設定ファイル（`.tf` ファイル）で定義し、バージョン管理・再利用・共有できるようにするものです。

### 2.2 コアワークフロー（3 ステージ）

Terraform 公式ドキュメントに記載されたコアワークフローは以下の 3 段階です：

| ステージ | 説明 |
|---|---|
| **Write** | リソースを定義する。複数のクラウドプロバイダやサービスにまたがる構成を記述可能 |
| **Plan** | 既存のインフラと設定を比較し、作成・更新・削除される内容を示す実行計画を生成する |
| **Apply** | 承認後、リソースの依存関係を考慮した正しい順序で操作を実行する |

### 2.3 State（状態管理）

Terraform は **state ファイル**（デフォルトは `terraform.tfstate`）で実際のインフラの状態を追跡します。このファイルはリソースの現在の状態を記録しており、`plan` 実行時に設定ファイルとの差分を計算するために使われます。

本リポジトリでは `.gitignore` で以下を除外しています：

```
infra/*.tfstate
infra/*.tfstate.backup
infra/.terraform.tfstate.lock.info
```

> ⚠️ **state ファイルにはシークレット情報（DB パスワード等）が含まれる場合があります。** チーム開発では Azure Storage や HCP Terraform 等のリモートバックエンドの使用を推奨します。

### 2.4 本リポジトリで使用しているプロバイダ

`infra/versions.tf` で定義：

```hcl
terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
```

| プロバイダ | 説明 |
|---|---|
| **hashicorp/azurerm** | Azure Resource Manager API を通じて Azure リソースを管理するプロバイダ。Terraform Registry（https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs）で公開されている。認証方法として Azure CLI・マネージド ID・サービスプリンシパル（クライアント証明書/シークレット）・OpenID Connect をサポート |
| **hashicorp/random** | ランダム値（パスワード等）を生成するユーティリティプロバイダ。本リポジトリでは DB パスワードの生成に使用 |

#### `~> 3.100` の意味（バージョン制約）

`~>` は「悲観的バージョン制約（pessimistic constraint operator）」と呼ばれ、`~> 3.100` は `>= 3.100, < 4.0` と同義です。つまり 3.x 系の 3.100 以上を許容し、メジャーバージョン 4 は使用しません。

#### `provider "azurerm"` ブロックの設定

```hcl
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
}
```

- `features {}` ブロックは azurerm プロバイダで**必須**
- `purge_soft_delete_on_destroy = false`：Key Vault リソースを `terraform destroy` で削除した際、論理削除（soft delete）状態にとどめ、完全削除（purge）しない設定。これにより誤削除時の復旧が可能

### 2.5 主要 CLI コマンド

| コマンド | 説明 |
|---|---|
| `terraform init` | 作業ディレクトリを初期化し、プロバイダプラグインをダウンロードする。最初に 1 回実行が必要 |
| `terraform plan` | 現在の state と設定ファイルを比較し、実行計画を表示する。実際の変更は行わない |
| `terraform apply` | 実行計画に基づいてリソースを作成・変更・削除する。確認プロンプトあり |
| `terraform destroy` | 管理下の全リソースを削除する。確認プロンプトあり |
| `terraform output` | 定義された出力値を表示する |

---

## 3. Azure Resource Group

### 3.1 概要

Azure のリソースグループは、Azure ソリューションの関連リソースを保持するコンテナです。リソースグループ内のリソースはグループとしてまとめてデプロイ・更新・削除できます。

### 3.2 本リポジトリの定義（`resource_group.tf`）

```hcl
resource "azurerm_resource_group" "main" {
  name     = "${local.name_prefix}-rg"
  location = var.location
  tags     = local.common_tags
}
```

| 属性 | 値 | 説明 |
|---|---|---|
| `name` | `webapp-dev-rg`（デフォルト） | `{project}-{environment}-rg` の命名規則 |
| `location` | `japaneast`（デフォルト） | リソースが作成される Azure リージョン |
| `tags` | `Project`, `Environment`, `ManagedBy` | すべてのリソースに共通で付与されるタグ |

### 3.3 命名規則と tags

`variables.tf` の `locals` ブロックで定義：

```hcl
locals {
  name_prefix = "${var.project}-${var.environment}"
  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags,
  )
}
```

- `name_prefix` はすべてのリソース名のプレフィックスとして使用される
- `common_tags` はすべてのリソースに付与され、コスト管理やリソースの識別に役立つ
- `ManagedBy = "terraform"` タグにより、Terraform 管理のリソースであることを明示

---

## 4. Azure Virtual Network（VNet）・Subnet・NSG

### 4.1 Azure Virtual Network とは

Microsoft 公式ドキュメント（https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview）による定義：

> Azure Virtual Network provides the fundamental building block for your private network in Azure. This service enables Azure resources like virtual machines (VMs) to securely communicate with each other, the internet, and on-premises networks.

Azure Virtual Network は Azure 上のプライベートネットワークの基本的な構成要素です。VNet を使うことで、Azure リソース同士の安全な通信、インターネットとの通信、オンプレミスネットワークとの通信が可能になります。

公式ドキュメントに記載されている主な利用シナリオ：

- Azure リソースとインターネット間の通信
- Azure リソース間の通信
- オンプレミスリソースとの通信
- ネットワークトラフィックのフィルタリング
- ネットワークトラフィックのルーティング
- Azure サービスとの統合

### 4.2 本リポジトリのネットワーク構成（`network.tf`）

#### VNet

```hcl
resource "azurerm_virtual_network" "main" {
  name                = "${local.name_prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  ...
}
```

- **アドレス空間**：`10.0.0.0/16`（65,536 個の IP アドレス）
- RFC 1918 で定義されたプライベートアドレス範囲を使用

#### サブネット構成

| サブネット名 | CIDR | 用途 | Delegation | Service Endpoints |
|---|---|---|---|---|
| `app` | `10.0.1.0/24`（256 IP） | App Service の VNet 統合用 | `Microsoft.Web/serverFarms` | `Microsoft.Storage`, `Microsoft.KeyVault` |
| `db` | `10.0.2.0/24`（256 IP） | PostgreSQL Flexible Server 配置用 | `Microsoft.DBforPostgreSQL/flexibleServers` | `Microsoft.Storage` |
| `private-endpoints` | `10.0.3.0/24`（256 IP） | 将来の Private Endpoint 拡張用 | なし | なし |

#### Subnet Delegation とは

サブネットの Delegation（委任）は、特定の Azure サービスがそのサブネットに専用のリソースを配置できるようにする仕組みです。委任されたサブネットには、そのサービス以外のリソースは配置できません。

- `Microsoft.Web/serverFarms`：App Service がそのサブネットを VNet 統合に使用
- `Microsoft.DBforPostgreSQL/flexibleServers`：PostgreSQL Flexible Server がそのサブネット内にデプロイされる

#### Service Endpoints とは

VNet Service Endpoints は、VNet のプライベートアドレス空間と VNet の ID を Azure サービスに直接接続で拡張する機能です。これにより、Azure サービスへのトラフィックが Azure のバックボーンネットワーク上にとどまり、パブリックインターネットを経由しません。

### 4.3 Network Security Group（NSG）

Microsoft 公式ドキュメント（https://learn.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview）による定義：

> You can use an Azure network security group to filter network traffic between Azure resources in Azure virtual networks. A network security group contains security rules that allow or deny inbound network traffic to, or outbound network traffic from, several types of Azure resources.

NSG はネットワークセキュリティルール（許可/拒否）の集合で、Azure リソース間のネットワークトラフィックをフィルタリングします。

#### セキュリティルールの属性（公式ドキュメントより）

| プロパティ | 説明 |
|---|---|
| **Name** | NSG 内で一意の名前 |
| **Priority** | 100〜4096 の数値。小さい数値ほど優先度が高い。一致したルールが見つかると処理は停止 |
| **Source / Destination** | Any、個別 IP、CIDR ブロック、サービスタグ、アプリケーションセキュリティグループ |
| **Protocol** | TCP、UDP、ICMP、ESP、AH、または Any |
| **Direction** | Inbound（受信）または Outbound（送信） |
| **Port range** | 個別ポートまたはポート範囲 |
| **Action** | Allow（許可）または Deny（拒否） |

#### 本リポジトリの NSG ルール（app サブネット用）

```hcl
resource "azurerm_network_security_group" "app" {
  name = "${local.name_prefix}-app-nsg"
  ...
}
```

| ルール名 | 優先度 | 方向 | プロトコル | ポート | ソース | アクション | 目的 |
|---|---|---|---|---|---|---|---|
| `Allow-HTTPS-Inbound` | 100 | Inbound | TCP | 443 | VirtualNetwork | Allow | VNet 内からの HTTPS 通信を許可 |
| `Allow-8080-Inbound` | 110 | Inbound | TCP | 8080 | VirtualNetwork | Allow | VNet 内からのアプリポート通信を許可 |
| `Allow-All-Outbound` | 100 | Outbound | * | * | * | Allow | すべてのアウトバウンド通信を許可 |

この NSG は `azurerm_subnet_network_security_group_association` で `app` サブネットに関連付けられています。

### 4.4 Private DNS Zone（PostgreSQL 用）

```hcl
resource "azurerm_private_dns_zone" "postgres" {
  name = "privatelink.postgres.database.azure.com"
  ...
}
```

Private DNS Zone は、VNet 内のリソースが PostgreSQL サーバーのプライベート FQDN を解決できるようにするものです。`azurerm_private_dns_zone_virtual_network_link` で VNet にリンクされ、`registration_enabled = false`（自動登録なし）で設定されています。

---

## 5. Azure App Service（Web アプリ実行環境）

### 5.1 Azure App Service とは

Microsoft 公式ドキュメント（https://learn.microsoft.com/en-us/azure/app-service/overview）による定義：

> Azure App Service is a platform that lets you run web applications, mobile back ends, and RESTful APIs without worrying about managing the underlying infrastructure.

App Service は、Web アプリケーション・モバイルバックエンド・RESTful API を、基盤インフラの管理を気にせず実行できるプラットフォームです。.NET、Java、Node.js、Python、PHP の各スタックをサポートし、Windows/Linux 両方で動作します。コンテナ化されたアプリもデプロイ可能です。

### 5.2 App Service Plan とは

Microsoft 公式ドキュメント（https://learn.microsoft.com/en-us/azure/app-service/overview-hosting-plans）による定義：

> An Azure App Service plan defines a set of compute resources for a web app to run.

App Service Plan は Web アプリが動作するコンピューティングリソースのセットを定義します。以下の要素を決定します：

- **OS**（Windows / Linux）
- **リージョン**
- **VM インスタンス数**
- **VM インスタンスサイズ**
- **価格レベル**

#### 価格レベル（公式ドキュメントの分類）

| カテゴリ | ティア | 説明 |
|---|---|---|
| **共有コンピューティング** | Free, Shared | 他の顧客のアプリと同じ Azure VM を共有。CPU クォータ割り当て。スケールアウト不可。開発・テスト用途 |
| **専用コンピューティング** | Basic, Standard, Premium, PremiumV2, PremiumV3, PremiumV4 | 専用の Azure VM 上でアプリを実行。同じプランのアプリのみがリソースを共有。ティアが高いほどスケールアウト用の VM インスタンス数が増加 |
| **分離** | IsolatedV2 | 専用の Azure VNet 上の専用 VM で実行。コンピューティング分離の上にネットワーク分離を提供。最大のスケールアウト能力 |

#### プラン内アプリ密度の上限（公式ドキュメントより）

| App Service Plan | 推奨最大アプリ数 |
|---|---|
| B1, S1, P1v2, I1v1 | 8 |
| B2, S2, P2v2, I2v1 | 16 |
| B3, S3, P3v2, I3v1 | 32 |
| P1v3, P1v4, I1v2 | 16 |
| P2v3, P2v4, I2v2 | 32 |
| P3v3, P3v4, I3v2 | 64 |

#### 課金モデル（公式ドキュメントより）

- **Free ティア**：無料
- **Shared ティア**：CPU クォータに対して課金
- **専用コンピューティングティア（Basic 以上）**：VM インスタンス数に対して課金。実行中のアプリの数に関わらず同一料金
- **IsolatedV2 ティア**：分離ワーカー数に対して課金

### 5.3 本リポジトリの定義（`app_service.tf`）

#### App Service Plan

```hcl
resource "azurerm_service_plan" "main" {
  name                = "${local.name_prefix}-plan"
  os_type             = "Linux"
  sku_name            = var.app_sku_name  # デフォルト: "B1"
  ...
}
```

| 属性 | 値 | 説明 |
|---|---|---|
| `os_type` | `Linux` | Linux コンテナベースのアプリ実行 |
| `sku_name` | `B1`（デフォルト） | Basic ティアの最小構成。専用 VM 1 台 |

#### Linux Web App

```hcl
resource "azurerm_linux_web_app" "main" {
  name                      = "${local.name_prefix}-app"
  service_plan_id           = azurerm_service_plan.main.id
  virtual_network_subnet_id = azurerm_subnet.app.id
  https_only                = true
  ...
}
```

| 設定 | 値 | 説明 |
|---|---|---|
| `virtual_network_subnet_id` | app サブネット | VNet 統合によりアプリから VNet 内リソースへのアクセスが可能 |
| `https_only` | `true` | HTTP リクエストを HTTPS にリダイレクト。通信の暗号化を強制 |
| `always_on` | `true` | アプリを常時稼働状態に維持。アイドルタイムアウトによるコールドスタートを防止 |
| `container_registry_use_managed_identity` | `true` | マネージド ID を使用して ACR に認証。管理者資格情報を使わない |
| `health_check_path` | `/health` | App Service が定期的にこのパスにリクエストを送信し、アプリの正常性を監視。応答がない場合は自動再起動 |
| `docker_image_name` | 変数で設定 | 実行するコンテナイメージ。初回は Microsoft の静的サイトイメージを使用 |

#### 環境変数（app_settings）

| 環境変数 | 値 | 説明 |
|---|---|---|
| `WEBSITES_PORT` | `8080` | App Service がコンテナに転送するポート番号 |
| `PORT` | `8080` | アプリが読み取るポート番号 |
| `DATABASE_URL` | PostgreSQL 接続文字列 | `postgresql://user:pass@host:5432/db?sslmode=require` 形式 |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | Application Insights 接続文字列 | テレメトリ送信先 |
| `KEY_VAULT_URI` | Key Vault の URI | アプリから Key Vault にアクセスするための URI |

#### System Assigned Managed Identity

```hcl
identity {
  type = "SystemAssigned"
}
```

App Service に Azure が自動管理するマネージド ID が付与されます。この ID を使って、パスワードなしで Key Vault や ACR などの Azure サービスに認証できます。

#### ログ設定

```hcl
logs {
  http_logs {
    file_system {
      retention_in_days = 7
      retention_in_mb   = 35
    }
  }
}
```

HTTP ログをファイルシステムに保存し、7 日間または 35 MB まで保持します。

---

## 6. Azure Database for PostgreSQL Flexible Server

### 6.1 概要

Microsoft 公式ドキュメント（https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/overview）による定義：

> Azure Database for PostgreSQL is a fully managed database service that gives you granular control and flexibility over database management functions and configuration settings.

フルマネージドのデータベースサービスであり、データベース管理機能と構成設定に対するきめ細かな制御と柔軟性を提供します。

### 6.2 公式ドキュメントに記載されている主な特徴

#### アーキテクチャと高可用性

- コンピューティングとストレージが分離されたアーキテクチャ
- データベースエンジンは Linux VM 内のコンテナで実行
- データファイルは Azure ストレージに格納され、**ローカル冗長で 3 つの同期コピー**を維持
- ゾーン冗長高可用性構成では、同一リージョン内の別の可用性ゾーンにウォームスタンバイサーバーをプロビジョニング
- データ変更はスタンバイに同期レプリケーションされ、**ゼロデータロス**を実現

#### 自動バックアップ

- サーバーバックアップを自動作成し、ゾーン冗長ストレージ（ZRS）に保存
- デフォルトのバックアップ保持期間は **7 日間**（最大 35 日まで設定可能）
- バックアップは **AES 256 ビット暗号化**で暗号化
- 保持期間内の任意の時点にリストア可能（ポイントインタイムリストア）

#### コンピューティングティア

| ティア | 用途 |
|---|---|
| **Burstable** | 低コストの開発・低同時実行ワークロード。常時フルコンピューティング容量が不要な場合 |
| **General Purpose** | 高同時実行性・スケール・予測可能なパフォーマンスが必要な本番ワークロード |
| **Memory Optimized** | 高同時実行性・スケール・予測可能なパフォーマンスが必要な本番ワークロード（メモリ重視） |

#### セキュリティ（公式ドキュメントより）

- **保存時の暗号化**：FIPS 140-2 検証済み暗号化モジュールで AES 256 ビット暗号化
- **転送中の暗号化**：TLS/SSL がデフォルトで強制。TLS 1.2 以降をサポート
- **VNet 統合**：VNet 内に配置することで、プライベート IP アドレスのみでアクセス可能。パブリックアクセスは拒否

#### 組み込み PgBouncer

- コネクションプーラーである **PgBouncer** が組み込みで提供されている
- 有効化すると同一ホスト名のポート 6432 で PgBouncer 経由の接続が可能

#### サーバーの停止/起動

- オンデマンドでサーバーを停止・起動可能
- 停止中はコンピューティング課金が停止し、コスト削減が可能
- 停止状態は最大 **7 日間**維持され、その後自動的に再起動

### 6.3 本リポジトリの定義（`database.tf`）

#### パスワード生成

```hcl
resource "random_password" "db_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}
```

`hashicorp/random` プロバイダを使用して 24 文字のランダムパスワードを生成。特殊文字は `!@#$%` に限定（URL エンコードの問題を回避するため）。

#### PostgreSQL Flexible Server

```hcl
resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "${local.name_prefix}-pgserver"
  administrator_login    = var.postgres_admin_username  # デフォルト: "pgadmin"
  administrator_password = random_password.db_password.result
  sku_name               = var.postgres_sku_name         # デフォルト: "B_Standard_B1ms"
  storage_mb             = var.postgres_storage_mb        # デフォルト: 32768 (32GB)
  version                = var.postgres_version           # デフォルト: "16"
  delegated_subnet_id    = azurerm_subnet.db.id
  private_dns_zone_id    = azurerm_private_dns_zone.postgres.id
  zone                   = "1"
  ...
}
```

| 属性 | 値 | 説明 |
|---|---|---|
| `sku_name` | `B_Standard_B1ms` | Burstable ティア、Standard B1ms。開発用の最小構成 |
| `storage_mb` | `32768` | 32 GB のストレージ |
| `version` | `16` | PostgreSQL メジャーバージョン 16 |
| `delegated_subnet_id` | db サブネット | VNet 内の専用サブネットに配置。インターネットからの直接アクセス不可 |
| `private_dns_zone_id` | PostgreSQL 用 Private DNS Zone | VNet 内から FQDN で名前解決可能にする |
| `zone` | `1` | 可用性ゾーン 1 に配置 |

#### データベース

```hcl
resource "azurerm_postgresql_flexible_server_database" "main" {
  name      = "${var.project}db"  # デフォルト: "webappdb"
  charset   = "UTF8"
  collation = "en_US.utf8"
  ...
}
```

#### SSL 強制設定

```hcl
resource "azurerm_postgresql_flexible_server_configuration" "require_ssl" {
  name  = "require_secure_transport"
  value = "on"
  ...
}
```

SSL/TLS 接続を強制し、平文での通信を拒否します。

---

## 7. Azure Container Registry（ACR）

### 7.1 概要

Azure Container Registry は、Azure 上のプライベートコンテナレジストリサービスです。Docker コンテナイメージやその他の OCI アーティファクトを保管・管理します。

### 7.2 SKU と機能（公式ドキュメントより）

Microsoft 公式ドキュメント（https://learn.microsoft.com/en-us/azure/container-registry/container-registry-skus）に記載された SKU 比較：

| リソース | Basic | Standard | Premium |
|---|---|---|---|
| **含まれるストレージ（GiB）** | 10 | 100 | 500 |
| **ストレージ上限（TiB）** | 40 | 40 | 100 |
| **最大イメージレイヤーサイズ（GiB）** | 200 | 200 | 200 |
| **Webhook 数** | 2 | 10 | 500 |
| **Private Link / Private Endpoint** | ✗ | ✗ | ✓（最大200） |
| **Geo レプリケーション** | ✗ | ✗ | ✓ |
| **可用性ゾーン** | ✓ | ✓ | ✓ |
| **コンテンツの信頼性（Content Trust）** | ✗ | ✗ | ✓ |
| **カスタマーマネージドキー** | ✗ | ✗ | ✓ |
| **匿名プルアクセス** | ✗ | ✓ | ✓ |
| **保持ポリシー（未タグマニフェスト）** | ✗ | ✗ | ✓ |

各 SKU の公式説明：

- **Basic**：開発者が Azure Container Registry を学ぶためのコスト最適化エントリポイント。ストレージとイメージスループットは低使用量シナリオ向け
- **Standard**：Basic と同じ機能に加え、ストレージとイメージスループットが増加。多くの本番シナリオに対応
- **Premium**：最大量のストレージと同時操作をサポート。Geo レプリケーション、Private Link、高 API 同時実行性、帯域幅スループット等の追加機能

### 7.3 本リポジトリの定義（`acr.tf`）

```hcl
resource "azurerm_container_registry" "main" {
  name                = replace("${local.name_prefix}acr", "-", "")
  sku                 = "Basic"
  admin_enabled       = true
  ...
}
```

| 属性 | 値 | 説明 |
|---|---|---|
| `name` | `webappdevacr`（デフォルト） | ACR 名にはハイフン不可のため `replace()` で除去 |
| `sku` | `Basic` | 最小コストの SKU。開発・テスト向け。含まれるストレージ 10 GiB |
| `admin_enabled` | `true` | 管理者アカウントを有効化。`docker login` でのプッシュに使用 |

> **注意**：`admin_enabled = true` は簡便ですが、本番環境ではマネージド ID またはサービスプリンシパルによる認証が推奨されます。

---

## 8. Azure Key Vault

### 8.1 概要

Microsoft 公式ドキュメント（https://learn.microsoft.com/en-us/azure/key-vault/general/overview）による定義：

> Azure Key Vault is one of several key management solutions in Azure, and helps solve the following problems:
> - **Secrets Management** - Securely store and tightly control access to tokens, passwords, certificates, API keys, and other secrets
> - **Key Management** - Create and control the encryption keys used to encrypt your data
> - **Certificate Management** - Provision, manage, and deploy public and private TLS/SSL certificates

Key Vault は Azure の鍵管理ソリューションの 1 つであり、シークレット管理・鍵管理・証明書管理の 3 つの問題を解決します。

### 8.2 サービスティア（公式ドキュメントより）

| ティア | 説明 |
|---|---|
| **Standard** | FIPS 140 Level 1 検証済みのソフトウェアライブラリでデータを暗号化 |
| **Premium** | FIPS 140-3 Level 3 検証済み Marvell LiquidSecurity HSM で保護されたキーを提供。最高レベルの暗号化保護 |

### 8.3 公式ドキュメントに記載されている主な利点

- **シークレットの一元管理**：アプリケーションのシークレットを一元化し、漏洩リスクを軽減。アプリケーションコードにセキュリティ情報を埋め込む必要がなくなる
- **安全な保存**：Microsoft Entra ID による認証、Azure RBAC または Key Vault アクセスポリシーによる認可。すべての Key Vault は HSM に格納されたキーで暗号化
- **アクセスの監視**：ログを有効化して、いつ・誰がキーやシークレットにアクセスしたかを監視可能
- **管理の簡素化**：Azure がレプリケーションと高可用性を自動管理。HSM の専門知識が不要

> 公式ドキュメントより：「Azure Key Vault is designed so that Microsoft doesn't see or extract your data.」（Microsoft がデータを閲覧・抽出できない設計）

### 8.4 本リポジトリの定義（`keyvault.tf`）

```hcl
resource "azurerm_key_vault" "main" {
  name                      = "${local.name_prefix}-kv"
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  sku_name                  = "standard"
  enable_rbac_authorization = true
  purge_protection_enabled  = true
  ...
}
```

| 属性 | 値 | 説明 |
|---|---|---|
| `sku_name` | `standard` | Standard ティア |
| `enable_rbac_authorization` | `true` | Azure RBAC で認可を管理。Key Vault アクセスポリシーではなく RBAC を使用 |
| `purge_protection_enabled` | `true` | 論理削除されたリソースの完全削除（purge）を防止。復旧期間中の誤削除を防ぐ |

#### ネットワーク ACL

```hcl
network_acls {
  default_action             = "Deny"
  bypass                     = "AzureServices"
  virtual_network_subnet_ids = [azurerm_subnet.app.id]
}
```

- `default_action = "Deny"`：デフォルトで全アクセスを拒否
- `bypass = "AzureServices"`：Azure サービスからのアクセスはバイパス（許可）
- `virtual_network_subnet_ids`：app サブネットからのアクセスのみ許可

#### RBAC ロール割り当て

```hcl
resource "azurerm_role_assignment" "app_keyvault_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.main.identity[0].principal_id
}
```

App Service のマネージド ID に「**Key Vault Secrets User**」ロールを付与。これにより App Service はシークレットの**読み取り**のみ可能（書き込み・削除は不可）。

#### シークレットの保存

```hcl
resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = random_password.db_password.result
  key_vault_id = azurerm_key_vault.main.id
}
```

生成された DB パスワードを Key Vault にシークレットとして保存。

---

## 9. Azure Application Insights / Log Analytics

### 9.1 Application Insights とは

Microsoft 公式ドキュメント（https://learn.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview）による定義：

> Azure Monitor Application Insights is an application performance monitoring (APM) feature of Azure Monitor. For supported scenarios, you can use OpenTelemetry (OTel), a vendor-neutral observability framework, to instrument your applications and collect telemetry data, then analyze that telemetry in Application Insights.

Application Insights は Azure Monitor のアプリケーションパフォーマンス監視（APM）機能です。OpenTelemetry を使用してテレメトリデータを収集・分析できます。

#### 公式ドキュメントに記載されている主な機能

**調査（Investigate）系**：
- **Application dashboard**：アプリの正常性とパフォーマンスの概要
- **Application map**：アプリアーキテクチャとコンポーネント間の相互作用を視覚化
- **Live metrics**：リアルタイム分析ダッシュボード
- **Search view**：トランザクションのトレースと診断
- **Availability view**：エンドポイントの可用性と応答性を事前に監視・テスト
- **Failures view**：アプリの障害を特定・分析
- **Performance view**：パフォーマンスメトリクスとボトルネック

**監視（Monitoring）系**：
- **Alerts**：さまざまなアスペクトの監視とアクション発火
- **Metrics**：メトリクスデータの詳細分析
- **Logs**：Azure Monitoring Logs に収集されたデータの取得・統合・分析
- **Workbooks**：インタラクティブなレポートとダッシュボード

**利用分析（Usage）系**：
- **Users, sessions, and events**：ユーザーの操作パターン分析
- **Funnels**：コンバージョン率の分析
- **Flows**：ユーザーパスの可視化

### 9.2 Log Analytics Workspace とは

Log Analytics Workspace は Azure Monitor のログデータを集約・保存・クエリするための場所です。Application Insights のバックエンドストアとして使用されます。

### 9.3 本リポジトリの定義（`monitoring.tf`）

#### Log Analytics Workspace

```hcl
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${local.name_prefix}-law"
  sku                 = "PerGB2018"
  retention_in_days   = 30
  ...
}
```

| 属性 | 値 | 説明 |
|---|---|---|
| `sku` | `PerGB2018` | GB 単位の従量課金モデル（現在利用可能な唯一の SKU） |
| `retention_in_days` | `30` | ログデータを 30 日間保持 |

#### Application Insights

```hcl
resource "azurerm_application_insights" "main" {
  name             = "${local.name_prefix}-ai"
  application_type = "web"
  workspace_id     = azurerm_log_analytics_workspace.main.id
  ...
}
```

| 属性 | 値 | 説明 |
|---|---|---|
| `application_type` | `web` | Web アプリケーション用の Application Insights |
| `workspace_id` | Log Analytics Workspace | ワークスペースベースの Application Insights（推奨構成） |

---

## 10. Go アプリケーション

### 10.1 概要

`app/main.go` は Go 標準ライブラリの `net/http` パッケージを使用した最小構成の HTTP サーバーです。

### 10.2 ソースコード解説

```go
package main

import (
	"encoding/json"
	"net/http"
	"os"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/", handleRoot)
	http.HandleFunc("/health", handleHealth)

	http.ListenAndServe(":"+port, nil)
}
```

| 要素 | 説明 |
|---|---|
| `os.Getenv("PORT")` | 環境変数 `PORT` からリッスンポートを取得。未設定時は `8080` をデフォルトで使用 |
| `http.HandleFunc` | Go 標準ライブラリ `net/http` パッケージの関数。URL パターンにハンドラ関数を登録 |
| `http.ListenAndServe` | 指定アドレスで HTTP サーバーを起動し、リクエストの待ち受けを開始。第 2 引数 `nil` はデフォルトの `DefaultServeMux` を使用 |

### 10.3 エンドポイント

#### `GET /`

```json
{"service": "azure-webapp", "status": "ok"}
```

アプリの基本レスポンス。サービスの稼働確認用。GET 以外のメソッドには `405 Method Not Allowed` を返す。

#### `GET /health`

```json
{"healthy": true}
```

ヘルスチェック用エンドポイント。App Service の `health_check_path` で監視対象として設定されている。App Service はこのエンドポイントに定期的にリクエストを送り、応答がない場合はインスタンスを不健全と判断して自動再起動を行う。

### 10.4 Go モジュール（`go.mod`）

```
module github.com/example/azure-webapp
go 1.22
```

- Go 1.22 を使用
- 外部依存パッケージなし（標準ライブラリのみ）

---

## 11. Docker / Dockerfile

### 11.1 マルチステージビルドとは

Docker 公式ドキュメント（https://docs.docker.com/build/building/multi-stage/）による説明：

> Multi-stage builds are useful to anyone who has struggled to optimize Dockerfiles while keeping them easy to read and maintain.

マルチステージビルドでは、Dockerfile 内で複数の `FROM` 文を使用します。各 `FROM` は異なるベースイメージを使用でき、それぞれが新しいビルドステージを開始します。あるステージから別のステージへ必要なアーティファクトのみをコピーし、最終イメージに不要なものを残さないことができます。

### 11.2 本リポジトリの Dockerfile 解説

```dockerfile
# Build stage
FROM golang:1.22-alpine AS builder
WORKDIR /src
COPY go.mod ./
COPY *.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags='-s -w' -o /out/app .

# Run stage
FROM alpine:3.19
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
COPY --from=builder /out/app /app
USER appuser
EXPOSE 8080
CMD ["/app"]
```

#### ビルドステージ（`builder`）

| 行 | 説明 |
|---|---|
| `FROM golang:1.22-alpine AS builder` | Go 1.22 の Alpine ベースイメージをビルド用ステージとして使用。`golang:1.22-alpine` は Docker Hub 公式イメージ（https://hub.docker.com/_/golang）。Alpine ベースのため軽量 |
| `WORKDIR /src` | 作業ディレクトリを `/src` に設定 |
| `COPY go.mod ./` | Go モジュール定義をコピー |
| `COPY *.go ./` | Go ソースファイルをコピー |
| `CGO_ENABLED=0` | CGO（C 言語バインディング）を無効化。静的リンクバイナリを生成し、C ライブラリへの依存をなくす |
| `GOOS=linux` | Linux 向けにクロスコンパイル |
| `-ldflags='-s -w'` | `-s`：シンボルテーブルを削除。`-w`：DWARF デバッグ情報を削除。バイナリサイズを削減 |

#### 実行ステージ

| 行 | 説明 |
|---|---|
| `FROM alpine:3.19` | Alpine Linux 3.19（https://hub.docker.com/_/alpine）をベースイメージに使用。約 5 MB の最小 Linux ディストリビューション |
| `addgroup -S` / `adduser -S` | システムグループ `appgroup` とシステムユーザー `appuser` を作成。`-S` はシステムアカウント（UID が低い範囲、ホームディレクトリなし） |
| `COPY --from=builder` | ビルドステージからコンパイル済みバイナリのみをコピー。Go ツールチェーンやソースコードは含まれない |
| `USER appuser` | root ではなく非特権ユーザーでアプリを実行。コンテナが侵害された場合のリスクを軽減するセキュリティベストプラクティス |
| `EXPOSE 8080` | コンテナがポート 8080 でリッスンすることをドキュメント化（実際のポート公開は行わない） |
| `CMD ["/app"]` | コンテナ起動時に実行されるコマンド。exec 形式（JSON 配列）を使用 |

#### マルチステージビルドのメリット

- ビルドツール（Go コンパイラ等）が最終イメージに含まれない → **イメージサイズの大幅削減**
- 攻撃対象面積の縮小（最小限のバイナリのみ） → **セキュリティ向上**
- ビルドとランタイムの関心の分離

---

## 12. Makefile（操作コマンド）

### 12.1 変数

| 変数 | デフォルト | 説明 |
|---|---|---|
| `PROJECT` | `webapp` | プロジェクト名 |
| `ENV` | `dev` | 環境名 |
| `ACR_NAME` | Terraform output から取得 | ACR のログインサーバー URL |
| `APP_NAME` | Terraform output から取得 | App Service 名 |
| `IMAGE` | `$(ACR_NAME)/$(PROJECT):latest` | Docker イメージのフルネーム |

### 12.2 コマンド一覧

| コマンド | カテゴリ | 説明 |
|---|---|---|
| `make help` | ユーティリティ | 全コマンドのヘルプを表示 |
| `make infra-init` | インフラ | `terraform init`。プロバイダプラグインのダウンロードと初期化 |
| `make infra-plan` | インフラ | `terraform plan`。変更内容のプレビュー |
| `make infra-apply` | インフラ | `terraform apply`。リソースの作成・変更 |
| `make infra-destroy` | インフラ | `terraform destroy`。全リソースの削除 |
| `make infra-output` | インフラ | `terraform output`。出力値の表示 |
| `make app-run` | アプリ | `go run main.go`。ローカルでアプリを起動 |
| `make app-test` | アプリ | `go test ./...`。テストを実行 |
| `make docker-build` | Docker | Docker イメージをビルド |
| `make docker-push` | Docker | ACR にログインし、イメージをプッシュ。`docker-build` に依存 |
| `make deploy` | デプロイ | `az webapp config container set` で App Service のコンテナイメージを更新 |

---

## 13. Terraform 変数リファレンス

`infra/variables.tf` で定義されている全変数：

| 変数名 | 型 | デフォルト値 | 説明 |
|---|---|---|---|
| `project` | `string` | `"webapp"` | リソース命名に使用するプロジェクト名 |
| `environment` | `string` | `"dev"` | デプロイ環境（dev / staging / prod 等） |
| `location` | `string` | `"japaneast"` | 全リソースの Azure リージョン |
| `app_sku_name` | `string` | `"B1"` | App Service Plan の SKU |
| `postgres_sku_name` | `string` | `"B_Standard_B1ms"` | PostgreSQL Flexible Server の SKU |
| `postgres_storage_mb` | `number` | `32768` | PostgreSQL のストレージサイズ（MB 単位）。32 GB |
| `postgres_version` | `string` | `"16"` | PostgreSQL のメジャーバージョン |
| `postgres_admin_username` | `string` | `"pgadmin"` | PostgreSQL の管理者ユーザー名 |
| `app_docker_image` | `string` | `"mcr.microsoft.com/appsvc/staticsite:latest"` | 初回デプロイ用の Docker イメージ。ACR push 後に差し替え |
| `tags` | `map(string)` | `{}` | 全リソースに追加で付与するタグ |

### 変数の上書き方法

`infra/terraform.tfvars` ファイルを作成して値を記述：

```hcl
project     = "myapp"
environment = "prod"
location    = "japaneast"
app_sku_name = "P1v3"
postgres_sku_name = "GP_Standard_D2s_v3"
tags = {
  Team = "backend"
}
```

---

## 14. Terraform 出力値リファレンス

`infra/outputs.tf` で定義されている全出力値：

| 出力名 | 説明 | Sensitive |
|---|---|---|
| `resource_group_name` | リソースグループ名 | No |
| `app_service_url` | App Service の URL（`https://...`） | No |
| `app_service_name` | App Service 名 | No |
| `acr_login_server` | ACR のログインサーバー URL | No |
| `acr_name` | ACR 名 | No |
| `key_vault_uri` | Key Vault の URI | No |
| `postgresql_fqdn` | PostgreSQL サーバーの FQDN | No |
| `application_insights_instrumentation_key` | Application Insights のインストルメンテーションキー | **Yes** |
| `application_insights_connection_string` | Application Insights の接続文字列 | **Yes** |

`sensitive = true` の出力値は `terraform output` で直接表示されません。表示するには `terraform output -raw <名前>` を使用します。

---

## 15. セキュリティ設計の解説

本リポジトリでは以下のセキュリティ対策が実装されています：

### ネットワーク分離

| 対策 | 実装 |
|---|---|
| VNet 統合 | App Service が VNet 内から DB・Key Vault にアクセス |
| DB のプライベート配置 | PostgreSQL は delegated サブネット内にデプロイ。パブリック IP なし |
| Private DNS Zone | VNet 内から FQDN で DB に名前解決 |
| NSG | app サブネットで HTTPS/8080 のみ受信許可 |
| Key Vault ネットワーク ACL | デフォルト拒否、app サブネットからのみアクセス許可 |

### 認証・認可

| 対策 | 実装 |
|---|---|
| マネージド ID | App Service に System Assigned Managed Identity を付与 |
| RBAC | Key Vault で RBAC を有効化。App Service に「Key Vault Secrets User」ロールのみ付与（最小権限の原則） |
| ACR 認証 | マネージド ID による認証（`container_registry_use_managed_identity = true`） |

### 暗号化

| 対策 | 実装 |
|---|---|
| 通信の暗号化 | App Service で `https_only = true`。PostgreSQL で SSL 強制 |
| 保存時の暗号化 | Key Vault：HSM ベースの暗号化。PostgreSQL：AES 256 ビット暗号化（Azure 管理） |

### シークレット管理

| 対策 | 実装 |
|---|---|
| パスワード生成 | `random_password` で 24 文字のランダムパスワードを自動生成 |
| シークレット保管 | DB パスワードを Key Vault に保存 |
| purge 保護 | Key Vault で `purge_protection_enabled = true` |

### コンテナセキュリティ

| 対策 | 実装 |
|---|---|
| 非 root 実行 | Dockerfile で `USER appuser`（非特権ユーザー） |
| 最小イメージ | Alpine ベースの最小イメージを使用 |
| 静的バイナリ | `CGO_ENABLED=0` で静的リンク。不要なライブラリを含まない |

---

## 16. 参考リンク集

### Azure 公式ドキュメント

| トピック | URL |
|---|---|
| App Service 概要 | https://learn.microsoft.com/en-us/azure/app-service/overview |
| App Service Plan | https://learn.microsoft.com/en-us/azure/app-service/overview-hosting-plans |
| PostgreSQL Flexible Server | https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/overview |
| Container Registry SKU | https://learn.microsoft.com/en-us/azure/container-registry/container-registry-skus |
| Key Vault 概要 | https://learn.microsoft.com/en-us/azure/key-vault/general/overview |
| Application Insights | https://learn.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview |
| Virtual Network | https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview |
| NSG 概要 | https://learn.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview |

### Terraform 公式ドキュメント

| トピック | URL |
|---|---|
| Terraform とは | https://developer.hashicorp.com/terraform/intro |
| AzureRM プロバイダ | https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs |

### Docker 公式ドキュメント

| トピック | URL |
|---|---|
| マルチステージビルド | https://docs.docker.com/build/building/multi-stage/ |
| Go 公式イメージ | https://hub.docker.com/_/golang |
| Alpine 公式イメージ | https://hub.docker.com/_/alpine |
