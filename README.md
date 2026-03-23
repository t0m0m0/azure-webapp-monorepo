# Azure WebApp Monorepo — AZ-104 学習用エンタープライズインフラ構成

> **AZ-104: Microsoft Azure Administrator** 試験の学習教材としても活用できる、Terraform ベースの Azure インフラ構成です。

## 📚 AZ-104 試験ドメインとリポジトリの対応

| AZ-104 ドメイン | 配点 | 対応ファイル | 学習トピック |
|---|---|---|---|
| **1. ID・ガバナンス管理** | 20-25% | `governance.tf`, `keyvault.tf` | RBAC, Policy, Locks, タグ, マネージドID |
| **2. ストレージ** | 15-20% | `storage.tf` | Storage Account, Blob層, Files, ライフサイクル, SAS |
| **3. コンピューティング** | 20-25% | `virtual_machines.tf`, `app_service.tf`, `acr.tf` | VM, App Service, ACR, 可用性 |
| **4. 仮想ネットワーク** | 15-20% | `network.tf`, `load_balancer.tf`, `frontdoor.tf` | VNet, NSG, LB, DNS, Private Endpoint |
| **5. 監視・バックアップ** | 10-15% | `monitoring.tf`, `disaster_recovery.tf`, `budget.tf` | Monitor, Alerts, Backup, DR |

## アーキテクチャ

```
┌─────────────┐       ┌─────────────────────────────────────────────────────┐
│   Users     │────▶│  Azure Front Door + WAF (OWASP, rate limiting)     │
└─────────────┘       └─────────────────────────┬───────────────────────────┘
                                                  │
                    ┌──────────────────── VNet (10.0.0.0/16) ────────────────────┐
                    │                                                         │
                    │  ┌──── app subnet ────┐    ┌──── db subnet ─────┐    │
                    │  │ App Service        │    │ PostgreSQL        │    │
                    │  │ (+ staging slot)   ├───▶│ (HA + backups)    │    │
                    │  │ (auto-scale)       │    │                   │    │
                    │  └────┬──────┬─────┘    └───────────────────┘    │
                    │       │      │                                       │
                    │  ┌────┴──────┴──── private-endpoints subnet ───┐    │
                    │  │ Key Vault PE │ ACR PE │ Storage PE │ Redis PE │    │
                    │  └──────────────┴────────┴────────────┴──────────┘    │
                    └─────────────────────────────────────────────────────────┘

  Supporting: ACR │ Key Vault │ Storage │ Log Analytics │ App Insights │ Redis
  Governance: Policy │ RBAC │ Locks │ Budget │ Tags
  Compute:    VM │ Load Balancer (AZ-104 学習用)
```

## プロジェクト構成

```
├── app/                          # Go Web アプリケーション
│   ├── main.go                   # HTTP サーバー
│   ├── go.mod                    # Go モジュール
│   └── Dockerfile                # マルチステージビルド
├── infra/                        # Terraform 構成ファイル
│   ├── versions.tf               # プロバイダバージョン & バックエンド
│   ├── variables.tf              # 全入力変数 & locals
│   ├── resource_group.tf         # リソースグループ
│   ├── network.tf                # VNet, Subnet, NSG, Private DNS
│   ├── app_service.tf            # App Service + Slot + Auto-scale
│   ├── database.tf               # PostgreSQL Flexible Server
│   ├── acr.tf                    # Container Registry
│   ├── keyvault.tf               # Key Vault + RBAC + Managed ID
│   ├── monitoring.tf             # Log Analytics + App Insights + Alerts
│   ├── storage.tf          ⭐    # Storage Account + Blob + Files + Lifecycle
│   ├── virtual_machines.tf ⭐    # VM + NIC + Disk + Extensions
│   ├── load_balancer.tf    ⭐    # Load Balancer + Probe + NAT
│   ├── governance.tf       ⭐    # Azure Policy + Locks + RBAC
│   ├── frontdoor.tf              # Front Door + WAF
│   ├── redis.tf                  # Azure Cache for Redis
│   ├── budget.tf                 # コスト管理アラート
│   ├── disaster_recovery.tf      # Recovery Vault + DR
│   ├── github_actions.tf         # OIDC CI/CD ID
│   ├── outputs.tf                # 出力値
│   └── terraform.tfvars.example  # 変数サンプル
├── docs/
│   ├── AZ-104_STUDY_GUIDE.md     # ⭐ AZ-104 完全学習ガイド（模擬問題付き）
│   ├── INFRASTRUCTURE_GUIDE.md   # インフラ初心者向けガイド
│   └── DETAILED_GUIDE.md         # 詳細技術リファレンス
├── .github/workflows/
│   └── deploy.yml                # CI/CD: build, test, deploy, swap
├── Makefile                      # 操作コマンド
└── README.md                     # このファイル
```

> ⭐ = AZ-104 学習用に追加したファイル。各ファイルに試験対策のコメントが豊富に含まれています。

## 🎓 AZ-104 学習の進め方

### Step 1: ドキュメントを読む

1. **[⭐ AZ-104 完全学習ガイド](docs/AZ-104_STUDY_GUIDE.md)** — 全ドメインの概念解説 + 模擬問題
2. **[インフラガイド](docs/INFRASTRUCTURE_GUIDE.md)** — 「そもそも Azure とは？」から始める初心者向け
3. **[詳細リファレンス](docs/DETAILED_GUIDE.md)** — 各リソースの公式ドキュメントベースの解説

### Step 2: Terraform ファイルを読む

各 `.tf` ファイルには AZ-104 試験に関連する詳細なコメントが含まれています：

| ファイル | 学べること |
|---|---|
| `storage.tf` | ストレージ冗長性 (LRS/ZRS/GRS), Blob 層 (Hot/Cool/Archive), SAS, Private Endpoint |
| `virtual_machines.tf` | VM サイズシリーズ, 可用性セット vs ゾーン, ディスク種別, 拡張機能 |
| `load_balancer.tf` | Basic vs Standard SKU, ヘルスプローブ, NAT ルール, セッション持続性 |
| `governance.tf` | Azure Policy の効果(Deny/Audit), リソースロック, カスタムロール |
| `network.tf` | VNet/Subnet 設計, NSG ルール, Service Endpoint, Delegation |
| `keyvault.tf` | RBAC ロール割り当て, マネージドID, ネットワークACL |
| `monitoring.tf` | Log Analytics, App Insights, アラートルール |

### Step 3: 実際にデプロイしてみる

```bash
# 1. 変数ファイルを作成
cp infra/terraform.tfvars.example infra/terraform.tfvars

# 2. AZ-104 学習用リソースを有効化（任意）
# terraform.tfvars に以下を追加:
#   enable_storage    = true   # Storage Account
#   enable_vm         = true   # 仮想マシン
#   enable_governance = true   # Policy & Locks

# 3. デプロイ
make infra-init    # Terraform 初期化
make infra-plan    # 実行計画の確認
make infra-apply   # リソース作成
```

> ⚠️ AZ-104 学習用リソースはデフォルトで無効 (`false`) です。コストを避けたい場合はコードとコメントを読むだけでも十分学習できます。

## Azure リソース一覧

| リソース | AZ-104 ドメイン | ファイル | Dev SKU | Prod SKU |
|---|---|---|---|---|
| Resource Group | ガバナンス | `resource_group.tf` | - | - |
| Azure Policy | ガバナンス | `governance.tf` | disabled | enabled |
| Resource Locks | ガバナンス | `governance.tf` | disabled | enabled |
| VNet + 3 Subnets | ネットワーク | `network.tf` | - | - |
| NSG | ネットワーク | `network.tf` | - | - |
| App Service (Linux) | コンピューティング | `app_service.tf` | B1 | P1v3 |
| Virtual Machine | コンピューティング | `virtual_machines.tf` | disabled | enabled |
| Load Balancer | ネットワーク | `load_balancer.tf` | disabled | enabled |
| Storage Account | ストレージ | `storage.tf` | disabled | enabled |
| PostgreSQL | コンピューティング | `database.tf` | B_Standard_B1ms | GP_Standard_D2ds_v4 |
| ACR | コンピューティング | `acr.tf` | Basic | Premium |
| Key Vault | ガバナンス | `keyvault.tf` | Standard | Standard |
| Front Door + WAF | ネットワーク | `frontdoor.tf` | disabled | enabled |
| Redis Cache | コンピューティング | `redis.tf` | disabled | enabled |
| Log Analytics | 監視 | `monitoring.tf` | PerGB2018 | PerGB2018 |
| App Insights | 監視 | `monitoring.tf` | - | - |
| Recovery Vault | 監視 | `disaster_recovery.tf` | disabled | enabled |
| Budget Alerts | ガバナンス | `budget.tf` | disabled | enabled |

## CI/CD パイプライン

GitHub Actions（`.github/workflows/deploy.yml`）による Blue/Green デプロイ:

1. **Test** — Go テスト + race detection
2. **Build** — Docker build + ACR push
3. **Deploy to Staging** — ステージングスロットにデプロイ
4. **Smoke Test** — ヘルスチェック
5. **Swap** — ゼロダウンタイムスワップ
6. **Auto-rollback** — 失敗時自動ロールバック

認証は OIDC（シークレット保存不要）。`infra/github_actions.tf` 参照。

## Make ターゲット

```
  infra-init            Terraform 初期化
  infra-plan            Terraform 実行計画
  infra-apply           Terraform 適用
  infra-destroy         Terraform リソース削除
  infra-output          Terraform 出力値の表示
  infra-fmt             Terraform フォーマット
  infra-validate        Terraform 構文検証
  docker-build          Docker イメージビルド
  docker-push           ACR へプッシュ
  deploy                App Service へ直接デプロイ
  deploy-staging        ステージングスロットへデプロイ
  swap                  ステージング -> プロダクションにスワップ
  rollback              プロダクションをロールバック
  status                全リソースのステータス確認
```

## 推定月額コスト

| 環境 | 推定コスト |
|---|---|
| Dev（最小構成） | ~$80/月 |
| Dev + AZ-104学習リソース | ~$120/月 |
| Staging | ~$150/月 |
| Production（フル） | ~$800-1200/月 |

## クリーンアップ

```bash
make infra-destroy    # 全リソースを削除
```

> ⚠️ Key Vault は purge protection 有効。論理削除後 90 日で完全削除されます。
