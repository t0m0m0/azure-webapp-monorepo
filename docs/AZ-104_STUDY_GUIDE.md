# AZ-104: Microsoft Azure Administrator 完全学習ガイド

## はじめに

本ガイドは、Microsoft AZ-104（Azure Administrator）試験の合格を目指す方のための包括的な学習資料です。実際のTerraformコード例を参照しながら、Azureの管理タスクを実践的に学習できます。

## AZ-104試験概要

### 試験の詳細
- **試験コード**: AZ-104
- **試験時間**: 120分
- **問題数**: 40-60問
- **合格ライン**: 700点/1000点
- **問題形式**: 選択問題、複数選択、ドラッグ&ドロップ、ケーススタディ
- **受験料**: $165 USD
- **言語**: 日本語対応

### 試験ドメインの配分

```
┌─────────────────────────────────────────────────────────┐
│ AZ-104 試験ドメイン                                      │
├─────────────────────────────────────────────────────────┤
│ Domain 1: ID・ガバナンス管理        │████████│ 20-25%  │
│ Domain 2: ストレージ                │██████│   15-20%  │
│ Domain 3: コンピューティング        │████████│ 20-25%  │
│ Domain 4: 仮想ネットワーク          │██████│   15-20%  │
│ Domain 5: 監視・バックアップ        │████│     10-15%  │
└─────────────────────────────────────────────────────────┘
```

---

# Domain 1: IDとガバナンスの管理 (20-25%)

## 1.1 Microsoft Entra ID（旧Azure Active Directory）

### 概念説明

Microsoft Entra IDは、Azureのクラウドベースのアイデンティティおよびアクセス管理サービスです。

#### Entra IDの主要機能
- **ユーザー・グループ管理**: ユーザーアカウントとグループの作成・管理
- **シングルサインオン（SSO）**: 複数のアプリケーションへの統合認証
- **多要素認証（MFA）**: セキュリティ強化のための追加認証層
- **条件付きアクセス**: コンテキストベースのアクセス制御
- **セルフサービスパスワードリセット（SSPR）**: ユーザーによるパスワード管理

#### Entra IDのエディション

```
┌──────────────────────────────────────────────────────┐
│ Free        │ 基本機能、500,000オブジェクト制限      │
├──────────────────────────────────────────────────────┤
│ Premium P1  │ 条件付きアクセス、動的グループ        │
├──────────────────────────────────────────────────────┤
│ Premium P2  │ Identity Protection、PIM              │
└──────────────────────────────────────────────────────┘
```

### ユーザーとグループの種類

#### ユーザータイプ
1. **クラウドID**: Entra IDで直接作成
2. **同期ID**: オンプレミスADから同期（Azure AD Connect使用）
3. **ゲストユーザー**: B2Bコラボレーション用の外部ユーザー

#### グループタイプ
1. **セキュリティグループ**: リソースアクセス管理用
2. **Microsoft 365グループ**: コラボレーション用

#### メンバーシップタイプ
- **割り当て済み**: 手動でメンバーを追加
- **動的ユーザー**: 属性ベースの自動メンバーシップ（Premium P1必須）
- **動的デバイス**: デバイス属性ベース（Premium P1必須）

## 1.2 ロールベースアクセス制御（RBAC）

### 概念説明

RBACは、Azureリソースへのアクセスをきめ細かく制御するための認可システムです。

### RBACの4要素

```
┌──────────────┐
│ セキュリティ │
│ プリンシパル │ ← 誰が（ユーザー、グループ、SP、マネージドID）
└──────┬───────┘
       │
       │ 割り当て
       ↓
┌──────────────┐
│   ロール     │ ← 何ができる（権限の集合）
└──────┬───────┘
       │
       │ 適用先
       ↓
┌──────────────┐
│   スコープ   │ ← どこで（管理グループ、サブスク、RG、リソース）
└──────────────┘
```

### 主要な組み込みロール

| ロール | 説明 | 使用例 |
|--------|------|--------|
| **Owner** | 完全なアクセス権、RBAC管理可能 | リソース所有者 |
| **Contributor** | リソース作成・管理可能、RBAC管理不可 | 開発者 |
| **Reader** | リソース閲覧のみ | 監査担当者 |
| **User Access Administrator** | RBAC管理のみ | セキュリティ管理者 |
| **Virtual Machine Contributor** | VM管理専用 | VMオペレーター |
| **Storage Account Contributor** | ストレージアカウント管理 | ストレージ管理者 |
| **Network Contributor** | ネットワークリソース管理 | ネットワーク管理者 |

### リポジトリファイル参照: `governance.tf`

```hcl
# RBACロール割り当ての例
resource "azurerm_role_assignment" "contributor" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = var.principal_id
}

# カスタムロール定義の例
resource "azurerm_role_definition" "custom" {
  name  = "Custom VM Operator"
  scope = data.azurerm_subscription.primary.id
  
  permissions {
    actions = [
      "Microsoft.Compute/virtualMachines/start/action",
      "Microsoft.Compute/virtualMachines/restart/action",
      "Microsoft.Compute/virtualMachines/read"
    ]
    not_actions = []
  }
}
```

### RBACのベストプラクティス

1. **最小権限の原則**: 必要最小限の権限のみを付与
2. **グループベースの割り当て**: 個別ユーザーではなくグループに割り当て
3. **適切なスコープ選択**: 必要なスコープでのみ権限付与
4. **カスタムロールの活用**: 組み込みロールが適さない場合に使用
5. **定期的なレビュー**: アクセス権限の定期的な監査

## 1.3 Azure Policy

### 概念説明

Azure Policyは、組織の標準を強制し、コンプライアンスを大規模に評価するサービスです。

### Policyの構成要素

```
ポリシー定義（Policy Definition）
    ↓
イニシアティブ定義（Initiative/Policy Set）
    ↓ 複数のポリシーをグループ化
割り当て（Assignment）
    ↓ スコープに適用
評価（Evaluation）
    ↓
コンプライアンスレポート
```

### ポリシーの効果（Effects）

| 効果 | 動作 | 使用例 |
|------|------|--------|
| **Deny** | リソース作成/更新を拒否 | 特定リージョン以外での作成を拒否 |
| **Audit** | 非準拠時に警告イベント作成 | タグなしリソースの検出 |
| **Append** | リソースに追加のプロパティを追加 | 自動的にタグを追加 |
| **Modify** | リソースのプロパティを変更 | マネージドIDの有効化 |
| **DeployIfNotExists** | 条件に応じてリソースをデプロイ | 診断設定の自動構成 |
| **AuditIfNotExists** | 関連リソースの存在を監査 | バックアップ設定の確認 |
| **Disabled** | ポリシーを無効化 | テスト用 |

### リポジトリファイル参照: `governance.tf`

```hcl
# タグ強制ポリシー
resource "azurerm_policy_definition" "require_tag" {
  name         = "require-environment-tag"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Require Environment Tag"
  
  policy_rule = jsonencode({
    if = {
      field  = "tags['Environment']"
      exists = "false"
    }
    then = {
      effect = "deny"
    }
  })
}

# ポリシー割り当て
resource "azurerm_resource_group_policy_assignment" "tag_policy" {
  name                 = "require-env-tag"
  resource_group_id    = azurerm_resource_group.main.id
  policy_definition_id = azurerm_policy_definition.require_tag.id
}

# 組み込みポリシーの使用例
resource "azurerm_subscription_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations"
  subscription_id      = data.azurerm_subscription.primary.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"
  
  parameters = jsonencode({
    listOfAllowedLocations = {
      value = ["japaneast", "japanwest"]
    }
  })
}
```

### ポリシーの一般的な使用例

1. **リージョン制限**: 特定のリージョンでのみリソース作成を許可
2. **タグ強制**: 必須タグの適用（Environment、CostCenter等）
3. **SKU制限**: 高コストなSKUの使用を制限
4. **セキュリティ強制**: ストレージアカウントのHTTPS通信強制
5. **診断設定**: すべてのリソースでログ収集を強制

## 1.4 リソースロック

### 概念説明

リソースロックは、重要なリソースの誤削除や誤変更を防ぐ保護メカニズムです。

### ロックの種類

```
┌─────────────────────────────────────────────┐
│ ReadOnly（読み取り専用）                    │
│ - 読み取り操作のみ可能                      │
│ - 更新・削除操作は拒否                      │
│ - GET操作は許可、PUT/DELETE/POST は拒否     │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│ CanNotDelete（削除不可）                    │
│ - 読み取り・更新操作は可能                  │
│ - 削除操作のみ拒否                          │
│ - GET/PUT/POST は許可、DELETE は拒否        │
└─────────────────────────────────────────────┘
```

### ロックの継承

```
管理グループ
    ↓ 継承
サブスクリプション
    ↓ 継承
リソースグループ
    ↓ 継承
個別リソース
```

### リポジトリファイル参照: `governance.tf`

```hcl
# リソースグループレベルのロック
resource "azurerm_management_lock" "rg_lock" {
  name       = "prevent-deletion"
  scope      = azurerm_resource_group.main.id
  lock_level = "CanNotDelete"
  notes      = "This resource group contains production resources"
}

# 個別リソースへのロック
resource "azurerm_management_lock" "storage_lock" {
  name       = "storage-readonly"
  scope      = azurerm_storage_account.main.id
  lock_level = "ReadOnly"
  notes      = "Production storage account - read only"
}
```

### ロックに関する重要なポイント

1. **Owner または User Access Administrator ロールが必要**
2. **ロック削除後にリソース操作が可能**
3. **子リソースに継承される**
4. **Azure Policyよりも優先される**
5. **ReadOnlyロックでもAzure RBACの読み取り操作は可能**

## 1.5 管理グループ

### 概念説明

管理グループは、複数のサブスクリプションを階層的に整理し、ガバナンスを大規模に適用するための構造です。

### 管理グループの階層

```
ルート管理グループ（テナントルート）
    ↓
┌───────────────┴───────────────┐
│                               │
本番環境                    非本番環境
    ↓                           ↓
┌───┴───┐               ┌───────┴───────┐
│       │               │               │
東日本  西日本          開発環境       テスト環境
    ↓       ↓               ↓               ↓
サブスク  サブスク        サブスク        サブスク
```

### 管理グループの制限

- **階層の深さ**: 最大6レベル（ルートを除く）
- **親管理グループ**: 1つの管理グループは1つの親のみ
- **子の数**: 制限なし
- **サブスクリプション**: 1つのサブスクリプションは1つの親管理グループのみ

### 管理グループのベストプラクティス

1. **環境による分離**: 本番/非本番の明確な分離
2. **ポリシーの適用**: 上位レベルで共通ポリシーを適用
3. **RBAC の設定**: 管理グループレベルでの権限管理
4. **シンプルな構造**: 必要以上に複雑にしない（3-4レベル推奨）

## 1.6 サブスクリプション管理

### 概念説明

Azureサブスクリプションは、Azureリソースの論理コンテナであり、課金の境界です。

### サブスクリプションの種類

| 種類 | 説明 | 用途 |
|------|------|------|
| **従量課金制** | 使用量に応じた課金 | 一般的な利用 |
| **Enterprise Agreement (EA)** | 大企業向け契約 | 大規模組織 |
| **CSP** | クラウドソリューションプロバイダー経由 | パートナー経由 |
| **無料試用版** | $200クレジット（30日間） | 評価・学習 |
| **Visual Studio サブスクリプション** | 開発者向け月額クレジット | 開発・テスト |

### サブスクリプションのリミットとクォータ

```
リソースタイプごとの制限例:
┌─────────────────────────────────────────┐
│ リソースグループ/サブスク: 980          │
│ 可用性セット/サブスク: 2,500           │
│ VM/リージョン: 25,000                  │
│ vCPU/リージョン: 350（標準）           │
│ ストレージアカウント/サブスク: 250      │
│ パブリックIPアドレス: 1,000            │
└─────────────────────────────────────────┘
```

### コスト管理

#### リポジトリファイル参照: `budget.tf`

```hcl
# 予算アラートの設定
resource "azurerm_consumption_budget_subscription" "monthly" {
  name            = "monthly-budget"
  subscription_id = data.azurerm_subscription.primary.id
  
  amount     = 10000
  time_grain = "Monthly"
  
  time_period {
    start_date = "2024-01-01T00:00:00Z"
  }
  
  notification {
    enabled   = true
    threshold = 80
    operator  = "GreaterThan"
    
    contact_emails = [
      "admin@example.com"
    ]
  }
  
  notification {
    enabled   = true
    threshold = 100
    operator  = "GreaterThan"
    
    contact_emails = [
      "admin@example.com"
    ]
  }
}
```

## 1.7 タグ管理

### 概念説明

タグは、リソースにメタデータを付与し、整理・コスト管理・自動化に活用するキーバリューペアです。

### タグの制限

- **リソースあたりのタグ数**: 最大50個
- **タグ名**: 最大512文字
- **タグ値**: 最大256文字
- **大文字小文字**: 一部のリソースタイプでは区別されない

### 推奨タグ戦略

```
必須タグの例:
┌──────────────────────────────────────────┐
│ Environment: Production/Staging/Dev      │
│ CostCenter: CC-001                       │
│ Owner: team@example.com                  │
│ Project: ProjectName                     │
│ ExpirationDate: 2024-12-31               │
│ Compliance: PCI-DSS/HIPAA/ISO27001       │
└──────────────────────────────────────────┘
```

### リポジトリファイル参照: `governance.tf`

```hcl
# タグポリシー - 継承
resource "azurerm_policy_definition" "inherit_tag" {
  name         = "inherit-environment-tag"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Inherit Environment Tag from Resource Group"
  
  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "tags['Environment']"
          exists = "false"
        },
        {
          value  = "[resourceGroup().tags['Environment']]"
          notEquals = ""
        }
      ]
    }
    then = {
      effect = "append"
      details = [
        {
          field = "tags['Environment']"
          value = "[resourceGroup().tags['Environment']]"
        }
      ]
    }
  })
}
```

### タグによるコスト分析

```
コスト管理でのタグ活用:
1. CostCenterタグでコストセンター別集計
2. Projectタグでプロジェクト別コスト追跡
3. Environmentタグで環境別コスト比較
4. Ownerタグでチーム別コスト可視化
```

## 1.8 試験対策のポイント

### Domain 1 重要ポイント

1. **Entra ID のエディションと機能の違い**
   - Freeでできること/できないこと
   - Premium P1とP2の違い（Identity Protection、PIM）

2. **RBAC の適用範囲とスコープの理解**
   - 継承の仕組み
   - Deny割り当ての動作

3. **Azure Policy の効果（Effects）の違い**
   - Deny vs Audit
   - DeployIfNotExists vs AuditIfNotExists

4. **リソースロックの動作**
   - ReadOnly vs CanNotDelete
   - 削除の手順

5. **管理グループの階層制限**
   - 最大6レベル
   - ポリシーとRBACの継承

### 試験Tips

✅ **RBACは累積的、Denyは常に優先**
✅ **Policyは評価のみ、実際の拒否はEffectによる**
✅ **ロックは最も強力な保護（RBACやPolicyより優先）**
✅ **タグはリソースグループから自動継承されない（Policyで実装）**
✅ **管理グループのポリシーは子に継承、削除不可**

## Domain 1 練習問題

### 問題1
あなたの会社は、すべてのAzureリソースに「CostCenter」タグを必須にしたいと考えています。タグがないリソースの作成を防ぐには、どのAzure Policy効果を使用すべきですか？

A) Audit  
B) Append  
C) Deny  
D) DeployIfNotExists

<details>
<summary>解答と解説</summary>

**正解: C) Deny**

**解説:**
- **Deny**: タグがない場合にリソース作成を拒否します。これが要件に最も適しています。
- **Audit**: 非準拠を記録するだけで、作成は許可されます。
- **Append**: リソースに自動的にタグを追加しますが、作成は拒否しません。
- **DeployIfNotExists**: 条件に応じて追加リソースをデプロイしますが、作成自体は拒否しません。

**参照:** `governance.tf` - ポリシー定義の例
</details>

### 問題2
開発チームがリソースグループ内のVMを作成・管理できるが、RBACの権限を変更できないようにする必要があります。どのロールを割り当てるべきですか？

A) Owner  
B) Contributor  
C) Virtual Machine Contributor  
D) Reader

<details>
<summary>解答と解説</summary>

**正解: B) Contributor**

**解説:**
- **Contributor**: リソースの作成・管理が可能ですが、RBAC権限の変更はできません。
- **Owner**: RBAC権限の管理も可能なため、要件に合いません。
- **Virtual Machine Contributor**: VM専用で、他のリソース（ネットワーク等）を作成できない可能性があります。
- **Reader**: 読み取り専用で、リソース作成ができません。

**ポイント:** ContributorはOwnerから「権限管理能力」を除いたロールです。

**参照:** `governance.tf` - RBAC ロール割り当て
</details>

### 問題3
本番環境のストレージアカウントを誤って削除されないように保護したいが、管理者が設定を変更できるようにする必要があります。どのリソースロックを使用すべきですか？

A) ReadOnly  
B) CanNotDelete  
C) Delete  
D) DoNotDelete

<details>
<summary>解答と解説</summary>

**正解: B) CanNotDelete**

**解説:**
- **CanNotDelete**: 削除は防ぎますが、読み取りと更新（設定変更）は可能です。これが要件に合致します。
- **ReadOnly**: 読み取りのみで、設定変更もできなくなります。
- **Delete / DoNotDelete**: 存在しないロックタイプです。

**リソースロックは2種類のみ:**
1. CanNotDelete（削除不可）
2. ReadOnly（読み取り専用）

**参照:** `governance.tf` - リソースロック定義
</details>

### 問題4
組織には3つの部門があり、それぞれが独自のサブスクリプションを持っています。すべての部門に対して、Japan EastとJapan Westのリージョンのみでリソース作成を許可するポリシーを適用したいです。最も効率的な方法は？

A) 各サブスクリプションに個別にポリシーを割り当てる  
B) 管理グループを作成し、3つのサブスクリプションを追加して、管理グループレベルでポリシーを割り当てる  
C) 各リソースグループにポリシーを割り当てる  
D) Azure Policy Initiativeを作成する

<details>
<summary>解答と解説</summary>

**正解: B) 管理グループを作成し、3つのサブスクリプションを追加して、管理グループレベルでポリシーを割り当てる**

**解説:**
管理グループを使用することで、複数のサブスクリプションに対してポリシーを一度に適用でき、管理が効率的になります。

**管理グループの利点:**
- 一元管理: 1回の割り当てで複数サブスクリプションに適用
- 継承: 子サブスクリプションに自動的に継承
- 変更容易性: ポリシー変更が一箇所で済む

**参照:** `governance.tf` - ポリシー割り当て例
</details>

### 問題5
ユーザーがKey Vaultからシークレットを読み取れるようにする必要がありますが、Key Vault自体の設定は変更できないようにしたいです。どのアクションを持つカスタムRBACロールを作成すべきですか？

A) Microsoft.KeyVault/vaults/read および Microsoft.KeyVault/vaults/secrets/read  
B) Microsoft.KeyVault/vaults/secrets/getSecret/action  
C) Microsoft.KeyVault/vaults/*/read  
D) Microsoft.KeyVault/vaults/read および Microsoft.KeyVault/vaults/secrets/*/read

<details>
<summary>解答と解説</summary>

**正解: B) Microsoft.KeyVault/vaults/secrets/getSecret/action**

**解説:**
シークレットの読み取りには、データプレーン操作の `getSecret/action` が必要です。

**Key Vault の2つのプレーン:**
- **管理プレーン**: Key Vault自体の管理（作成、削除、設定変更）
- **データプレーン**: シークレット、キー、証明書の操作

**必要なアクション:**
- `Microsoft.KeyVault/vaults/read`: Key Vaultのメタデータ読み取り
- `Microsoft.KeyVault/vaults/secrets/getSecret/action`: シークレット値の取得

**参照:** `keyvault.tf` - Key Vault RBAC設定
</details>

### 問題6
Azure Policyを使用して、すべてのVMにMicrosoft Monitoring Agentがインストールされていることを確認し、インストールされていない場合は自動的にインストールしたいです。どのポリシー効果を使用すべきですか？

A) Append  
B) Deny  
C) DeployIfNotExists  
D) AuditIfNotExists

<details>
<summary>解答と解説</summary>

**正解: C) DeployIfNotExists**

**解説:**
**DeployIfNotExists**: 条件（エージェント未インストール）に該当する場合、自動的にリソース（VM拡張機能）をデプロイします。

**各効果の違い:**
- **DeployIfNotExists**: 不足しているリソースを自動作成
- **AuditIfNotExists**: 不足を検出するだけ（修復はしない）
- **Append**: プロパティ追加のみ（新規リソース作成は不可）
- **Deny**: 作成を拒否（自動デプロイはしない）

**修復タスク:**
既存のリソースに対しては、修復タスクを手動で実行する必要があります。

**参照:** `virtual_machines.tf` - VM拡張機能の例
</details>

---

# Domain 2: ストレージの実装と管理 (15-20%)

## 2.1 ストレージアカウントの基礎

### 概念説明

Azure Storage Accountは、Azure Storage サービス（Blob、Files、Queue、Table、Disk）のための名前空間を提供します。

### ストレージアカウントの種類

```
┌─────────────────────────────────────────────────────────┐
│ Storage Account の種類                                  │
├─────────────────────────────────────────────────────────┤
│ Standard (汎用v2)    │ 推奨、すべてのサービス対応      │
│ Premium Block Blobs  │ 高スループットのBlob専用        │
│ Premium File Shares  │ エンタープライズファイル共有    │
│ Premium Page Blobs   │ VMディスク専用                 │
└─────────────────────────────────────────────────────────┘
```

### パフォーマンス層

| 層 | 用途 | 特徴 |
|------|------|------|
| **Standard** | 一般的な用途 | HDD、低コスト |
| **Premium** | 低遅延が必要 | SSD、高IOPS、高スループット |

### アクセス層（Blob のみ）

```
Hot (ホット層)
├─ 頻繁なアクセス
├─ ストレージコスト: 高
└─ アクセスコスト: 低

Cool (クール層)
├─ 月1回程度のアクセス
├─ 最低保存期間: 30日
├─ ストレージコスト: 中
└─ アクセスコスト: 中

Cold (コールド層)
├─ 3ヶ月程度のアクセス
├─ 最低保存期間: 90日
├─ ストレージコスト: やや低
└─ アクセスコスト: やや高

Archive (アーカイブ層)
├─ めったにアクセスしない
├─ 最低保存期間: 180日
├─ ストレージコスト: 最低
├─ アクセスコスト: 最高
└─ リハイドレート時間: 数時間〜15時間
```

### リポジトリファイル参照: `storage.tf`

```hcl
# 汎用v2 ストレージアカウント
resource "azurerm_storage_account" "main" {
  name                     = "mystorageaccount"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  account_kind             = "StorageV2"
  
  # セキュリティ設定
  enable_https_traffic_only       = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  
  # ネットワーク設定
  network_rules {
    default_action             = "Deny"
    ip_rules                   = ["203.0.113.0/24"]
    virtual_network_subnet_ids = [azurerm_subnet.main.id]
    bypass                     = ["AzureServices"]
  }
  
  # Blob設定
  blob_properties {
    versioning_enabled  = true
    change_feed_enabled = true
    
    delete_retention_policy {
      days = 30
    }
    
    container_delete_retention_policy {
      days = 30
    }
  }
}
```

## 2.2 データ冗長性

### 概念説明

データ冗長性オプションは、データの耐久性と可用性を決定します。

### 冗長性オプション

```
同一リージョン内:
┌──────────────────────────────────────────────┐
│ LRS (Locally Redundant Storage)              │
│ ├─ 3つのコピー（同一データセンター内）      │
│ ├─ 耐久性: 99.999999999% (11 9's)           │
│ ├─ 最低コスト                                │
│ └─ データセンター障害に弱い                  │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│ ZRS (Zone Redundant Storage)                 │
│ ├─ 3つの可用性ゾーンに分散                  │
│ ├─ 耐久性: 99.9999999999% (12 9's)          │
│ ├─ ゾーン障害に対応                          │
│ └─ LRSより高コスト                           │
└──────────────────────────────────────────────┘

リージョン間:
┌──────────────────────────────────────────────┐
│ GRS (Geo Redundant Storage)                  │
│ ├─ プライマリ: LRS (3コピー)                │
│ ├─ セカンダリ: LRS (3コピー、別リージョン)  │
│ ├─ 耐久性: 99.99999999999999% (16 9's)      │
│ ├─ セカンダリは読み取り不可（通常時）        │
│ └─ フェイルオーバー: 手動                    │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│ RA-GRS (Read Access GRS)                     │
│ ├─ GRS + セカンダリリージョンへの読み取り   │
│ ├─ 読み取りエンドポイント: 2つ              │
│ └─ 高可用性アプリケーション向け              │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│ GZRS (Geo Zone Redundant Storage)            │
│ ├─ プライマリ: ZRS                           │
│ ├─ セカンダリ: LRS (別リージョン)           │
│ └─ 最高レベルの耐久性と可用性                │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│ RA-GZRS (Read Access GZRS)                   │
│ ├─ GZRS + セカンダリへの読み取りアクセス    │
│ └─ 最高レベルの可用性                        │
└──────────────────────────────────────────────┘
```

### 冗長性の選択ガイド

| 要件 | 推奨オプション |
|------|----------------|
| 最低コスト | LRS |
| データセンター障害対策 | ZRS |
| リージョン障害対策 | GRS / GZRS |
| セカンダリリージョンからの読み取り | RA-GRS / RA-GZRS |
| 最高の耐久性と可用性 | RA-GZRS |

## 2.3 Azure Blob Storage

### 概念説明

Blob Storageは、テキストやバイナリデータなどの非構造化データを格納するためのオブジェクトストレージです。

### Blobの種類

```
Block Blob（ブロックBlob）
├─ 用途: テキスト、バイナリファイル
├─ 最大サイズ: 約190.7 TiB
├─ 構成: 最大50,000ブロック
└─ 使用例: ドキュメント、動画、バックアップ

Append Blob（追加Blob）
├─ 用途: ログファイル
├─ 最大サイズ: 約195 GiB
├─ 特徴: 追加操作に最適化
└─ 使用例: アプリケーションログ、監査ログ

Page Blob（ページBlob）
├─ 用途: ランダムアクセス
├─ 最大サイズ: 8 TiB
├─ 構成: 512バイトページ
└─ 使用例: VMディスク（VHD/VHDX）
```

### リポジトリファイル参照: `storage.tf`

```hcl
# Blobコンテナー
resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# ライフサイクル管理
resource "azurerm_storage_management_policy" "lifecycle" {
  storage_account_id = azurerm_storage_account.main.id
  
  rule {
    name    = "move-to-cool"
    enabled = true
    
    filters {
      prefix_match = ["data/logs"]
      blob_types   = ["blockBlob"]
    }
    
    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 30
        tier_to_archive_after_days_since_modification_greater_than = 90
        delete_after_days_since_modification_greater_than          = 365
      }
      
      snapshot {
        delete_after_days_since_creation_greater_than = 90
      }
    }
  }
}

# Blob バージョニング（論理削除されたBlobの自動削除）
resource "azurerm_storage_account" "main" {
  # ... 他の設定 ...
  
  blob_properties {
    versioning_enabled = true
    
    delete_retention_policy {
      days = 30
    }
  }
}
```

### Blob アクセス層の変更

```
アクセス層の変更方法:
1. アカウントレベル（デフォルト層）
2. 個別Blobレベル
3. ライフサイクル管理（自動）

アーカイブからのリハイドレート:
┌─────────────────────────────────────┐
│ 優先度: Standard (最大15時間)       │
│ 優先度: High (1時間以内)            │
└─────────────────────────────────────┘
```

## 2.4 Azure Files

### 概念説明

Azure Filesは、SMBおよびNFSプロトコルを使用してアクセスできるフルマネージドのファイル共有サービスです。

### Azure Files の特徴

```
プロトコルサポート:
┌────────────────────────────────────────┐
│ SMB (Server Message Block)             │
│ ├─ SMB 2.1: Azure VMのみ               │
│ ├─ SMB 3.0: 暗号化、オンプレミス可     │
│ ├─ SMB 3.1.1: 最新、推奨               │
│ └─ OS: Windows, Linux, macOS           │
└────────────────────────────────────────┘

┌────────────────────────────────────────┐
│ NFS (Network File System) 4.1          │
│ ├─ Premium ファイル共有のみ            │
│ ├─ OS: Linux                           │
│ └─ 認証: ネットワークベース            │
└────────────────────────────────────────┘
```

### パフォーマンス層

| 層 | IOPS | スループット | 用途 |
|------|------|--------------|------|
| **Standard** | 最大10,000 | 最大300 MiB/s | 一般的なファイル共有 |
| **Premium** | 最大100,000 | 最大10 GiB/s | 高パフォーマンス、低遅延 |

### リポジトリファイル参照: `storage.tf`

```hcl
# Azure ファイル共有
resource "azurerm_storage_share" "files" {
  name                 = "shared-files"
  storage_account_name = azurerm_storage_account.main.name
  quota                = 100  # GB
  
  enabled_protocol = "SMB"
  
  acl {
    id = "GhostedDirectory"
    
    access_policy {
      permissions = "r"
      start       = "2024-01-01T00:00:00Z"
      expiry      = "2024-12-31T23:59:59Z"
    }
  }
}

# Premium ファイル共有（別ストレージアカウント）
resource "azurerm_storage_account" "premium_files" {
  name                     = "premiumfilesaccount"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Premium"
  account_kind             = "FileStorage"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "premium" {
  name                 = "premium-share"
  storage_account_name = azurerm_storage_account.premium_files.name
  quota                = 100
  enabled_protocol     = "SMB"
}
```

### Azure File Sync

```
オンプレミスとの同期:
┌─────────────────────────────────────────────┐
│ オンプレミスファイルサーバー                │
│         ↓ Azure File Sync Agent             │
│ Storage Sync Service                        │
│         ↓ 同期                               │
│ Azure ファイル共有                          │
└─────────────────────────────────────────────┘

メリット:
- クラウドティアリング（頻繁にアクセスされないファイルはクラウドへ）
- マルチサイト同期
- バックアップと災害復旧
- リフト&シフト
```

## 2.5 ストレージのセキュリティ

### Shared Access Signature (SAS)

```
SASの種類:
┌────────────────────────────────────────────┐
│ User Delegation SAS (推奨)                 │
│ ├─ Entra ID資格情報で保護                  │
│ ├─ Blob、コンテナーのみ                    │
│ └─ 最もセキュア                             │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ Service SAS                                │
│ ├─ ストレージアカウントキーで署名          │
│ ├─ 1つのサービス（Blob, Queue等）         │
│ └─ きめ細かいアクセス制御                   │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ Account SAS                                │
│ ├─ ストレージアカウントキーで署名          │
│ ├─ 複数サービス                            │
│ └─ サービスレベル操作も可能                │
└────────────────────────────────────────────┘
```

### SASパラメータ

```
必須パラメータ:
- sv (SignedVersion): APIバージョン
- sr (SignedResource): リソースタイプ（b=blob, c=container）
- sp (SignedPermissions): 権限（r=read, w=write, d=delete, l=list）
- se (SignedExpiry): 有効期限
- sig (Signature): 署名

オプション:
- st (SignedStart): 開始時刻
- sip (SignedIP): IPアドレス制限
- spr (SignedProtocol): https のみ等
```

### ストレージアカウントキー

```
キー管理のベストプラクティス:
┌────────────────────────────────────────────┐
│ 1. 定期的なキーローテーション              │
│ 2. Key Vaultでの保管                       │
│ 3. Entra ID認証を優先使用                  │
│ 4. 共有キー認証の無効化（可能な場合）      │
│ 5. アクティビティログの監視                │
└────────────────────────────────────────────┘

キーローテーション手順:
1. セカンダリキーを再生成
2. アプリケーションをセカンダリキーに更新
3. プライマリキーを再生成
4. アプリケーションをプライマリキーに戻す（オプション）
```

### リポジトリファイル参照: `keyvault.tf`

```hcl
# Key Vault にストレージアカウントキーを保存
resource "azurerm_key_vault_secret" "storage_key" {
  name         = "storage-account-key"
  value        = azurerm_storage_account.main.primary_access_key
  key_vault_id = azurerm_key_vault.main.id
  
  content_type = "Storage Account Key"
  
  expiration_date = "2024-12-31T23:59:59Z"
}
```

### ネットワークセキュリティ

```
ファイアウォール設定:
┌────────────────────────────────────────────┐
│ デフォルトアクション: Deny                 │
│ ├─ 許可するIPアドレス範囲                  │
│ ├─ 許可する仮想ネットワーク                │
│ └─ 例外: Azure Services                    │
└────────────────────────────────────────────┘

プライベートエンドポイント:
┌────────────────────────────────────────────┐
│ VNet内にプライベートIPアドレス             │
│ ├─ パブリックアクセス不要                  │
│ ├─ Private DNS Zone統合                    │
│ └─ サービスエンドポイントより安全          │
└────────────────────────────────────────────┘
```

### リポジトリファイル参照: `network.tf`

```hcl
# ストレージアカウント用プライベートエンドポイント
resource "azurerm_private_endpoint" "storage" {
  name                = "storage-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private.id
  
  private_service_connection {
    name                           = "storage-psc"
    private_connection_resource_id = azurerm_storage_account.main.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }
  
  private_dns_zone_group {
    name                 = "storage-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }
}

# Private DNS Zone
resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "blob-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.main.id
}
```

## 2.6 データ保護とバックアップ

### 論理削除（Soft Delete）

```
Blob の論理削除:
┌────────────────────────────────────────────┐
│ 削除されたBlob/スナップショットを保持      │
│ ├─ 保持期間: 1〜365日                      │
│ ├─ 誤削除からの保護                        │
│ └─ 保持期間内は復元可能                    │
└────────────────────────────────────────────┘

コンテナーの論理削除:
┌────────────────────────────────────────────┐
│ 削除されたコンテナーを保持                │
│ ├─ 保持期間: 1〜365日                      │
│ └─ コンテナーとその内容を復元              │
└────────────────────────────────────────────┘

ファイル共有の論理削除:
┌────────────────────────────────────────────┐
│ 削除されたファイル共有を保持              │
│ ├─ 保持期間: 1〜365日                      │
│ └─ スナップショットから復元                │
└────────────────────────────────────────────┘
```

### Blobバージョニング

```
バージョン管理の仕組み:
Blob作成 → Version 1 (現在のバージョン)
    ↓ 更新
Version 1 (以前のバージョン) + Version 2 (現在)
    ↓ 削除
Version 1 + Version 2 (削除マーカー付き)

メリット:
- 誤った上書きからの保護
- 以前のバージョンへの復元
- 変更履歴の追跡
```

### 不変ストレージ

```
不変ポリシーの種類:
┌────────────────────────────────────────────┐
│ 時間ベースの保持ポリシー                  │
│ ├─ 指定期間中は変更・削除不可              │
│ ├─ 期間: 1日〜146,000日                    │
│ └─ コンプライアンス要件に対応              │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ 訴訟ホールド（Legal Hold）                │
│ ├─ 明示的に解除されるまで保護              │
│ └─ 法的調査・訴訟対応                      │
└────────────────────────────────────────────┘

WORM (Write Once, Read Many):
- 金融規制（SEC 17a-4等）
- 医療規制（HIPAA）
- 一般的なコンプライアンス
```

## 2.7 ストレージのコスト最適化

### ライフサイクル管理ポリシー

```
ルールアクションの例:
┌────────────────────────────────────────────────┐
│ 作成後30日 → Cool層に移動                      │
│ 作成後90日 → Archive層に移動                   │
│ 作成後365日 → 削除                             │
│ スナップショット作成後90日 → 削除              │
│ バージョン作成後180日 → 削除                   │
└────────────────────────────────────────────────┘
```

### リポジトリファイル参照: `storage.tf` (ライフサイクルポリシー)

```hcl
resource "azurerm_storage_management_policy" "lifecycle" {
  storage_account_id = azurerm_storage_account.main.id
  
  # ログファイルの管理
  rule {
    name    = "log-retention"
    enabled = true
    
    filters {
      prefix_match = ["logs/"]
      blob_types   = ["blockBlob"]
    }
    
    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 7
        tier_to_archive_after_days_since_modification_greater_than = 30
        delete_after_days_since_modification_greater_than          = 90
      }
    }
  }
  
  # バックアップの管理
  rule {
    name    = "backup-retention"
    enabled = true
    
    filters {
      prefix_match = ["backups/"]
      blob_types   = ["blockBlob"]
    }
    
    actions {
      base_blob {
        tier_to_archive_after_days_since_modification_greater_than = 30
        delete_after_days_since_modification_greater_than          = 365
      }
      
      snapshot {
        tier_to_archive_after_days_since_creation_greater_than = 7
        delete_after_days_since_creation_greater_than          = 30
      }
    }
  }
}
```

### コスト削減のベストプラクティス

1. **適切なアクセス層の選択**
   - 頻繁にアクセス: Hot
   - 月1回程度: Cool
   - ほとんどアクセスしない: Archive

2. **ライフサイクル管理の活用**
   - 自動階層化
   - 古いデータの自動削除

3. **冗長性の適切な選択**
   - 開発/テスト環境: LRS
   - 本番環境: ZRS/GRS

4. **予約容量の購入**
   - 1年/3年コミットで割引

## 2.8 試験対策のポイント

### Domain 2 重要ポイント

1. **冗長性オプションの違い**
   - LRS, ZRS, GRS, RA-GRS, GZRS, RA-GZRS
   - 9の数（耐久性）を覚える

2. **アクセス層の特性**
   - 最低保存期間（Cool: 30日、Cold: 90日、Archive: 180日）
   - アーカイブからのリハイドレート時間

3. **SASの種類と使い分け**
   - User Delegation SAS（推奨）
   - Service SAS vs Account SAS

4. **Azure Files のプロトコル**
   - SMB vs NFS
   - Premium ファイル共有の要件

5. **データ保護機能**
   - 論理削除 vs バージョニング vs 不変ストレージ
   - それぞれの使用シーン

### 試験Tips

✅ **RA-GRS/RA-GZRSのみセカンダリリージョンから読み取り可能**
✅ **Archiveからのリハイドレートには時間がかかる（即座にアクセス不可）**
✅ **Premium ストレージはLRSまたはZRSのみ**
✅ **プライベートエンドポイントはサービスエンドポイントより安全**
✅ **ストレージアカウントキーは完全なアクセス権を持つ（使用は最小限に）**

## Domain 2 練習問題

### 問題1
会社のコンプライアンス要件により、監査ログを最低7年間保存し、その間変更や削除ができないようにする必要があります。どのAzure Storage機能を使用すべきですか？

A) Blob の論理削除（保持期間365日）  
B) 時間ベースの保持ポリシー（不変ストレージ）  
C) Blob バージョニング  
D) ライフサイクル管理ポリシー

<details>
<summary>解答と解説</summary>

**正解: B) 時間ベースの保持ポリシー（不変ストレージ）**

**解説:**
不変ストレージのWORM（Write Once, Read Many）機能により、指定期間中はBlobの変更・削除が不可能になります。

**各オプションの比較:**
- **時間ベースの保持ポリシー**: 指定期間（最大146,000日≈400年）変更・削除不可
- **論理削除**: 最大365日、削除は可能（復元可能期間）
- **バージョニング**: 変更履歴を保持するが、削除は可能
- **ライフサイクル管理**: 自動削除・移動であり、保護機能ではない

**コンプライアンス:**
SEC 17a-4(f)、HIPAA、FINRAなどの規制要件に対応

**参照:** `storage.tf` - Blob プロパティ設定
</details>

### 問題2
日本のユーザー向けWebアプリケーションで、静的コンテンツ（画像・CSS）を配信するストレージアカウントを作成します。可用性ゾーン障害に対応し、コストを抑えたい場合、どの冗長性オプションを選択すべきですか？

A) LRS  
B) ZRS  
C) GRS  
D) RA-GZRS

<details>
<summary>解答と解説</summary>

**正解: B) ZRS**

**解説:**
ZRS（Zone Redundant Storage）は、同一リージョン内の3つの可用性ゾーンにデータを分散し、ゾーン障害に対応します。

**要件分析:**
- 可用性ゾーン障害対応: ZRS または GZRS/RA-GZRS
- コスト抑制: ZRS（GRS系より安価）
- リージョン間冗長性不要: 日本のユーザー向けのみ

**コスト比較（概算）:**
LRS < ZRS < GRS < RA-GRS < GZRS < RA-GZRS

**参照:** `storage.tf` - account_replication_type設定
</details>

### 問題3
ストレージアカウントのBlobに対して、特定のサードパーティアプリケーションに一時的な書き込みアクセス権を付与する必要があります。ストレージアカウントキーを共有せず、最もセキュアな方法は？

A) ストレージアカウントキーを提供  
B) User Delegation SAS を生成  
C) アカウント全体に対するContributor ロールを割り当て  
D) パブリックアクセスを有効化

<details>
<summary>解答と解説</summary>

**正解: B) User Delegation SAS を生成**

**解説:**
User Delegation SASは、Entra ID資格情報で保護され、ストレージアカウントキーを使用しないため最もセキュアです。

**セキュリティ比較:**
1. **User Delegation SAS**: Entra ID認証、きめ細かい権限、有効期限設定可
2. **Service/Account SAS**: アカウントキーベース、User Delegationより劣る
3. **ストレージアカウントキー**: 完全なアクセス権（危険）
4. **RBAC ロール**: 一時的なアクセスに不向き
5. **パブリックアクセス**: 誰でもアクセス可能（最も危険）

**SAS のベストプラクティス:**
- 最小限の権限
- 短い有効期限
- IP制限の使用
- HTTPS のみ許可

**参照:** `storage.tf` - ストレージアカウント設定
</details>

### 問題4
アプリケーションログを保存するストレージアカウントがあります。ログは作成後30日間は頻繁にアクセスされますが、その後はほとんどアクセスされません。ただし、監査のため2年間は保持する必要があります。最もコスト効率の良い構成は？

A) すべてのログをHot層に保存  
B) ライフサイクル管理で、30日後にCool層、90日後にArchive層に移動  
C) すべてのログをArchive層に保存  
D) 30日後に手動でCool層に移動

<details>
<summary>解答と解説</summary>

**正解: B) ライフサイクル管理で、30日後にCool層、90日後にArchive層に移動**

**解説:**
ライフサイクル管理ポリシーにより、アクセスパターンに応じて自動的に適切な層に移動できます。

**アクセス層の使い分け:**
- **0-30日**: Hot層（頻繁なアクセス）
- **30-90日**: Cool層（月1回程度のアクセス）
- **90日以降**: Archive層（ほとんどアクセスなし、長期保存）

**コスト構造:**
- ストレージコスト: Hot > Cool > Archive
- アクセスコスト: Hot < Cool < Archive
- 最低保存期間: Hot なし、Cool 30日、Archive 180日

**参照:** `storage.tf` - ライフサイクル管理ポリシー
</details>

### 問題5
オンプレミスのファイルサーバーをAzureに移行し、SMBプロトコルで既存のアプリケーションから引き続きアクセスできるようにする必要があります。どのAzure サービスを使用すべきですか？

A) Azure Blob Storage  
B) Azure Files  
C) Azure Disk Storage  
D) Azure Data Lake Storage Gen2

<details>
<summary>解答と解説</summary>

**正解: B) Azure Files**

**解説:**
Azure Filesは、SMBおよびNFSプロトコルをサポートする唯一のストレージサービスで、既存のファイル共有アプリケーションとの互換性があります。

**各サービスの特性:**
- **Azure Files**: SMB/NFS、ファイル共有、リフト&シフトに最適
- **Blob Storage**: REST API、オブジェクトストレージ、SMB非対応
- **Disk Storage**: VMディスク専用、共有アクセス不可
- **Data Lake Gen2**: ビッグデータ分析用、階層的名前空間

**Azure File Sync:**
オンプレミスとのハイブリッド構成も可能で、段階的な移行に有効

**参照:** `storage.tf` - Azure Files 共有設定
</details>

### 問題6
ストレージアカウントへのアクセスを特定の仮想ネットワークからのみ許可し、パブリックインターネットからのアクセスを完全にブロックしたいです。どの機能を組み合わせて使用すべきですか？

A) ストレージファイアウォールでデフォルトアクションをDenyに設定し、VNetサービスエンドポイントを構成  
B) NSGでストレージアカウントへのトラフィックを制御  
C) Azure Policyでパブリックアクセスを拒否  
D) すべてのBlobコンテナーをプライベートに設定

<details>
<summary>解答と解説</summary>

**正解: A) ストレージファイアウォールでデフォルトアクションをDenyに設定し、VNetサービスエンドポイントを構成**

**解説:**
ストレージアカウントのネットワーク規則により、アクセスを特定のVNetに制限できます。

**ネットワークセキュリティの階層:**
1. **ストレージファイアウォール**: アカウントレベルのアクセス制御
   - デフォルトアクション: Deny
   - 許可: 特定のVNet/サブネット
   - 例外: Azure Servicesなど

2. **サービスエンドポイント**: VNetからストレージへの最適化されたルート

3. **プライベートエンドポイント**: より高度なセキュリティ（VNet内にプライベートIP）

**その他のオプションが不適切な理由:**
- NSG: ストレージアカウント自体には適用不可（VM等のNICに適用）
- Azure Policy: 設定を強制するが、実際のトラフィック制御は行わない
- コンテナーのプライベート設定: 匿名アクセスの制御のみ

**参照:** `storage.tf` - network_rules 設定、`network.tf` - サービスエンドポイント
</details>

---

# Domain 3: コンピューティングリソースのデプロイと管理 (20-25%)

## 3.1 Azure Virtual Machines（仮想マシン）

### 概念説明

Azure VMは、Azureクラウド上のオンデマンド、スケーラブルなコンピューティングリソースです。

### VMのサイズシリーズ

```
┌──────────────────────────────────────────────────────┐
│ 汎用 (B, D, DC, E シリーズ)                          │
│ ├─ B シリーズ: バースト可能、低コスト、開発/テスト  │
│ ├─ D シリーズ: バランス、一般的なワークロード        │
│ ├─ DC シリーズ: 機密コンピューティング              │
│ └─ E シリーズ: メモリ最適化、データベース            │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│ コンピューティング最適化 (F シリーズ)                │
│ ├─ 高い CPU/メモリ比                                 │
│ └─ 用途: Webサーバー、バッチ処理、ゲームサーバー    │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│ メモリ最適化 (E, M, Mv2 シリーズ)                   │
│ ├─ 高いメモリ/CPU比                                  │
│ └─ 用途: データベース、キャッシュ、インメモリ分析  │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│ ストレージ最適化 (L シリーズ)                        │
│ ├─ 高スループット、低遅延のローカルストレージ        │
│ └─ 用途: NoSQLデータベース、データウェアハウス      │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│ GPU (N シリーズ)                                     │
│ ├─ グラフィックス/コンピューティング GPU             │
│ └─ 用途: AI/ML、レンダリング、シミュレーション      │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│ ハイパフォーマンスコンピューティング (H シリーズ)    │
│ ├─ 最高のCPUパフォーマンス                           │
│ └─ 用途: シミュレーション、科学計算                  │
└──────────────────────────────────────────────────────┘
```

### VMのディスクタイプ

| ディスクタイプ | パフォーマンス | IOPS | スループット | 用途 |
|----------------|----------------|------|--------------|------|
| **Ultra Disk** | 最高 | 最大160,000 | 最大4,000 MB/s | ミッションクリティカル |
| **Premium SSD v2** | 超高 | 最大80,000 | 最大1,200 MB/s | 高性能ワークロード |
| **Premium SSD** | 高 | 最大20,000 | 最大900 MB/s | 本番環境 |
| **Standard SSD** | 中 | 最大6,000 | 最大750 MB/s | 一般的なワークロード |
| **Standard HDD** | 低 | 最大2,000 | 最大500 MB/s | バックアップ、非クリティカル |

### リポジトリファイル参照: `virtual_machines.tf`

```hcl
# 仮想マシンの作成
resource "azurerm_linux_virtual_machine" "main" {
  name                = "vm-prod-001"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_D2s_v3"
  
  # 管理者アカウント
  admin_username = "azureuser"
  
  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }
  
  # ネットワーク
  network_interface_ids = [
    azurerm_network_interface.main.id
  ]
  
  # OSディスク
  os_disk {
    name                 = "osdisk-vm-prod-001"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }
  
  # ソースイメージ
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  
  # ブート診断
  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.main.primary_blob_endpoint
  }
  
  # マネージドID
  identity {
    type = "SystemAssigned"
  }
  
  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}

# ネットワークインターフェース
resource "azurerm_network_interface" "main" {
  name                = "nic-vm-prod-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }
}

# パブリックIPアドレス
resource "azurerm_public_ip" "main" {
  name                = "pip-vm-prod-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# データディスク
resource "azurerm_managed_disk" "data" {
  name                 = "datadisk-vm-prod-001"
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = 512
}

resource "azurerm_virtual_machine_data_disk_attachment" "data" {
  managed_disk_id    = azurerm_managed_disk.data.id
  virtual_machine_id = azurerm_linux_virtual_machine.main.id
  lun                = 0
  caching            = "ReadWrite"
}
```

### VM拡張機能

```
主要な拡張機能:
┌────────────────────────────────────────────┐
│ Azure Monitor Agent                        │
│ ├─ メトリックとログの収集                  │
│ └─ Log Analytics ワークスペースへ送信      │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ カスタムスクリプト拡張機能                │
│ ├─ スクリプトのダウンロードと実行          │
│ └─ 初期構成、ソフトウェアインストール      │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ Desired State Configuration (DSC)          │
│ ├─ Windows VM の構成管理                   │
│ └─ 宣言的な構成                            │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ Antimalware                                │
│ ├─ Microsoft Antimalware                   │
│ └─ Windows VM 用                           │
└────────────────────────────────────────────┘
```

### リポジトリファイル参照: `virtual_machines.tf` (拡張機能)

```hcl
# Azure Monitor Agent拡張機能
resource "azurerm_virtual_machine_extension" "ama" {
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.main.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
}

# カスタムスクリプト拡張機能
resource "azurerm_virtual_machine_extension" "custom_script" {
  name                 = "CustomScript"
  virtual_machine_id   = azurerm_linux_virtual_machine.main.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"
  
  settings = jsonencode({
    commandToExecute = "sh install.sh"
  })
  
  protected_settings = jsonencode({
    fileUris = ["https://example.com/install.sh"]
  })
}
```

## 3.2 可用性オプション

### 概念説明

Azure では複数の可用性オプションを提供し、SLA を保証します。

### 可用性のオプション

```
┌────────────────────────────────────────────────────┐
│ 単一VM (Premium SSD/Ultra Disk使用)                │
│ ├─ SLA: 99.9%                                      │
│ ├─ 計画外ダウンタイム/年: 約8.76時間               │
│ └─ 用途: 非クリティカルワークロード                │
└────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────┐
│ 可用性セット (Availability Set)                    │
│ ├─ SLA: 99.95%                                     │
│ ├─ 障害ドメイン: 最大3（ラック障害対策）           │
│ ├─ 更新ドメイン: 最大20（計画メンテナンス対策）   │
│ └─ 用途: 同一データセンター内の高可用性            │
└────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────┐
│ 可用性ゾーン (Availability Zone)                   │
│ ├─ SLA: 99.99%                                     │
│ ├─ 物理的に分離されたデータセンター                │
│ ├─ 独立した電源、冷却、ネットワーク                │
│ └─ 用途: データセンター障害対策                    │
└────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────┐
│ 複数リージョン                                      │
│ ├─ SLA: カスタム（Traffic Manager等と組み合わせ）  │
│ ├─ リージョン全体の障害対策                        │
│ └─ 用途: 災害復旧、グローバル展開                  │
└────────────────────────────────────────────────────┘
```

### 可用性セットの仕組み

```
可用性セット内のVM配置:
┌─────────────────────────────────────────────────────┐
│               障害ドメイン (Fault Domain)           │
│  FD 0          FD 1          FD 2                   │
│  ┌───┐        ┌───┐        ┌───┐                   │
│  │VM1│  UD0   │VM2│  UD0   │VM3│  UD0              │
│  └───┘        └───┘        └───┘                   │
│  ┌───┐        ┌───┐        ┌───┐                   │
│  │VM4│  UD1   │VM5│  UD1   │VM6│  UD1              │
│  └───┘        └───┘        └───┘                   │
│                                                     │
│ 更新ドメイン (Update Domain)                        │
│ - 計画メンテナンス時に順次再起動                    │
│ - 同時に再起動されるのは1つのUDのみ                 │
└─────────────────────────────────────────────────────┘
```

### リポジトリファイル参照: `virtual_machines.tf` (可用性セット)

```hcl
# 可用性セット
resource "azurerm_availability_set" "main" {
  name                         = "avset-web"
  location                     = azurerm_resource_group.main.location
  resource_group_name          = azurerm_resource_group.main.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 5
  managed                      = true  # マネージドディスク使用
  
  tags = {
    Environment = "Production"
  }
}

# 可用性セット内のVM
resource "azurerm_linux_virtual_machine" "web" {
  count               = 3
  name                = "vm-web-${count.index + 1}"
  availability_set_id = azurerm_availability_set.main.id
  
  # ... 他の設定 ...
}
```

### 可用性ゾーンの使用

```hcl
# ゾーン冗長VM（3つのゾーンに分散）
resource "azurerm_linux_virtual_machine" "zonal" {
  count = 3
  name  = "vm-zonal-${count.index + 1}"
  zone  = tostring(count.index + 1)  # ゾーン 1, 2, 3
  
  # ... 他の設定 ...
}

# ゾーン冗長パブリックIP
resource "azurerm_public_ip" "zonal" {
  name              = "pip-zonal"
  sku               = "Standard"  # Standard SKU必須
  allocation_method = "Static"
  zones             = ["1", "2", "3"]
  
  # ... 他の設定 ...
}
```

## 3.3 Virtual Machine Scale Sets (VMSS)

### 概念説明

VMSSは、同一のVMのグループを作成・管理し、自動スケーリングを提供します。

### VMSSの特徴

```
VMSS のメリット:
┌────────────────────────────────────────────┐
│ 自動スケーリング                           │
│ ├─ メトリックベース（CPU、メモリ等）       │
│ ├─ スケジュールベース（時間指定）          │
│ └─ カスタムメトリック（App Insights等）   │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ 高可用性                                   │
│ ├─ 可用性ゾーン対応                        │
│ ├─ 自動修復                                │
│ └─ ローリングアップグレード                │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ 大規模管理                                 │
│ ├─ 最大1,000インスタンス（標準イメージ）  │
│ ├─ 最大600インスタンス（カスタムイメージ）│
│ └─ 統一された構成管理                      │
└────────────────────────────────────────────┘
```

### オーケストレーションモード

| モード | 説明 | 使用例 |
|--------|------|--------|
| **Uniform** | すべてのVMが同一、ステートレス | Webサーバー、バッチ処理 |
| **Flexible** | 異なる構成のVMを混在可能、ステートフル | マイクロサービス、データベース |

### 自動スケーリングルール

```
スケールアウト例:
条件: CPU使用率 > 70% が 5分間継続
アクション: インスタンス数を +1 増やす
クールダウン: 5分間

スケールイン例:
条件: CPU使用率 < 30% が 10分間継続
アクション: インスタンス数を -1 減らす
クールダウン: 5分間

制約:
最小インスタンス数: 2
最大インスタンス数: 10
デフォルトインスタンス数: 2
```

## 3.4 Azure App Service

### 概念説明

App Serviceは、Webアプリ、RESTful API、モバイルバックエンドをホストするフルマネージドPaaSです。

### App Service プラン

```
┌──────────────────────────────────────────────────────┐
│ 価格レベル                                           │
├──────────────────────────────────────────────────────┤
│ Free (F1)          │ 共有インフラ、60分/日制限       │
│ Shared (D1)        │ 共有インフラ、240分/日制限      │
├──────────────────────────────────────────────────────┤
│ Basic (B1-B3)      │ 専用VM、カスタムドメイン        │
│                    │ 手動スケール、最大3インスタンス │
├──────────────────────────────────────────────────────┤
│ Standard (S1-S3)   │ 自動スケール、ステージングスロット│
│                    │ 最大10インスタンス              │
├──────────────────────────────────────────────────────┤
│ Premium (P1v2-P3v2)│ 高性能、VNet統合               │
│ PremiumV3          │ 最大30インスタンス              │
├──────────────────────────────────────────────────────┤
│ Isolated (I1-I3)   │ App Service Environment (ASE)   │
│                    │ 完全分離、最大100インスタンス   │
└──────────────────────────────────────────────────────┘
```

### リポジトリファイル参照: `app_service.tf`

```hcl
# App Service Plan
resource "azurerm_service_plan" "main" {
  name                = "asp-prod"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = "P1v2"
  
  # ゾーン冗長（Premium V2以上）
  zone_balancing_enabled = true
}

# App Service (Web App)
resource "azurerm_linux_web_app" "main" {
  name                = "app-mywebapp-prod"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.main.id
  
  site_config {
    always_on = true
    
    application_stack {
      node_version = "18-lts"
    }
    
    # 仮想ネットワーク統合
    vnet_route_all_enabled = true
    
    # ヘルスチェック
    health_check_path = "/health"
  }
  
  # アプリケーション設定
  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.main.instrumentation_key
    "DATABASE_URL"                   = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.db_url.id})"
  }
  
  # 接続文字列
  connection_string {
    name  = "Database"
    type  = "PostgreSQL"
    value = azurerm_postgresql_server.main.fqdn
  }
  
  # HTTPS のみ
  https_only = true
  
  # マネージドID
  identity {
    type = "SystemAssigned"
  }
  
  # ログ
  logs {
    application_logs {
      file_system_level = "Information"
    }
    
    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
  }
}
```

### デプロイスロット

```
デプロイスロットの構成:
┌────────────────────────────────────────────┐
│ 本番スロット (Production)                  │
│ ├─ URL: myapp.azurewebsites.net            │
│ └─ 常時稼働                                │
└────────────────────────────────────────────┘
         ↑ スワップ
┌────────────────────────────────────────────┐
│ ステージングスロット (Staging)             │
│ ├─ URL: myapp-staging.azurewebsites.net    │
│ ├─ 新バージョンのテスト                    │
│ └─ 検証後に本番とスワップ                  │
└────────────────────────────────────────────┘

スロットの利点:
- ダウンタイムなしのデプロイ
- 本番前の検証
- 自動スワップ（CI/CD）
- スワップのロールバック可能
```

### リポジトリファイル参照: `app_service.tf` (デプロイスロット)

```hcl
# ステージングスロット
resource "azurerm_linux_web_app_slot" "staging" {
  name           = "staging"
  app_service_id = azurerm_linux_web_app.main.id
  
  site_config {
    always_on = true
    
    application_stack {
      node_version = "18-lts"
    }
  }
  
  # ステージング固有の設定
  app_settings = {
    "ENVIRONMENT"                    = "Staging"
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.main.instrumentation_key
  }
}
```

### 自動スケーリング

```hcl
# App Service 自動スケール設定
resource "azurerm_monitor_autoscale_setting" "app_service" {
  name                = "autoscale-appservice"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  target_resource_id  = azurerm_service_plan.main.id
  
  profile {
    name = "default"
    
    capacity {
      default = 2
      minimum = 2
      maximum = 10
    }
    
    # CPU ベースのスケールアウト
    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.main.id
        operator           = "GreaterThan"
        statistic          = "Average"
        threshold          = 70
        time_aggregation   = "Average"
        time_grain         = "PT1M"
        time_window        = "PT5M"
      }
      
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
    
    # CPU ベースのスケールイン
    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.main.id
        operator           = "LessThan"
        statistic          = "Average"
        threshold          = 30
        time_aggregation   = "Average"
        time_grain         = "PT1M"
        time_window        = "PT10M"
      }
      
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
  
  # スケジュールベースのスケーリング
  profile {
    name = "business-hours"
    
    capacity {
      default = 5
      minimum = 5
      maximum = 10
    }
    
    recurrence {
      timezone = "Tokyo Standard Time"
      days     = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
      hours    = [9]
      minutes  = [0]
    }
  }
}
```

## 3.5 Azure Container Registry (ACR)

### 概念説明

ACRは、プライベートDockerコンテナイメージとHelmチャートを保存・管理するマネージドレジストリです。

### ACR SKU

| SKU | ストレージ | Webhook | Geo複製 | 用途 |
|-----|-----------|---------|---------|------|
| **Basic** | 10 GiB | 2 | ✗ | 開発/テスト |
| **Standard** | 100 GiB | 10 | ✗ | 小規模本番 |
| **Premium** | 500 GiB | 500 | ✓ | エンタープライズ、高スループット |

### リポジトリファイル参照: `acr.tf`

```hcl
# Azure Container Registry
resource "azurerm_container_registry" "main" {
  name                = "acrmycompanyprod"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Premium"
  admin_enabled       = false  # Entra ID認証を推奨
  
  # Geo複製（Premium）
  georeplications {
    location = "japanwest"
    tags     = {}
  }
  
  # ネットワーク設定
  public_network_access_enabled = false
  network_rule_bypass_option    = "AzureServices"
  
  # イメージの保持ポリシー
  retention_policy {
    enabled = true
    days    = 30
  }
  
  # 信頼されたサービス
  trust_policy {
    enabled = true
  }
  
  identity {
    type = "SystemAssigned"
  }
}

# プライベートエンドポイント
resource "azurerm_private_endpoint" "acr" {
  name                = "pe-acr"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private.id
  
  private_service_connection {
    name                           = "psc-acr"
    private_connection_resource_id = azurerm_container_registry.main.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }
}
```

### ACRタスク

```
ACRタスクの用途:
┌────────────────────────────────────────────┐
│ クイックタスク                             │
│ ├─ オンデマンドでイメージをビルド          │
│ └─ az acr build コマンド                   │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ 自動トリガータスク                         │
│ ├─ ソースコードコミット時                  │
│ ├─ ベースイメージ更新時                    │
│ └─ スケジュール実行                        │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ マルチステップタスク                       │
│ ├─ YAML定義                                │
│ ├─ ビルド、テスト、プッシュ                │
│ └─ 複雑なワークフロー                      │
└────────────────────────────────────────────┘
```

## 3.6 Azure Container Instances (ACI)

### 概念説明

ACIは、オーケストレーターなしでコンテナを実行できる最速・最簡単な方法です。

### ACIの特徴

```
メリット:
- 秒単位の起動
- 秒単位の課金
- オーケストレーター不要
- ハイパーバイザーレベルの分離

使用例:
┌────────────────────────────────────────────┐
│ バッチジョブ                               │
│ CI/CDビルドエージェント                    │
│ イベント駆動アプリケーション                │
│ 開発/テスト環境                            │
│ タスク自動化                               │
└────────────────────────────────────────────┘
```

### コンテナグループ

```
コンテナグループ構成例:
┌─────────────────────────────────────────┐
│ コンテナグループ                        │
│ ├─ コンテナ1: Webアプリ (Port 80)       │
│ ├─ コンテナ2: サイドカー（ログ収集）    │
│ └─ 共有: ボリューム、ネットワーク       │
│                                         │
│ パブリックIP: 203.0.113.10              │
│ DNS名: myapp.japaneast.azurecontainer.io│
└─────────────────────────────────────────┘
```

## 3.7 試験対策のポイント

### Domain 3 重要ポイント

1. **VM可用性オプションとSLA**
   - 単一VM: 99.9%（Premium SSD使用時）
   - 可用性セット: 99.95%
   - 可用性ゾーン: 99.99%

2. **ディスクの種類と使い分け**
   - Ultra Disk: ミッションクリティカル
   - Premium SSD: 本番環境
   - Standard HDD: バックアップ

3. **App Service プランと機能**
   - Basic: カスタムドメインまで
   - Standard: 自動スケール、デプロイスロット
   - Premium: VNet統合、ゾーン冗長

4. **VMSSのオーケストレーションモード**
   - Uniform: ステートレス、同一構成
   - Flexible: ステートフル、異なる構成可

5. **ACRのSKU選択**
   - Premium: Geo複製、プライベートエンドポイント

### 試験Tips

✅ **可用性セットと可用性ゾーンは同時使用不可**
✅ **デプロイスロットはStandard以上のApp Serviceプラン**
✅ **VM拡張機能は複数インストール可能**
✅ **Ultra DiskはゾーンVMでのみ使用可能**
✅ **ACRの管理者アカウントは無効化推奨（Entra ID使用）**

## Domain 3 練習問題

### 問題1
Webアプリケーションを可用性ゾーンに展開し、99.99%のSLAを達成する必要があります。3つの可用性ゾーンにVMを配置する場合、最小で何台のVMが必要ですか？

A) 1台  
B) 2台  
C) 3台  
D) 6台

<details>
<summary>解答と解説</summary>

**正解: C) 3台**

**解説:**
99.99%のSLAを達成するには、可用性ゾーンを使用する必要があり、少なくとも2つ以上のゾーンにVMを配置する必要があります。ベストプラクティスとして、3つすべてのゾーンに配置することで、最高の可用性と耐障害性を実現します。

**可用性ゾーンのSLA:**
- 2つ以上のゾーンにVMを配置: 99.99% SLA
- 各ゾーンに1台ずつ配置することで、1つのゾーンが停止しても他のゾーンで継続稼働

**構成例:**
- ゾーン1: VM1
- ゾーン2: VM2
- ゾーン3: VM3
- ロードバランサー（ゾーン冗長）で分散

**参照:** `virtual_machines.tf` - ゾーン配置の例
</details>

### 問題2
App Serviceで新しいバージョンのアプリケーションをダウンタイムなしでデプロイしたいです。どの機能を使用すべきですか？

A) カスタムドメイン  
B) デプロイスロット  
C) 自動スケーリング  
D) VNet統合

<details>
<summary>解答と解説</summary>

**正解: B) デプロイスロット**

**解説:**
デプロイスロット機能により、新バージョンをステージング環境でテストした後、本番スロットとスワップすることで、ダウンタイムなしでデプロイできます。

**デプロイスロットのワークフロー:**
1. ステージングスロットに新バージョンをデプロイ
2. ステージング環境でテスト・検証
3. 本番スロットとステージングスロットをスワップ
4. 問題があればスワップをロールバック

**必要条件:**
- Standard、Premium、またはIsolated App Serviceプラン
- スロット数の上限はプランにより異なる（Standard: 5, Premium: 20）

**参照:** `app_service.tf` - デプロイスロット設定
</details>

### 問題3
VMのOSディスクに使用するストレージタイプを選択する必要があります。本番環境のデータベースサーバーで、高いIOPSと低遅延が求められます。どのディスクタイプが最適ですか？

A) Standard HDD  
B) Standard SSD  
C) Premium SSD  
D) Ultra Disk

<details>
<summary>解答と解説</summary>

**正解: C) Premium SSD または D) Ultra Disk**

**解説:**
本番環境のデータベースには、Premium SSD以上が推奨されます。Ultra Diskは最高性能ですが、コストも最高です。

**ディスクタイプの選択基準:**

**Premium SSD (推奨):**
- IOPS: 最大20,000
- 遅延: 一桁ミリ秒
- コスト: 中〜高
- 用途: ほとんどの本番データベース

**Ultra Disk:**
- IOPS: 最大160,000
- 遅延: サブミリ秒
- コスト: 最高
- 用途: SAP HANA等の超高性能要件

**一般的な選択:**
- 開発/テスト: Standard SSD
- 本番Web: Premium SSD
- 本番DB: Premium SSD
- ミッションクリティカルDB: Ultra Disk

**参照:** `virtual_machines.tf` - OSディスク設定
</details>

### 問題4
VMSSで自動スケーリングを構成しています。平日の営業時間（9:00-18:00）は最低5インスタンス、それ以外の時間は最低2インスタンスで運用したいです。どのタイプの自動スケーリングルールを使用すべきですか？

A) メトリックベースのスケーリングのみ  
B) スケジュールベースのスケーリングのみ  
C) メトリックベースとスケジュールベースの両方  
D) 手動スケーリング

<details>
<summary>解答と解説</summary>

**正解: C) メトリックベースとスケジュールベースの両方**

**解説:**
時間帯による要件変更にはスケジュールベース、トラフィックの変動にはメトリックベースを組み合わせます。

**自動スケーリングプロファイルの構成:**

**デフォルトプロファイル（営業時間外）:**
- 最小: 2インスタンス
- 最大: 10インスタンス
- メトリック: CPU使用率 > 70% でスケールアウト

**営業時間プロファイル:**
- 最小: 5インスタンス
- 最大: 20インスタンス
- スケジュール: 平日 9:00-18:00
- メトリック: CPU使用率 > 70% でスケールアウト

**動作:**
- 9:00になると自動的に5インスタンスに増加
- トラフィック増加時はメトリックに基づいて追加スケール
- 18:00になると2インスタンスまで減少（トラフィック次第）

**参照:** `app_service.tf` - 自動スケーリング設定例
</details>

### 問題5
Container RegistryからApp Serviceにコンテナイメージをデプロイする際、安全に認証を行う方法として最も推奨されるのはどれですか？

A) ACRの管理者アカウントを有効化してユーザー名/パスワードを使用  
B) App ServiceのマネージドIDを使用してACRにアクセス  
C) ACRのアクセスキーをApp Serviceの環境変数に保存  
D) パブリックアクセスを有効化

<details>
<summary>解答と解説</summary>

**正解: B) App ServiceのマネージドIDを使用してACRにアクセス**

**解説:**
マネージドIDを使用することで、資格情報を管理する必要がなく、最もセキュアです。

**マネージドIDによるACRアクセスの手順:**

1. **App ServiceでシステムマネージドIDを有効化**
   ```hcl
   identity {
     type = "SystemAssigned"
   }
   ```

2. **ACRにAcrPullロールを割り当て**
   ```hcl
   resource "azurerm_role_assignment" "acr_pull" {
     scope                = azurerm_container_registry.main.id
     role_definition_name = "AcrPull"
     principal_id         = azurerm_linux_web_app.main.identity[0].principal_id
   }
   ```

3. **App ServiceでACRを指定**
   - 資格情報は自動的に取得される

**セキュリティ比較:**
- マネージドID: ✓ 資格情報管理不要、最もセキュア
- 管理者アカウント: ✗ 非推奨、フルアクセス
- アクセスキー: ✗ ローテーション必要、漏洩リスク
- パブリックアクセス: ✗ 誰でもアクセス可能

**参照:** `acr.tf`, `app_service.tf`
</details>

### 問題6
本番環境のVMで計画メンテナンスが発生しても、サービスが中断されないようにする必要があります。最も適切な構成は？

A) 単一VMをPremium SSDで構成  
B) 可用性セットに2台以上のVMを配置  
C) 可用性ゾーンに1台のVMを配置  
D) 2台のVMを同じラックに配置

<details>
<summary>解答と解説</summary>

**正解: B) 可用性セットに2台以上のVMを配置**

**解説:**
可用性セットの更新ドメイン機能により、計画メンテナンス時に一度に1つの更新ドメインのみが再起動されます。

**可用性セットの更新ドメイン:**
- 計画メンテナンス時の保護機能
- 最大20の更新ドメイン
- 同時に1つのUDのみ更新
- 次のUDの更新まで30分の待機時間

**構成例:**
```
更新ドメイン 0: VM1
更新ドメイン 1: VM2
更新ドメイン 2: VM3

計画メンテナンス:
1. UD 0のVMを再起動（VM2, VM3は稼働中）
2. 30分待機
3. UD 1のVMを再起動（VM1, VM3は稼働中）
4. 30分待機
5. UD 2のVMを再起動（VM1, VM2は稼働中）
```

**他のオプション:**
- A) 単一VM: メンテナンス時にダウンタイム発生
- C) 可用性ゾーン: 計画外障害には強いが、計画メンテナンス対策には可用性セットが適切
- D) 同じラック: 障害ドメインが同じで、ラック障害時に全滅

**参照:** `virtual_machines.tf` - 可用性セット設定
</details>

---

# Domain 4: 仮想ネットワークの構成と管理 (15-20%)

## 4.1 仮想ネットワーク (VNet) の基礎

### 概念説明

Azure Virtual Network (VNet) は、Azureリソースが安全に通信するための基盤となるネットワークです。

### VNetの構成要素

```
VNet階層構造:
┌─────────────────────────────────────────────┐
│ Virtual Network (VNet)                      │
│ アドレス空間: 10.0.0.0/16                   │
│                                             │
│ ┌─────────────────────────────────────┐     │
│ │ Subnet 1: Web層                     │     │
│ │ 10.0.1.0/24 (256アドレス)           │     │
│ │ - 予約済み: 5アドレス               │     │
│ │ - 使用可能: 251アドレス             │     │
│ └─────────────────────────────────────┘     │
│                                             │
│ ┌─────────────────────────────────────┐     │
│ │ Subnet 2: アプリ層                  │     │
│ │ 10.0.2.0/24                         │     │
│ └─────────────────────────────────────┘     │
│                                             │
│ ┌─────────────────────────────────────┐     │
│ │ Subnet 3: データ層                  │     │
│ │ 10.0.3.0/24                         │     │
│ └─────────────────────────────────────┘     │
└─────────────────────────────────────────────┘
```

### 予約済みIPアドレス

各サブネットで最初の4個と最後の1個のアドレスは予約されています：

```
サブネット: 10.0.1.0/24
┌────────────────────────────────────────┐
│ 10.0.1.0   - ネットワークアドレス      │
│ 10.0.1.1   - デフォルトゲートウェイ    │
│ 10.0.1.2   - Azure DNS                 │
│ 10.0.1.3   - Azure DNS (将来用)        │
│ 10.0.1.4～10.0.1.254 - 使用可能        │
│ 10.0.1.255 - ブロードキャスト          │
└────────────────────────────────────────┘
```

### リポジトリファイル参照: `network.tf`

```hcl
# 仮想ネットワーク
resource "azurerm_virtual_network" "main" {
  name                = "vnet-prod-japaneast"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]
  
  # DNSサーバー（カスタム）
  dns_servers = ["10.0.0.4", "10.0.0.5"]
  
  tags = {
    Environment = "Production"
  }
}

# サブネット - Web層
resource "azurerm_subnet" "web" {
  name                 = "snet-web"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
  
  # サービスエンドポイント
  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.Sql",
    "Microsoft.KeyVault"
  ]
}

# サブネット - アプリ層
resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
  
  # プライベートエンドポイント専用設定
  private_endpoint_network_policies_enabled = false
}

# サブネット - データ層
resource "azurerm_subnet" "data" {
  name                 = "snet-data"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.3.0/24"]
  
  # サブネットをサービスに委任
  delegation {
    name = "delegation"
    
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }
}
```

## 4.2 ネットワークセキュリティグループ (NSG)

### 概念説明

NSGは、Azureリソースへのネットワークトラフィックをフィルタリングするセキュリティルールを含みます。

### NSGの適用先

```
NSGの適用レベル:
┌────────────────────────────────────┐
│ サブネットレベル（推奨）           │
│ ├─ サブネット全体に適用            │
│ └─ 集中管理                        │
└────────────────────────────────────┘
        ↓ 両方適用可能
┌────────────────────────────────────┐
│ NICレベル                          │
│ ├─ 個別VMに適用                    │
│ └─ きめ細かい制御                  │
└────────────────────────────────────┘
```

### セキュリティルールの処理順序

```
優先度による評価（100-4096、低い方が優先）:
┌─────────────────────────────────────────┐
│ 優先度 100: Allow HTTPS from Internet  │ ← 最初に評価
│ 優先度 200: Allow SSH from Admin VNet  │
│ 優先度 300: Deny All Inbound           │
│ 優先度 65000: AllowVNetInBound (既定)  │
│ 優先度 65001: AllowAzureLB (既定)      │
│ 優先度 65500: DenyAllInBound (既定)    │ ← 最後
└─────────────────────────────────────────┘

マッチした最初のルールが適用され、以降は評価されない
```

### デフォルトセキュリティルール

```
インバウンド:
┌──────────────────────────────────────────────┐
│ AllowVNetInBound (65000)                     │
│ - VNet内の通信を許可                          │
│                                              │
│ AllowAzureLoadBalancerInBound (65001)        │
│ - Azure Load Balancerからの通信を許可        │
│                                              │
│ DenyAllInBound (65500)                       │
│ - その他すべての受信を拒否                    │
└──────────────────────────────────────────────┘

アウトバウンド:
┌──────────────────────────────────────────────┐
│ AllowVNetOutBound (65000)                    │
│ - VNet内への通信を許可                        │
│                                              │
│ AllowInternetOutBound (65001)                │
│ - インターネットへの通信を許可                │
│                                              │
│ DenyAllOutBound (65500)                      │
│ - その他すべての送信を拒否                    │
└──────────────────────────────────────────────┘
```

### リポジトリファイル参照: `network.tf` (NSG)

```hcl
# Web層のNSG
resource "azurerm_network_security_group" "web" {
  name                = "nsg-web"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  # HTTPSを許可
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
  
  # HTTPを許可
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
  
  # 管理者VNetからのSSHを許可
  security_rule {
    name                       = "AllowSSHFromAdmin"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.1.0.0/16"  # 管理者VNet
    destination_address_prefix = "*"
  }
  
  # その他のインバウンドを拒否（明示的）
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# NSGをサブネットに関連付け
resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}

# アプリ層のNSG
resource "azurerm_network_security_group" "app" {
  name                = "nsg-app"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  # Web層からのHTTPSを許可
  security_rule {
    name                       = "AllowHTTPSFromWeb"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "10.0.1.0/24"  # Web層サブネット
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}
```

### アプリケーションセキュリティグループ (ASG)

```
ASGによる論理グルーピング:
┌─────────────────────────────────────────┐
│ ASG: WebServers                         │
│ ├─ VM1 (NIC1)                           │
│ ├─ VM2 (NIC2)                           │
│ └─ VM3 (NIC3)                           │
└─────────────────────────────────────────┘
         ↓ 許可
┌─────────────────────────────────────────┐
│ ASG: AppServers                         │
│ ├─ VM4 (NIC4)                           │
│ └─ VM5 (NIC5)                           │
└─────────────────────────────────────────┘

NSGルール例:
Source: ASG(WebServers)
Destination: ASG(AppServers)
Port: 443
Action: Allow
```

## 4.3 VNetピアリング

### 概念説明

VNetピアリングは、2つのVNetを接続し、プライベートIPアドレスを使用して通信を可能にします。

### ピアリングの種類

```
リージョン内ピアリング (VNet Peering):
┌──────────────────┐      ┌──────────────────┐
│ VNet A           │◄────►│ VNet B           │
│ Japan East       │      │ Japan East       │
│ 10.0.0.0/16      │      │ 10.1.0.0/16      │
└──────────────────┘      └──────────────────┘

グローバルVNetピアリング:
┌──────────────────┐      ┌──────────────────┐
│ VNet A           │◄────►│ VNet B           │
│ Japan East       │      │ West US          │
│ 10.0.0.0/16      │      │ 10.2.0.0/16      │
└──────────────────┘      └──────────────────┘
```

### ピアリングの特性

```
特徴:
✓ 低遅延、高帯域幅（Azureバックボーンネットワーク使用）
✓ VNet間でプライベートIP通信
✓ クロスサブスクリプション対応
✓ 非推移的（A-B、B-Cがピアリングでも、A-Cは通信不可）

制約:
✗ アドレス空間の重複不可
✗ ピアリング確立後のアドレス空間追加に制限
✗ ピアリングは双方向に設定が必要
```

### ピアリングのオプション

```
ゲートウェイトランジット:
┌────────────┐    ┌────────────┐    ┌──────────┐
│ VNet A     │◄──►│ VNet B     │◄──►│ VPN GW   │
│            │    │(GW Transit)│    │          │
└────────────┘    └────────────┘    └──────────┘
                         │
                         ↓ オンプレミス
                  ┌──────────────┐
                  │ On-Premises  │
                  └──────────────┘

VNet A は VNet B のゲートウェイを使用してオンプレミスに接続
```

### リポジトリファイル参照: `network.tf` (VNetピアリング)

```hcl
# VNet ピアリング: VNet A → VNet B
resource "azurerm_virtual_network_peering" "a_to_b" {
  name                      = "peer-vnet-a-to-vnet-b"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.vnet_a.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_b.id
  
  # トラフィック設定
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  
  # ゲートウェイトランジット（VNet Bのゲートウェイを使用）
  use_remote_gateways = true
}

# VNet ピアリング: VNet B → VNet A（双方向設定必須）
resource "azurerm_virtual_network_peering" "b_to_a" {
  name                      = "peer-vnet-b-to-vnet-a"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.vnet_b.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_a.id
  
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  
  # ゲートウェイトランジット許可（VNet Bがゲートウェイを持つ）
  allow_gateway_transit = true
}
```

## 4.4 Azure Load Balancer

### 概念説明

Azure Load Balancerは、レイヤー4（TCP/UDP）のトラフィック分散を提供します。

### Load Balancer SKU

| SKU | スケール | 可用性ゾーン | SLA | 料金 |
|-----|----------|--------------|-----|------|
| **Basic** | 最大300インスタンス | 非対応 | なし | 無料 |
| **Standard** | 最大1000インスタンス | 対応 | 99.99% | 有料 |

### Load Balancerの構成要素

```
Load Balancer構成:
┌─────────────────────────────────────────────┐
│ フロントエンドIP                            │
│ - パブリックIP: インターネット向け          │
│ - プライベートIP: 内部負荷分散              │
└─────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────┐
│ 負荷分散ルール                              │
│ - プロトコル: TCP/UDP                       │
│ - ポート: 80, 443等                         │
│ - バックエンドプール/ポートへマッピング     │
└─────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────┐
│ 正常性プローブ                              │
│ - HTTP/HTTPS/TCP                            │
│ - パス: /health                             │
│ - 間隔: 15秒、しきい値: 2                   │
└─────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────┐
│ バックエンドプール                          │
│ - VM、VMSS、または可用性セット              │
│ - NICまたはIP構成で参照                     │
└─────────────────────────────────────────────┘
```

### 分散アルゴリズム

```
5タプルハッシュ（デフォルト）:
- 送信元IP
- 送信元ポート
- 宛先IP
- 宛先ポート
- プロトコルタイプ

3タプルハッシュ（送信元IPアフィニティ）:
- 送信元IP
- 宛先IP
- プロトコルタイプ
→ 同じクライアントは常に同じバックエンドへ

2タプルハッシュ:
- 送信元IP
- 宛先IP
```

### リポジトリファイル参照: `load_balancer.tf`

```hcl
# パブリックIPアドレス
resource "azurerm_public_ip" "lb" {
  name                = "pip-lb-web"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]  # ゾーン冗長
}

# Load Balancer
resource "azurerm_lb" "main" {
  name                = "lb-web"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
  
  frontend_ip_configuration {
    name                 = "frontend"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

# バックエンドプール
resource "azurerm_lb_backend_address_pool" "main" {
  name            = "backend-pool"
  loadbalancer_id = azurerm_lb.main.id
}

# 正常性プローブ
resource "azurerm_lb_probe" "http" {
  name            = "http-probe"
  loadbalancer_id = azurerm_lb.main.id
  protocol        = "Http"
  port            = 80
  request_path    = "/health"
  interval_in_seconds = 15
  number_of_probes    = 2
}

# 負荷分散ルール
resource "azurerm_lb_rule" "http" {
  name                           = "http-rule"
  loadbalancer_id                = azurerm_lb.main.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.main.id]
  probe_id                       = azurerm_lb_probe.http.id
  
  # セッションの永続性
  load_distribution = "SourceIP"  # 送信元IPアフィニティ
  
  # アイドルタイムアウト
  idle_timeout_in_minutes = 4
  
  # フローティングIP（DSR - Direct Server Return）
  enable_floating_ip = false
}

# インバウンドNATルール（特定のVMへの直接アクセス）
resource "azurerm_lb_nat_rule" "ssh" {
  count                          = 3
  name                           = "ssh-vm-${count.index + 1}"
  resource_group_name            = azurerm_resource_group.main.name
  loadbalancer_id                = azurerm_lb.main.id
  protocol                       = "Tcp"
  frontend_port                  = 2200 + count.index
  backend_port                   = 22
  frontend_ip_configuration_name = "frontend"
}
```

### 内部Load Balancer

```hcl
# 内部Load Balancer（プライベートIPを使用）
resource "azurerm_lb" "internal" {
  name                = "lb-internal"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
  
  frontend_ip_configuration {
    name                          = "frontend"
    subnet_id                     = azurerm_subnet.app.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.2.10"
  }
}
```

## 4.5 Azure Application Gateway

### 概念説明

Application Gatewayは、レイヤー7（HTTP/HTTPS）のアプリケーション配信コントローラー（ADC）です。

### Application Gateway vs Load Balancer

```
┌───────────────────────────────────────────────────┐
│ Application Gateway (レイヤー7)                   │
│ ├─ URLパスベースルーティング                      │
│ ├─ ホストベースルーティング                       │
│ ├─ SSL/TLS終端                                    │
│ ├─ Webアプリケーションファイアウォール (WAF)      │
│ ├─ Cookie ベースのセッションアフィニティ          │
│ └─ HTTP/HTTPS のみ                                │
└───────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────┐
│ Load Balancer (レイヤー4)                         │
│ ├─ TCP/UDP トラフィック                           │
│ ├─ シンプルな負荷分散                             │
│ ├─ 高スループット、超低遅延                       │
│ ├─ インバウンド/アウトバウンドシナリオ            │
│ └─ すべてのプロトコル                             │
└───────────────────────────────────────────────────┘
```

### Application Gateway SKU

| SKU | WAF | 自動スケーリング | 可用性ゾーン |
|-----|-----|------------------|--------------|
| **Standard_v2** | ✗ | ✓ | ✓ |
| **WAF_v2** | ✓ | ✓ | ✓ |

### URLパスベースルーティング

```
Application Gateway ルーティング例:
https://example.com/images/*    → バックエンドプール: Images
https://example.com/video/*     → バックエンドプール: Video
https://example.com/api/*       → バックエンドプール: API
https://example.com/*           → バックエンドプール: Default

マルチサイトルーティング:
https://www.contoso.com/*       → バックエンドプール: Contoso
https://www.fabrikam.com/*      → バックエンドプール: Fabrikam
```

## 4.6 Azure DNS とプライベートDNS

### 概念説明

Azure DNSは、Azureインフラストラクチャを使用した名前解決を提供します。

### Azure DNSの種類

```
┌────────────────────────────────────────────┐
│ Azure DNS (パブリック)                     │
│ ├─ インターネット向けドメイン              │
│ ├─ DNSレコード管理                         │
│ └─ エニーキャストネットワーク              │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ Azure Private DNS Zone                     │
│ ├─ VNet内の名前解決                        │
│ ├─ VNetリンクで接続                        │
│ ├─ 自動登録（VM名の自動DNS登録）           │
│ └─ プライベートエンドポイントの名前解決    │
└────────────────────────────────────────────┘
```

### サポートされるDNSレコードタイプ

- **A**: IPv4アドレス
- **AAAA**: IPv6アドレス
- **CNAME**: 正規名（エイリアス）
- **MX**: メール交換
- **TXT**: テキスト
- **SRV**: サービス
- **PTR**: ポインター（逆引き）
- **NS**: ネームサーバー
- **SOA**: 権限の開始

### リポジトリファイル参照: `network.tf` (Private DNS)

```hcl
# Private DNS Zone
resource "azurerm_private_dns_zone" "main" {
  name                = "internal.contoso.com"
  resource_group_name = azurerm_resource_group.main.name
}

# VNetリンク
resource "azurerm_private_dns_zone_virtual_network_link" "main" {
  name                  = "vnet-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.main.name
  virtual_network_id    = azurerm_virtual_network.main.id
  
  # VM作成時に自動的にDNSレコード登録
  registration_enabled = true
}

# Aレコード
resource "azurerm_private_dns_a_record" "app" {
  name                = "app"
  zone_name           = azurerm_private_dns_zone.main.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  records             = ["10.0.2.10"]
}

# Private Endpoint用 DNS Zone（Blob Storage例）
resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "blob-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.main.id
}
```

## 4.7 サービスエンドポイントとプライベートエンドポイント

### 概念説明

サービスエンドポイントとプライベートエンドポイントは、Azureサービスへの安全なアクセスを提供します。

### サービスエンドポイント vs プライベートエンドポイント

```
サービスエンドポイント:
┌──────────────────────────────────────────┐
│ VNet                                     │
│ ┌────────────┐                           │
│ │ VM         │                           │
│ │ 10.0.1.4   │                           │
│ └──────┬─────┘                           │
│        │ サービスエンドポイント          │
│        ↓ (Azureバックボーン経由)         │
└────────┼─────────────────────────────────┘
         │
         ↓ パブリックIPアドレス使用
┌────────┴─────────────────────────────────┐
│ Storage Account                          │
│ - mystorageaccount.blob.core.windows.net │
│ - ファイアウォールでVNet許可             │
└──────────────────────────────────────────┘

プライベートエンドポイント:
┌──────────────────────────────────────────┐
│ VNet                                     │
│ ┌────────────┐  ┌──────────────────┐    │
│ │ VM         │  │ Private Endpoint │    │
│ │ 10.0.1.4   │──│ 10.0.2.5         │    │
│ └────────────┘  └──────────────────┘    │
│                  (プライベートIP)        │
└──────────────────────────────────────────┘
         │ Private Link
         ↓
┌────────┴─────────────────────────────────┐
│ Storage Account                          │
│ - プライベートIPでアクセス               │
│ - パブリックアクセス無効化可能           │
└──────────────────────────────────────────┘
```

### 比較表

| 特徴 | サービスエンドポイント | プライベートエンドポイント |
|------|------------------------|----------------------------|
| **IPアドレス** | パブリックIP使用 | プライベートIP使用 |
| **コスト** | 無料 | 有料 |
| **DNS** | 変更不要 | Private DNS必要 |
| **セキュリティ** | ファイアウォールルール | VNet内に配置 |
| **クロスリージョン** | 非対応 | 対応 |
| **オンプレミス** | 非対応 | 対応（VPN/ExpressRoute経由）|

## 4.8 Azure Front Door

### 概念説明

Azure Front Doorは、グローバルなHTTP/HTTPSアプリケーション配信ネットワーク（ADN）です。

### Front Doorの主要機能

```
Front Door機能:
┌────────────────────────────────────────────┐
│ グローバル負荷分散                         │
│ ├─ 複数リージョンのバックエンド            │
│ ├─ 自動フェイルオーバー                    │
│ └─ 最も近いエンドポイントへルーティング    │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ SSL/TLS オフロード                         │
│ ├─ カスタムドメイン                        │
│ ├─ マネージド証明書                        │
│ └─ エンドツーエンドSSL                     │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ WAF (Web Application Firewall)             │
│ ├─ OWASP Top 10対策                        │
│ ├─ カスタムルール                          │
│ ├─ ボット保護                              │
│ └─ DDoS保護                                │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ URLベースルーティング                      │
│ ├─ パスベース                              │
│ ├─ ホストベース                            │
│ └─ URLリライト/リダイレクト                │
└────────────────────────────────────────────┘
```

### リポジトリファイル参照: `frontdoor.tf`

```hcl
# Azure Front Door
resource "azurerm_cdn_frontdoor_profile" "main" {
  name                = "fd-myapp"
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Premium_AzureFrontDoor"  # WAF対応
}

# フロントエンドエンドポイント
resource "azurerm_cdn_frontdoor_endpoint" "main" {
  name                     = "myapp"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
}

# オリジングループ
resource "azurerm_cdn_frontdoor_origin_group" "main" {
  name                     = "origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
  
  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }
  
  health_probe {
    path                = "/health"
    request_type        = "HEAD"
    protocol            = "Https"
    interval_in_seconds = 30
  }
}

# オリジン（Japan East）
resource "azurerm_cdn_frontdoor_origin" "japaneast" {
  name                          = "origin-japaneast"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.main.id
  
  enabled                        = true
  host_name                      = azurerm_linux_web_app.japaneast.default_hostname
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = azurerm_linux_web_app.japaneast.default_hostname
  priority                       = 1
  weight                         = 1000
  
  certificate_name_check_enabled = true
}

# オリジン（West US）- フェイルオーバー用
resource "azurerm_cdn_frontdoor_origin" "westus" {
  name                          = "origin-westus"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.main.id
  
  enabled                        = true
  host_name                      = azurerm_linux_web_app.westus.default_hostname
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = azurerm_linux_web_app.westus.default_hostname
  priority                       = 2
  weight                         = 1000
  
  certificate_name_check_enabled = true
}

# WAF ポリシー
resource "azurerm_cdn_frontdoor_firewall_policy" "main" {
  name                = "wafpolicy"
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Premium_AzureFrontDoor"
  enabled             = true
  mode                = "Prevention"
  
  # マネージドルール（OWASP）
  managed_rule {
    type    = "Microsoft_DefaultRuleSet"
    version = "2.1"
    action  = "Block"
  }
  
  # マネージドルール（ボット保護）
  managed_rule {
    type    = "Microsoft_BotManagerRuleSet"
    version = "1.0"
    action  = "Block"
  }
  
  # カスタムルール（Geo-Filtering）
  custom_rule {
    name                           = "AllowJapanOnly"
    enabled                        = true
    priority                       = 1
    rate_limit_duration_in_minutes = 1
    rate_limit_threshold           = 10
    type                           = "MatchRule"
    action                         = "Block"
    
    match_condition {
      match_variable     = "RemoteAddr"
      operator           = "GeoMatch"
      negation_condition = true
      match_values       = ["JP"]
    }
  }
}
```

## 4.9 試験対策のポイント

### Domain 4 重要ポイント

1. **NSGのデフォルトルールと優先度**
   - 優先度は100-4096（低い方が優先）
   - デフォルトルールは65000番台

2. **VNetピアリングの特性**
   - 非推移的（A-B、B-Cでも A-C は通信不可）
   - 双方向に設定必要
   - アドレス空間重複不可

3. **Load Balancer vs Application Gateway**
   - LB: レイヤー4（TCP/UDP）
   - AppGW: レイヤー7（HTTP/HTTPS）、WAF対応

4. **サービスエンドポイント vs プライベートエンドポイント**
   - サービスEP: 無料、パブリックIP使用、VNet内のみ
   - プライベートEP: 有料、プライベートIP、オンプレミスからも可

5. **Front Doorの用途**
   - グローバル負荷分散
   - WAF
   - SSL/TLS オフロード

### 試験Tips

✅ **Standard Load Balancerは可用性ゾーン対応、BasicはなしSLA**
✅ **NSGはステートフル（戻りトラフィックは自動許可）**
✅ **各サブネットで5つのIPアドレスが予約済み**
✅ **プライベートエンドポイントはPrivate DNS Zone必要**
✅ **VNetピアリングのゲートウェイトランジットは双方向設定必要**

## Domain 4 練習問題

### 問題1
WebサーバーのサブネットにNSGを適用しています。インターネットからHTTPS（ポート443）を許可し、その他すべてのインバウンド通信を拒否したいです。最小限のルールで実現する方法は？

A) 優先度100でHTTPSを許可するルールのみ作成  
B) 優先度100でHTTPSを許可、優先度200ですべて拒否  
C) 優先度100でHTTPSを許可、デフォルトルールで拒否  
D) すべてのポートを個別に拒否するルールを作成

<details>
<summary>解答と解説</summary>

**正解: A) 優先度100でHTTPSを許可するルールのみ作成**

**解説:**
NSGにはデフォルトで「DenyAllInBound」ルール（優先度65500）があり、明示的に許可されていないトラフィックはすべて拒否されます。

**ルール評価の流れ:**
1. 優先度100: Allow HTTPS（マッチ → 許可）
2. 優先度65000: AllowVNetInBound（VNet内通信は許可）
3. 優先度65001: AllowAzureLB（Azure LB からの通信許可）
4. 優先度65500: DenyAllInBound（その他すべて拒否）

**ベストプラクティス:**
- 必要な許可ルールのみを明示的に作成
- デフォルトルールを活用
- 不要な拒否ルールは作成しない

**参照:** `network.tf` - NSG設定
</details>

### 問題2
東日本リージョンのVNet A（10.0.0.0/16）と西日本リージョンのVNet B（10.1.0.0/16）を接続し、VNet A のVMからVNet B のVMへプライベートIPで通信できるようにしたいです。どの機能を使用すべきですか？

A) VPNゲートウェイ  
B) ExpressRoute  
C) グローバルVNetピアリング  
D) ルートテーブル

<details>
<summary>解答と解説</summary>

**正解: C) グローバルVNetピアリング**

**解説:**
異なるリージョン間のVNetを接続するには、グローバルVNetピアリングを使用します。

**VNetピアリングの特徴:**
- リージョン内ピアリング: 同一リージョン内のVNet接続
- グローバルVNetピアリング: 異なるリージョンのVNet接続
- Azureバックボーンネットワーク使用（インターネット経由ではない）
- 低遅延、高帯域幅
- プライベートIPアドレスで通信

**他のオプションとの比較:**
- VPNゲートウェイ: VNet間接続も可能だが、ピアリングより複雑で遅い
- ExpressRoute: オンプレミス接続用（VNet間にも使用可能だが高コスト）
- ルートテーブル: ルーティングのみ、接続は確立しない

**設定手順:**
1. VNet A → VNet B のピアリング作成
2. VNet B → VNet A のピアリング作成（双方向必須）

**参照:** `network.tf` - VNetピアリング設定
</details>

### 問題3
WebアプリケーションにWAF保護を追加し、SQLインジェクションやXSS攻撃から保護したいです。どのAzureサービスを使用すべきですか？

A) Azure Load Balancer  
B) Network Security Group (NSG)  
C) Application Gateway with WAF  
D) Azure Firewall

<details>
<summary>解答と解説</summary>

**正解: C) Application Gateway with WAF**

**解説:**
Application GatewayのWAF SKUは、OWASP Top 10の脆弱性から保護します。

**WAFの保護機能:**
- SQLインジェクション
- クロスサイトスクリプティング（XSS）
- コマンドインジェクション
- HTTPリクエストスマグリング
- HTTPレスポンススプリッティング
- リモートファイルインクルージョン
- ボット攻撃

**WAFモード:**
- **検出モード**: 脅威を検出してログ記録（ブロックしない）
- **防止モード**: 脅威を検出してブロック

**マネージドルールセット:**
- OWASP Core Rule Set (CRS) 3.2, 3.1, 3.0
- Microsoft Bot Manager Rule Set

**他のオプション:**
- Load Balancer: レイヤー4、WAF機能なし
- NSG: レイヤー3/4、アプリケーション層の保護不可
- Azure Firewall: ネットワークレベルの保護、WAFではない

**参照:** `frontdoor.tf` - WAFポリシー設定（Front DoorもWAF対応）
</details>

### 問題4
ストレージアカウントへのアクセスを特定のVNetからのみ許可し、パブリックインターネットからのアクセスを完全にブロックしたいです。オンプレミスネットワークからもVPN経由でアクセスできる必要があります。どの機能を使用すべきですか？

A) サービスエンドポイント  
B) プライベートエンドポイント  
C) NSG  
D) ストレージファイアウォールのみ

<details>
<summary>解答と解説</summary>

**正解: B) プライベートエンドポイント**

**解説:**
プライベートエンドポイントを使用すると、VNet内にプライベートIPアドレスが割り当てられ、オンプレミスからもVPN/ExpressRoute経由でアクセス可能です。

**プライベートエンドポイントの利点:**
- VNet内にプライベートIP割り当て
- パブリックアクセス完全無効化可能
- オンプレミスからアクセス可能（VPN/ExpressRoute経由）
- Private DNS Zone統合で名前解決も容易
- クロスリージョン対応

**サービスエンドポイントとの比較:**
| 要件 | サービスEP | プライベートEP |
|------|------------|----------------|
| VNet内アクセス | ✓ | ✓ |
| オンプレミスアクセス | ✗ | ✓（VPN/ER経由）|
| パブリックIP | 使用 | 不使用 |
| コスト | 無料 | 有料 |

**構成例:**
```
オンプレミス
    ↓ VPN Gateway
VNet (10.0.0.0/16)
    ↓ Private Subnet (10.0.1.0/24)
Private Endpoint (10.0.1.5)
    ↓ Private Link
Storage Account
```

**参照:** `network.tf` - プライベートエンドポイント設定
</details>

### 問題5
3台のWebサーバーVMにトラフィックを分散したいです。各VMの正常性を監視し、異常があるVMにはトラフィックを送信しないようにする必要があります。レイヤー4での負荷分散が要件です。どのリソースを構成する必要がありますか？（2つ選択）

A) Application Gateway  
B) Load Balancer  
C) 正常性プローブ  
D) NSG  
E) Traffic Manager

<details>
<summary>解答と解説</summary>

**正解: B) Load Balancer および C) 正常性プローブ**

**解説:**
レイヤー4の負荷分散にはLoad Balancerを使用し、正常性プローブで各VMの状態を監視します。

**Load Balancerの構成要素:**

1. **フロントエンドIP**: クライアントからのアクセスポイント
2. **バックエンドプール**: 負荷分散先のVM群
3. **正常性プローブ**: VMの正常性チェック
   - プロトコル: HTTP, HTTPS, TCP
   - パス: /health（HTTP/HTTPS）
   - 間隔: 15秒（デフォルト）
   - しきい値: 2回失敗で異常判定
4. **負荷分散ルール**: フロントエンドとバックエンドのマッピング

**正常性プローブの動作:**
```
プローブ送信（15秒ごと）
    ↓
VM1: 200 OK → 正常（トラフィック送信）
VM2: 500 Error → 異常カウント+1
VM3: タイムアウト → 異常カウント+1
    ↓
VM2: 2回連続失敗 → バックエンドプールから除外
```

**他のオプション:**
- Application Gateway: レイヤー7（要件に不一致）
- NSG: セキュリティルール（負荷分散ではない）
- Traffic Manager: DNS ベースの負荷分散（レイヤー7）

**参照:** `load_balancer.tf` - 正常性プローブとルール設定
</details>

---

# Domain 5: Azureリソースの監視とバックアップ (10-15%)

## 5.1 Azure Monitor の基礎

### 概念説明

Azure Monitorは、アプリケーションとインフラストラクチャの監視、診断、分析のための包括的なソリューションです。

### Azure Monitor のデータ型

```
Azure Monitor データフロー:
┌─────────────────────────────────────────────┐
│ データソース                                │
├─────────────────────────────────────────────┤
│ - アプリケーション                          │
│ - OS（ゲストOS）                            │
│ - Azure リソース                            │
│ - サブスクリプション                        │
│ - テナント                                  │
└──────────┬──────────────────────────────────┘
           │
           ↓
┌──────────┴──────────────────────────────────┐
│ データプラットフォーム                      │
├─────────────────────────────────────────────┤
│ メトリック             │ ログ               │
│ - 数値データ           │ - テキストデータ    │
│ - 時系列DB             │ - Log Analytics     │
│ - 1分間隔              │ - 構造化/非構造化   │
│ - 93日保持             │ - KQLクエリ         │
└──────────┬──────────────┬───────────────────┘
           │              │
           ↓              ↓
┌──────────┴─────┐  ┌────┴──────────────────┐
│ メトリック分析  │  │ Log Analytics        │
│ アラート        │  │ Workbooks            │
│ 自動スケール    │  │ Insights             │
└────────────────┘  └──────────────────────┘
```

### メトリックとログの違い

| 特徴 | メトリック | ログ |
|------|------------|------|
| **データ型** | 数値 | テキスト/構造化データ |
| **保持期間** | 93日 | カスタマイズ可能（最大730日）|
| **レイテンシ** | ほぼリアルタイム | 数分の遅延 |
| **用途** | トレンド分析、アラート | 詳細な診断、分析 |
| **クエリ** | メトリックエクスプローラー | KQL (Kusto Query Language) |

## 5.2 Log Analytics ワークスペース

### 概念説明

Log Analytics ワークスペースは、ログデータの収集、分析、可視化のための中央リポジトリです。

### ワークスペース設計

```
ワークスペース設計パターン:
┌────────────────────────────────────────────┐
│ 単一ワークスペース（推奨）                 │
│ ├─ シンプルな管理                          │
│ ├─ クロスリソース分析容易                  │
│ ├─ コスト最適化                            │
│ └─ RBACで柔軟なアクセス制御                │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ 環境別ワークスペース                       │
│ ├─ 本番 / 非本番の分離                     │
│ ├─ コンプライアンス要件                    │
│ └─ データの完全な分離                      │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ リージョン別ワークスペース                 │
│ ├─ データレジデンシー要件                  │
│ ├─ ネットワークレイテンシ削減              │
│ └─ 大規模環境                              │
└────────────────────────────────────────────┘
```

### データ保持とコスト

```
価格モデル:
┌────────────────────────────────────────────┐
│ 従量課金制                                 │
│ - $2.76/GB (最初の5GB/日は無料)           │
│ - 使用量に応じた課金                       │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ コミットメント層                           │
│ - 100GB/日: 約25%割引                     │
│ - 200GB/日以上: さらに割引                │
│ - 31日間のコミットメント                  │
└────────────────────────────────────────────┘

データ保持:
- デフォルト: 30日（無料）
- 最大: 730日（2年）
- 31日以降: $0.12/GB/月
```

### リポジトリファイル参照: `monitoring.tf`

```hcl
# Log Analytics ワークスペース
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-prod"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  
  # 日次上限（コスト管理）
  daily_quota_gb = 10
  
  tags = {
    Environment = "Production"
  }
}

# データ収集ルール（DCR）
resource "azurerm_monitor_data_collection_rule" "main" {
  name                = "dcr-vminsights"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.main.id
      name                  = "destination-log"
    }
  }
  
  data_flow {
    streams      = ["Microsoft-InsightsMetrics", "Microsoft-Syslog", "Microsoft-Perf"]
    destinations = ["destination-log"]
  }
  
  # パフォーマンスカウンター
  data_sources {
    performance_counter {
      streams                       = ["Microsoft-Perf"]
      sampling_frequency_in_seconds = 60
      counter_specifiers            = [
        "\\Processor(_Total)\\% Processor Time",
        "\\Memory\\Available MBytes",
        "\\Network Interface(*)\\Bytes Total/sec"
      ]
      name = "perfCounters"
    }
  }
  
  # Syslog（Linux）
  data_sources {
    syslog {
      facility_names = ["auth", "authpriv", "cron", "daemon", "kern", "syslog"]
      log_levels     = ["Error", "Warning", "Info"]
      name           = "syslog"
      streams        = ["Microsoft-Syslog"]
    }
  }
}
```

## 5.3 Application Insights

### 概念説明

Application Insightsは、Webアプリケーションのパフォーマンス管理（APM）と監視のためのサービスです。

### Application Insights の機能

```
Application Insights 機能:
┌────────────────────────────────────────────┐
│ 自動計装                                   │
│ ├─ リクエスト追跡                          │
│ ├─ 依存関係追跡（DB、HTTP等）              │
│ ├─ 例外検出                                │
│ └─ パフォーマンスカウンター                │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ アプリケーションマップ                     │
│ ├─ コンポーネント間の依存関係可視化        │
│ ├─ 失敗率の表示                            │
│ └─ パフォーマンスボトルネックの特定        │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ ライブメトリックストリーム                 │
│ ├─ リアルタイムメトリック（1秒未満）       │
│ ├─ リクエスト率、失敗率                    │
│ └─ プロセスメトリック                      │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ 可用性テスト                               │
│ ├─ URLピングテスト                         │
│ ├─ 標準テスト（複数手順）                  │
│ └─ カスタムTrackAvailabilityテスト         │
└────────────────────────────────────────────┘
```

### サポートされるプラットフォーム

- **.NET / .NET Core**
- **Java**
- **Node.js**
- **Python**
- **JavaScript（クライアント側）**

### リポジトリファイル参照: `monitoring.tf` (Application Insights)

```hcl
# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "appi-myapp-prod"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"
  
  # Log Analytics ワークスペースベース（推奨）
  workspace_id = azurerm_log_analytics_workspace.main.id
  
  # サンプリング率（コスト削減）
  sampling_percentage = 100  # 本番環境では調整
  
  # 日次上限（コスト管理）
  daily_data_cap_in_gb = 5
  
  tags = {
    Environment = "Production"
  }
}

# 可用性テスト（URLピング）
resource "azurerm_application_insights_standard_web_test" "main" {
  name                    = "ping-test-homepage"
  location                = azurerm_resource_group.main.location
  resource_group_name     = azurerm_resource_group.main.name
  application_insights_id = azurerm_application_insights.main.id
  
  geo_locations = [
    "apac-jp-kaw-edge",  # 日本
    "us-ca-sjc-azr",     # 米国
    "emea-nl-ams-azr"    # 欧州
  ]
  
  frequency               = 300  # 5分ごと
  timeout                 = 30
  enabled                 = true
  
  request {
    url = "https://example.com"
  }
  
  validation_rules {
    expected_status_code = 200
    ssl_check_enabled    = true
    ssl_cert_remaining_lifetime_check = 7
  }
}
```

### KQL（Kusto Query Language）の基本

```kql
// リクエストの失敗を検索
requests
| where success == false
| where timestamp > ago(1h)
| summarize count() by resultCode, operation_Name
| order by count_ desc

// 応答時間が遅いリクエスト
requests
| where timestamp > ago(24h)
| where duration > 3000  // 3秒以上
| project timestamp, name, url, duration, resultCode
| order by duration desc
| take 100

// 例外の集計
exceptions
| where timestamp > ago(7d)
| summarize count() by type, outerMessage
| order by count_ desc

// 依存関係の失敗
dependencies
| where success == false
| where timestamp > ago(1h)
| summarize count() by target, type
```

## 5.4 アラートとアクショングループ

### 概念説明

Azure Monitorアラートは、メトリックやログの条件に基づいて通知やアクションを実行します。

### アラートの種類

```
アラートタイプ:
┌────────────────────────────────────────────┐
│ メトリックアラート                         │
│ ├─ 数値ベースの条件                        │
│ ├─ ほぼリアルタイム（1分）                 │
│ ├─ 静的しきい値                            │
│ └─ 動的しきい値（機械学習）                │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ ログアラート                               │
│ ├─ KQLクエリベース                         │
│ ├─ レイテンシ: 数分                        │
│ ├─ 複雑な条件                              │
│ └─ 複数リソースのクエリ可能                │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ アクティビティログアラート                 │
│ ├─ リソース操作の監視                      │
│ ├─ サービス正常性                          │
│ └─ 管理操作の追跡                          │
└────────────────────────────────────────────┘
```

### アラートの状態

```
アラートライフサイクル:
New (新規)
  ↓ 条件が満たされる
Acknowledged (確認済み)
  ↓ 手動またはアクション
Closed (クローズ)

または

New
  ↓ 条件が解決
Resolved (解決済み)
  ↓ 自動クローズ
Closed
```

### リポジトリファイル参照: `monitoring.tf` (アラート)

```hcl
# アクショングループ
resource "azurerm_monitor_action_group" "main" {
  name                = "ag-prod-alerts"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "prodAlert"
  
  # メール通知
  email_receiver {
    name          = "send-to-admin"
    email_address = "admin@example.com"
  }
  
  # SMS通知
  sms_receiver {
    name         = "send-sms"
    country_code = "81"
    phone_number = "9012345678"
  }
  
  # Webhook
  webhook_receiver {
    name        = "call-webhook"
    service_uri = "https://example.com/webhook"
  }
  
  # Azure Function
  azure_function_receiver {
    name                     = "trigger-function"
    function_app_resource_id = azurerm_linux_function_app.main.id
    function_name            = "AlertHandler"
    http_trigger_url         = "https://myfunction.azurewebsites.net/api/AlertHandler"
  }
}

# メトリックアラート - CPU使用率
resource "azurerm_monitor_metric_alert" "cpu" {
  name                = "alert-high-cpu"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_linux_virtual_machine.main.id]
  description         = "CPU使用率が80%を超えています"
  
  severity            = 2  # 0=Critical, 1=Error, 2=Warning, 3=Informational, 4=Verbose
  frequency           = "PT1M"  # 評価頻度: 1分
  window_size         = "PT5M"  # 評価期間: 5分
  
  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }
  
  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# メトリックアラート - 動的しきい値
resource "azurerm_monitor_metric_alert" "dynamic" {
  name                = "alert-response-time-anomaly"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_application_insights.main.id]
  description         = "応答時間の異常を検出"
  
  severity    = 2
  frequency   = "PT1M"
  window_size = "PT5M"
  
  dynamic_criteria {
    metric_namespace  = "Microsoft.Insights/components"
    metric_name       = "requests/duration"
    aggregation       = "Average"
    operator          = "GreaterThan"
    alert_sensitivity = "Medium"  # Low, Medium, High
    
    # 過去のデータから学習
    evaluation_total_count   = 4
    evaluation_failure_count = 3
  }
  
  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# ログアラート
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "errors" {
  name                = "alert-app-errors"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  scopes              = [azurerm_application_insights.main.id]
  severity            = 1
  evaluation_frequency = "PT5M"
  window_duration      = "PT5M"
  
  criteria {
    query = <<-QUERY
      exceptions
      | where timestamp > ago(5m)
      | summarize count() by type
      | where count_ > 5
    QUERY
    
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"
    
    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }
  
  action {
    action_groups = [azurerm_monitor_action_group.main.id]
  }
}

# アクティビティログアラート
resource "azurerm_monitor_activity_log_alert" "vm_delete" {
  name                = "alert-vm-deletion"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_resource_group.main.id]
  description         = "仮想マシンが削除されました"
  
  criteria {
    category       = "Administrative"
    operation_name = "Microsoft.Compute/virtualMachines/delete"
    level          = "Warning"
  }
  
  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}
```

## 5.5 Azure Backup

### 概念説明

Azure Backupは、データを保護し、復旧を簡単にするクラウドベースのバックアップソリューションです。

### バックアップ対象

```
サポートされるワークロード:
┌────────────────────────────────────────────┐
│ Azure VM                                   │
│ ├─ Windows / Linux                         │
│ ├─ アプリケーション整合性                  │
│ └─ ファイルレベル復元                      │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ Azure Files                                │
│ ├─ ファイル共有スナップショット            │
│ ├─ 即座の復元                              │
│ └─ ファイル/フォルダレベル復元             │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ SQL Server / SAP HANA in Azure VM          │
│ ├─ トランザクション整合性                  │
│ ├─ ポイントインタイムリストア              │
│ └─ 15分間隔のログバックアップ              │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ オンプレミス                               │
│ ├─ MARSエージェント（ファイル/フォルダ）   │
│ ├─ Azure Backup Server                     │
│ └─ DPM (Data Protection Manager)           │
└────────────────────────────────────────────┘
```

### バックアップポリシーの構成要素

```
バックアップポリシー:
┌────────────────────────────────────────────┐
│ スケジュール                               │
│ - 頻度: 毎日 / 毎週                        │
│ - 時刻: 22:00 等                           │
└────────────────────────────────────────────┘
        ↓
┌────────────────────────────────────────────┐
│ 保持期間                                   │
│ - 日次: 30日                               │
│ - 週次: 12週                               │
│ - 月次: 12ヶ月                             │
│ - 年次: 10年                               │
└────────────────────────────────────────────┘
        ↓
┌────────────────────────────────────────────┐
│ インスタント復元                           │
│ - スナップショット保持: 2-5日              │
│ - 高速復元                                 │
└────────────────────────────────────────────┘
```

### リポジトリファイル参照: `disaster_recovery.tf`

```hcl
# Recovery Services Vault
resource "azurerm_recovery_services_vault" "main" {
  name                = "rsv-prod"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
  
  # 論理削除（誤削除保護）
  soft_delete_enabled = true
  
  # ストレージレプリケーション
  storage_mode_type = "GeoRedundant"  # LocallyRedundant または GeoRedundant
  
  # クロスリージョンリストア
  cross_region_restore_enabled = true
}

# VM バックアップポリシー
resource "azurerm_backup_policy_vm" "daily" {
  name                = "policy-vm-daily"
  resource_group_name = azurerm_resource_group.main.name
  recovery_vault_name = azurerm_recovery_services_vault.main.name
  
  # タイムゾーン
  timezone = "Tokyo Standard Time"
  
  # バックアップスケジュール
  backup {
    frequency = "Daily"
    time      = "23:00"
  }
  
  # 保持期間 - 日次
  retention_daily {
    count = 30
  }
  
  # 保持期間 - 週次
  retention_weekly {
    count    = 12
    weekdays = ["Sunday"]
  }
  
  # 保持期間 - 月次
  retention_monthly {
    count    = 12
    weekdays = ["Sunday"]
    weeks    = ["First"]
  }
  
  # 保持期間 - 年次
  retention_yearly {
    count    = 10
    weekdays = ["Sunday"]
    weeks    = ["First"]
    months   = ["January"]
  }
  
  # インスタント復元スナップショット
  instant_restore_retention_days = 2
}

# VMをバックアップに追加
resource "azurerm_backup_protected_vm" "main" {
  resource_group_name = azurerm_resource_group.main.name
  recovery_vault_name = azurerm_recovery_services_vault.main.name
  source_vm_id        = azurerm_linux_virtual_machine.main.id
  backup_policy_id    = azurerm_backup_policy_vm.daily.id
}

# Azure Files バックアップポリシー
resource "azurerm_backup_policy_file_share" "daily" {
  name                = "policy-files-daily"
  resource_group_name = azurerm_resource_group.main.name
  recovery_vault_name = azurerm_recovery_services_vault.main.name
  
  timezone = "Tokyo Standard Time"
  
  backup {
    frequency = "Daily"
    time      = "23:00"
  }
  
  retention_daily {
    count = 30
  }
}

# Azure Files バックアップ
resource "azurerm_backup_container_storage_account" "main" {
  resource_group_name = azurerm_resource_group.main.name
  recovery_vault_name = azurerm_recovery_services_vault.main.name
  storage_account_id  = azurerm_storage_account.main.id
}

resource "azurerm_backup_protected_file_share" "main" {
  resource_group_name       = azurerm_resource_group.main.name
  recovery_vault_name       = azurerm_recovery_services_vault.main.name
  source_storage_account_id = azurerm_backup_container_storage_account.main.storage_account_id
  source_file_share_name    = azurerm_storage_share.files.name
  backup_policy_id          = azurerm_backup_policy_file_share.daily.id
}
```

### バックアップの種類

```
VMバックアップの種類:
┌────────────────────────────────────────────┐
│ 完全バックアップ                           │
│ - 最初のバックアップ                       │
│ - すべてのデータ                           │
└────────────────────────────────────────────┘
        ↓
┌────────────────────────────────────────────┐
│ 増分バックアップ                           │
│ - 前回のバックアップ以降の変更のみ         │
│ - ストレージコスト削減                     │
│ - 転送データ量削減                         │
└────────────────────────────────────────────┘

整合性レベル:
┌────────────────────────────────────────────┐
│ アプリケーション整合性                     │
│ ├─ VSS (Windows) / pre/post スクリプト    │
│ ├─ アプリケーション状態を保持              │
│ └─ 推奨                                    │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ ファイルシステム整合性                     │
│ ├─ VSSが失敗した場合                       │
│ └─ ファイルシステムレベルの整合性          │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ クラッシュ整合性                           │
│ ├─ バックアップ中にVMシャットダウン        │
│ └─ 最小限の整合性保証                      │
└────────────────────────────────────────────┘
```

## 5.6 Azure Site Recovery (ASR)

### 概念説明

Azure Site Recoveryは、障害時のビジネス継続性を確保する災害復旧（DR）ソリューションです。

### サポートされるシナリオ

```
レプリケーションシナリオ:
┌────────────────────────────────────────────┐
│ Azure VM → Azure（別リージョン）           │
│ - リージョン障害対策                       │
│ - RPO: 数分                                │
│ - RTO: 数時間                              │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ オンプレミス VM → Azure                    │
│ - VMware                                   │
│ - Hyper-V                                  │
│ - 物理サーバー                             │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ オンプレミス → オンプレミス                │
│ - Hyper-V (SCVMM使用)                      │
│ - セカンダリデータセンター                 │
└────────────────────────────────────────────┘
```

### 復旧計画

```
復旧計画の構成:
┌────────────────────────────────────────────┐
│ グループ1: データベース層                  │
│ ├─ SQL Server VM                           │
│ └─ 起動順序: 1                             │
└────────────────────────────────────────────┘
        ↓ 依存関係
┌────────────────────────────────────────────┐
│ グループ2: アプリケーション層              │
│ ├─ Web/App Server VMs                      │
│ └─ 起動順序: 2                             │
└────────────────────────────────────────────┘
        ↓
┌────────────────────────────────────────────┐
│ グループ3: フロントエンド層                │
│ ├─ Load Balancer設定                       │
│ └─ 起動順序: 3                             │
└────────────────────────────────────────────┘

自動化:
- フェイルオーバー前スクリプト
- フェイルオーバー後スクリプト
- Azure Automation Runbook
- 手動アクション
```

### リポジトリファイル参照: `disaster_recovery.tf` (ASR)

```hcl
# セカンダリリージョンのリソースグループ
resource "azurerm_resource_group" "dr" {
  name     = "rg-prod-dr"
  location = "japanwest"  # DR用リージョン
}

# DR用 Recovery Services Vault
resource "azurerm_recovery_services_vault" "dr" {
  name                = "rsv-dr"
  location            = azurerm_resource_group.dr.location
  resource_group_name = azurerm_resource_group.dr.name
  sku                 = "Standard"
}

# レプリケーションファブリック（ソース）
resource "azurerm_site_recovery_fabric" "primary" {
  name                = "fabric-primary"
  resource_group_name = azurerm_resource_group.main.name
  recovery_vault_name = azurerm_recovery_services_vault.dr.name
  location            = azurerm_resource_group.main.location
}

# レプリケーションファブリック（ターゲット）
resource "azurerm_site_recovery_fabric" "secondary" {
  name                = "fabric-secondary"
  resource_group_name = azurerm_resource_group.dr.name
  recovery_vault_name = azurerm_recovery_services_vault.dr.name
  location            = azurerm_resource_group.dr.location
}

# レプリケーションポリシー
resource "azurerm_site_recovery_replication_policy" "main" {
  name                                                 = "policy-24-hour"
  resource_group_name                                  = azurerm_resource_group.main.name
  recovery_vault_name                                  = azurerm_recovery_services_vault.dr.name
  recovery_point_retention_in_minutes                  = 1440  # 24時間
  application_consistent_snapshot_frequency_in_minutes = 240   # 4時間
}

# DR用 VNet
resource "azurerm_virtual_network" "dr" {
  name                = "vnet-dr"
  location            = azurerm_resource_group.dr.location
  resource_group_name = azurerm_resource_group.dr.name
  address_space       = ["10.1.0.0/16"]
}
```

### フェイルオーバーの種類

```
テストフェイルオーバー:
- 本番環境に影響なし
- 分離されたネットワーク
- DR計画の検証
- 定期的な実施推奨（四半期ごと）

計画されたフェイルオーバー:
- 計画メンテナンス時
- データ損失なし
- レプリケーション停止
- 本番環境シャットダウン可能

計画外フェイルオーバー:
- 障害発生時
- 最小限のデータ損失（RPO内）
- 即座の実行
- 本番環境が利用不可
```

## 5.7 診断設定

### 概念説明

診断設定は、Azureリソースのログとメトリックを収集先（Log Analytics、Storage、Event Hub）に送信します。

### 診断設定の構成

```
診断設定のフロー:
┌────────────────────────────────────┐
│ Azureリソース                      │
│ - VM, App Service, Storage等       │
└──────────┬─────────────────────────┘
           │
           ↓ 診断設定
┌──────────┴─────────────────────────┐
│ ログカテゴリ                       │
│ - 監査ログ                         │
│ - 実行ログ                         │
│ - メトリック                       │
└──────────┬─────────────────────────┘
           │
           ↓ 送信先（複数選択可）
┌──────────┴─────────────────────────┐
│ 1. Log Analytics ワークスペース    │
│    - 分析・クエリ                  │
│                                    │
│ 2. Storage Account                 │
│    - 長期保存・アーカイブ          │
│                                    │
│ 3. Event Hub                       │
│    - ストリーミング・外部システム  │
└────────────────────────────────────┘
```

### 主要リソースの診断ログカテゴリ

```
Storage Account:
- StorageRead
- StorageWrite
- StorageDelete

App Service:
- AppServiceHTTPLogs
- AppServiceConsoleLogs
- AppServiceAppLogs
- AppServiceAuditLogs

Network Security Group:
- NetworkSecurityGroupEvent
- NetworkSecurityGroupRuleCounter

Application Gateway:
- ApplicationGatewayAccessLog
- ApplicationGatewayPerformanceLog
- ApplicationGatewayFirewallLog
```

## 5.8 試験対策のポイント

### Domain 5 重要ポイント

1. **Log Analytics ワークスペース設計**
   - 単一ワークスペース推奨（クロスリソース分析容易）
   - データ保持: デフォルト30日、最大730日

2. **Application Insightsのテレメトリタイプ**
   - リクエスト、依存関係、例外、ページビュー、カスタムイベント

3. **アラートの種類と用途**
   - メトリック: リアルタイム、数値ベース
   - ログ: KQLクエリ、複雑な条件
   - アクティビティログ: リソース操作監視

4. **バックアップの保持ポリシー**
   - 日次、週次、月次、年次の組み合わせ
   - インスタント復元: 2-5日

5. **Site Recoveryのシナリオ**
   - Azure→Azure（別リージョン）
   - オンプレミス→Azure

### 試験Tips

✅ **Application InsightsはLog Analyticsワークスペースベース推奨**
✅ **メトリックは93日保持、ログはカスタマイズ可能**
✅ **Recovery Services VaultのGeo冗長性でクロスリージョンリストア可能**
✅ **診断設定は複数の送信先を同時指定可能**
✅ **アクショングループは複数の通知方法を組み合わせ可能**

## Domain 5 練習問題

### 問題1
WebアプリケーションのHTTP 500エラーが過去5分間に10回以上発生した場合に管理者にメール通知したいです。どの種類のアラートを使用すべきですか?

A) メトリックアラート  
B) ログアラート  
C) アクティビティログアラート  
D) サービス正常性アラート

<details>
<summary>解答と解説</summary>

**正解: B) ログアラート**

**解説:**
Application Insightsのリクエストログを KQLでクエリし、条件に基づいてアラートを発生させます。

**ログアラートのKQLクエリ例:**
```kql
requests
| where timestamp > ago(5m)
| where resultCode == "500"
| summarize count()
| where count_ > 10
```

**アラートタイプの選択基準:**
- **ログアラート**: 複雑な条件、ログデータのクエリ、特定のエラーパターン
- **メトリックアラート**: シンプルな数値条件、リアルタイム性重視
- **アクティビティログアラート**: リソースの操作（作成、削除等）監視
- **サービス正常性アラート**: Azureサービスの障害通知

**構成要素:**
1. KQLクエリで条件定義
2. 評価頻度: 5分
3. しきい値: count > 10
4. アクショングループでメール送信

**参照:** `monitoring.tf` - ログアラート設定
</details>

### 問題2
VMのバックアップを構成しています。日次バックアップを30日保持し、毎週日曜日のバックアップを12週間保持したいです。どのリソースで設定しますか？

A) Azure Backup Agent  
B) Backup Policy  
C) Recovery Services Vault  
D) スナップショット

<details>
<summary>解答と解説</summary>

**正解: B) Backup Policy**

**解説:**
バックアップポリシーで、スケジュール、保持期間、インスタント復元の設定を定義します。

**バックアップポリシーの構成要素:**

1. **スケジュール:**
   - 頻度: 毎日
   - 時刻: 23:00（例）

2. **保持期間:**
   - 日次: 30日
   - 週次: 12週（毎週日曜日）
   - 月次: 12ヶ月（オプション）
   - 年次: 10年（オプション）

3. **インスタント復元:**
   - スナップショット保持: 2-5日
   - 高速復元

**Terraform設定例:**
```hcl
resource "azurerm_backup_policy_vm" "daily" {
  backup {
    frequency = "Daily"
    time      = "23:00"
  }
  
  retention_daily {
    count = 30
  }
  
  retention_weekly {
    count    = 12
    weekdays = ["Sunday"]
  }
}
```

**参照:** `disaster_recovery.tf` - バックアップポリシー
</details>

### 問題3
複数のAzureリソース（VM、ストレージアカウント、App Service）のログを一元的に分析したいです。どのサービスを使用すべきですか？

A) Azure Monitor メトリック  
B) Log Analytics ワークスペース  
C) Application Insights  
D) Azure Storage Account

<details>
<summary>解答と解説</summary>

**正解: B) Log Analytics ワークスペース**

**解説:**
Log Analytics ワークスペースは、複数のリソースからログを収集し、KQLで横断的に分析できます。

**Log Analytics の利点:**
- クロスリソースクエリ
- 統一されたクエリ言語（KQL）
- 長期保存（最大730日）
- 統合された可視化（Workbooks）

**構成手順:**
1. Log Analytics ワークスペース作成
2. 各リソースで診断設定を構成
3. 送信先としてワークスペースを指定

**クロスリソースクエリの例:**
```kql
// VMとApp Serviceの両方からエラーを検索
union
    (AzureDiagnostics | where ResourceType == "VIRTUALMACHINES"),
    (AppServiceHTTPLogs | where ScStatus >= 400)
| where TimeGenerated > ago(1h)
| project TimeGenerated, ResourceType, Message
| order by TimeGenerated desc
```

**ベストプラクティス:**
- 単一ワークスペースで複数リソース管理（推奨）
- 環境ごとの分離が必要な場合は別ワークスペース
- RBAC でアクセス制御

**参照:** `monitoring.tf` - Log Analytics ワークスペース
</details>

### 問題4
東日本リージョンで稼働中のVMを、リージョン障害時に西日本リージョンで復旧できるようにしたいです。どのサービスを使用すべきですか？

A) Azure Backup  
B) Azure Site Recovery  
C) Geo冗長ストレージ  
D) 可用性ゾーン

<details>
<summary>解答と解説</summary>

**正解: B) Azure Site Recovery**

**解説:**
Azure Site Recovery (ASR) は、VMを別リージョンに継続的にレプリケートし、障害時のフェイルオーバーを実現します。

**ASR vs Backup:**

| 機能 | Azure Site Recovery | Azure Backup |
|------|---------------------|--------------|
| 目的 | DR（災害復旧） | データ保護 |
| RPO | 数分 | 24時間 |
| RTO | 数時間 | 数時間〜数日 |
| レプリケーション | 継続的 | スケジュール |
| フェイルオーバー | 自動/手動 | 手動復元 |

**ASRの構成:**
```
プライマリリージョン（東日本）
    ↓ 継続的レプリケーション
セカンダリリージョン（西日本）
    ↓ フェイルオーバー
DR環境でVM起動
```

**フェイルオーバーの流れ:**
1. レプリケーションポリシー設定（RPO、復旧ポイント保持）
2. 復旧計画作成（起動順序、スクリプト）
3. テストフェイルオーバーで検証
4. 障害時に本番フェイルオーバー実行

**他のオプション:**
- Backup: データ保護用、DRには不向き
- GRS: ストレージアカウントの冗長性（VMには不十分）
- 可用性ゾーン: 同一リージョン内の高可用性

**参照:** `disaster_recovery.tf` - ASR設定
</details>

### 問題5
Application Insightsで収集したデータのコストを削減したいです。すべてのテレメトリではなく、一部のみを収集する方法は？

A) Application Insightsを無効化  
B) サンプリングを構成  
C) Log Analytics ワークスペースを削除  
D) 診断設定を無効化

<details>
<summary>解答と解説</summary>

**正解: B) サンプリングを構成**

**解説:**
サンプリングにより、データの代表的なサンプルのみを収集し、コストを削減できます。

**サンプリングの種類:**

**1. インジェストサンプリング（推奨）:**
- Application Insights側で実施
- すべてのSDKで動作
- 最も簡単な設定

**2. アダプティブサンプリング:**
- SDK側で自動調整
- トラフィック量に応じて動的にサンプリング率を変更
- .NET、Java、Node.js、Python

**3. 固定率サンプリング:**
- SDK側で固定のサンプリング率
- より細かい制御

**設定例（Terraform）:**
```hcl
resource "azurerm_application_insights" "main" {
  sampling_percentage = 50  # 50%のデータを収集
}
```

**サンプリングの考慮事項:**
- メトリックは影響を受けない（カウントは自動調整）
- 検索・分析時にサンプリング率が考慮される
- 重要なイベントはサンプリング対象外に設定可能

**コスト削減のその他の方法:**
- 日次データ上限設定
- 不要なテレメトリフィルタリング
- 適切なデータ保持期間設定

**参照:** `monitoring.tf` - Application Insights設定
</details>

### 問題6
Log Analytics ワークスペースのデータ保持期間を180日から365日に変更したいです。追加コストが発生するのは何日目以降ですか？

A) 30日目以降  
B) 31日目以降  
C) 180日目以降  
D) 365日目以降

<details>
<summary>解答と解説</summary>

**正解: B) 31日目以降**

**解説:**
Log Analytics ワークスペースでは、最初の30日間のデータ保持は無料です。31日目以降は追加料金が発生します。

**Log Analytics の価格構造:**

**データインジェスト:**
- 最初の5GB/日: 無料
- 以降: $2.76/GB（東日本リージョン、概算）

**データ保持:**
- 0-30日: 無料
- 31-730日: $0.12/GB/月（概算）

**例: 365日保持の場合:**
```
100GB のデータを365日保持:
- 0-30日: 無料
- 31-365日: 100GB × $0.12 × 11ヶ月 = $132
```

**コスト最適化のベストプラクティス:**
1. 必要なログのみ収集
2. 長期保存が不要なデータはフィルタリング
3. アーカイブ用にStorage Accountを使用（診断設定で送信先追加）
4. コミットメント層の検討（大量データの場合）

**保持期間の変更:**
```hcl
resource "azurerm_log_analytics_workspace" "main" {
  retention_in_days = 365  # 30, 60, 90...730
}
```

**参照:** `monitoring.tf` - Log Analytics ワークスペース設定
</details>

---

# 総合模擬問題（20問）

### 問題1
サブスクリプション内のすべてのリソースに「CostCenter」タグを必須にし、タグがない場合はリソース作成を拒否したいです。どのAzure Policy効果を使用すべきですか？

A) Audit  
B) Deny  
C) Append  
D) Modify

<details>
<summary>解答: B) Deny</summary>

リソース作成を拒否するには、Deny効果が必要です。Auditは記録のみ、Appendは自動追加、Modifyはプロパティ変更です。
</details>

### 問題2
ストレージアカウントのデータを東日本と西日本の両方で読み取りアクセス可能にしたいです。どの冗長性オプションを選択すべきですか？

A) LRS  
B) ZRS  
C) GRS  
D) RA-GRS

<details>
<summary>解答: D) RA-GRS</summary>

RA-GRS (Read-Access Geo-Redundant Storage) は、プライマリとセカンダリの両リージョンで読み取りアクセスが可能です。GRSはセカンダリから読み取り不可です。
</details>

### 問題3
VMのCPU使用率が過去5分間で平均80%を超えた場合にアラートを発生させたいです。どのメトリック集計方法を使用すべきですか？

A) Maximum  
B) Minimum  
C) Average  
D) Total

<details>
<summary>解答: C) Average</summary>

「過去5分間で平均80%」という条件のため、Average（平均）集計を使用します。
</details>

### 問題4
可用性ゾーンに対応したLoad Balancerを作成する必要があります。どのSKUを選択すべきですか？

A) Basic  
B) Standard  
C) Premium  
D) Classic

<details>
<summary>解答: B) Standard</summary>

可用性ゾーンに対応しているのはStandard SKUのみです。Basic SKUは可用性ゾーン非対応でSLAもありません。
</details>

### 問題5
App ServiceでNode.jsアプリケーションをホストし、デプロイスロットを使用してステージング環境でテストしてから本番にデプロイしたいです。最低限必要なApp Serviceプランは？

A) Free  
B) Basic  
C) Standard  
D) Premium

<details>
<summary>解答: C) Standard</summary>

デプロイスロット機能はStandard以上のプランで利用可能です。Free、Shared、Basicではデプロイスロットは使用できません。
</details>

### 問題6
VNet A（10.0.0.0/16）とVNet B（10.1.0.0/16）をピアリングしました。さらにVNet BとVNet C（10.2.0.0/16）もピアリングしています。VNet AからVNet Cへ通信できますか？

A) はい、自動的に通信可能  
B) いいえ、VNetピアリングは非推移的  
C) ゲートウェイトランジットを設定すれば可能  
D) ルートテーブルを追加すれば可能

<details>
<summary>解答: B) いいえ、VNetピアリングは非推移的</summary>

VNetピアリングは非推移的です。A-B、B-Cがピアリングされていても、AとCは通信できません。AとCの通信にはA-Cのピアリングが必要です。
</details>

### 問題7
ストレージアカウントへのアクセスを特定のVNetからのみ許可し、オンプレミスからもVPN経由でアクセスできるようにしたいです。最も適切な方法は？

A) サービスエンドポイント  
B) プライベートエンドポイント  
C) パブリックアクセス許可  
D) ストレージファイアウォールのみ

<details>
<summary>解答: B) プライベートエンドポイント</summary>

プライベートエンドポイントを使用すると、オンプレミスからもVPN/ExpressRoute経由でアクセス可能です。サービスエンドポイントはVNet内のみです。
</details>

### 問題8
VMのOSディスクに最高レベルのパフォーマンスと最低レイテンシが必要です。どのディスクタイプを選択すべきですか？

A) Standard HDD  
B) Standard SSD  
C) Premium SSD  
D) Ultra Disk

<details>
<summary>解答: D) Ultra Disk</summary>

Ultra Diskは最高のIOPS（最大160,000）、スループット（最大4,000 MB/s）、最低レイテンシ（サブミリ秒）を提供します。
</details>

### 問題9
Recovery Services Vaultでバックアップデータをセカンダリリージョンから復元できるようにしたいです。どの設定が必要ですか？

A) Geo-Redundant Storage  
B) Cross Region Restore  
C) AとB両方  
D) Locally Redundant Storage

<details>
<summary>解答: C) AとB両方</summary>

セカンダリリージョンから復元するには、ストレージをGeo-Redundantに設定し、Cross Region Restoreを有効にする必要があります。
</details>

### 問題10
WebアプリケーションにWAF保護を追加し、グローバルに分散した複数のバックエンドに負荷分散したいです。どのサービスが最適ですか？

A) Azure Load Balancer  
B) Application Gateway  
C) Azure Front Door with WAF  
D) Traffic Manager

<details>
<summary>解答: C) Azure Front Door with WAF</summary>

Azure Front Doorはグローバルな負荷分散とWAF機能を提供します。Application Gatewayはリージョナル、Load Balancerはレイヤー4で WAF なし、Traffic ManagerはDNSベースでWAFなしです。
</details>

### 問題11
NSGでHTTPSトラフィック（ポート443）のみを許可し、その他すべてを拒否したいです。明示的に拒否ルールを作成する必要がありますか？

A) はい、すべてのポートに対して拒否ルールが必要  
B) いいえ、デフォルトルールで拒否される  
C) はい、優先度を正しく設定する必要がある  
D) はい、各プロトコルに対して拒否ルールが必要

<details>
<summary>解答: B) いいえ、デフォルトルールで拒否される</summary>

NSGにはデフォルトで「DenyAllInBound」ルール（優先度65500）があり、明示的に許可されていないトラフィックは自動的に拒否されます。
</details>

### 問題12
VMSSで営業時間（平日9-18時）は最低5インスタンス、それ以外は2インスタンスで運用したいです。どのスケーリングを使用すべきですか？

A) メトリックベースのみ  
B) スケジュールベースのみ  
C) 両方の組み合わせ  
D) 手動スケーリング

<details>
<summary>解答: C) 両方の組み合わせ</summary>

スケジュールベースで時間帯による最小インスタンス数を設定し、メトリックベースでトラフィックに応じた追加スケーリングを行います。
</details>

### 問題13
Application Insightsで可用性テストを構成し、東京、ニューヨーク、ロンドンから5分ごとにエンドポイントを監視したいです。どのテストタイプを使用すべきですか？

A) URLピングテスト  
B) マルチステップWebテスト  
C) TrackAvailability  
D) カスタムメトリック

<details>
<summary>解答: A) URLピングテスト</summary>

URLピングテスト（Standard Web Test）は、複数の地理的な場所から定期的にエンドポイントを監視するための最適な方法です。
</details>

### 問題14
ストレージアカウントのBlobを作成後30日でCool層、90日でArchive層に自動移動したいです。どの機能を使用すべきですか？

A) Blob バージョニング  
B) ライフサイクル管理ポリシー  
C) 論理削除  
D) 不変ストレージ

<details>
<summary>解答: B) ライフサイクル管理ポリシー</summary>

ライフサイクル管理ポリシーにより、日数ベースでBlobを自動的に異なるアクセス層に移動または削除できます。
</details>

### 問題15
Container RegistryからApp Serviceにコンテナをデプロイする際、最もセキュアな認証方法は？

A) 管理者アカウント  
B) マネージドID  
C) アクセスキー  
D) パブリックアクセス

<details>
<summary>解答: B) マネージドID</summary>

マネージドIDを使用すると、資格情報を管理する必要がなく、最もセキュアです。App ServiceにACRのAcrPullロールを割り当てます。
</details>

### 問題16
東日本リージョンのVMを、障害時に西日本リージョンで数時間以内に復旧できるようにしたいです。どのサービスを使用すべきですか？

A) Azure Backup  
B) Azure Site Recovery  
C) Geo-Redundant Storage  
D) スナップショット

<details>
<summary>解答: B) Azure Site Recovery</summary>

Azure Site Recoveryは、VMを別リージョンに継続的にレプリケートし、障害時のフェイルオーバーを実現します（RTO: 数時間、RPO: 数分）。
</details>

### 問題17
Log Analytics ワークスペースで過去1時間のHTTP 500エラーを検索するKQLクエリで使用する時間フィルターは？

A) where timestamp > ago(1h)  
B) where timestamp > now()-1h  
C) where time > -1h  
D) where datetime > 1h

<details>
<summary>解答: A) where timestamp > ago(1h)</summary>

KQLでは `ago()` 関数を使用して相対時間を指定します。`ago(1h)` は1時間前を意味します。
</details>

### 問題18
可用性セットにVMを配置した場合のSLAは？

A) 99.9%  
B) 99.95%  
C) 99.99%  
D) 100%

<details>
<summary>解答: B) 99.95%</summary>

可用性セットに2台以上のVMを配置した場合のSLAは99.95%です。単一VM（Premium SSD使用）は99.9%、可用性ゾーンは99.99%です。
</details>

### 問題19
Azureリソースの作成/削除/変更などの管理操作を監視してアラートを発生させたいです。どの種類のアラートを使用すべきですか？

A) メトリックアラート  
B) ログアラート  
C) アクティビティログアラート  
D) Application Insightsアラート

<details>
<summary>解答: C) アクティビティログアラート</summary>

アクティビティログアラートは、Azureリソースに対する管理操作（作成、削除、更新等）を監視します。
</details>

### 問題20
仮想ネットワークの各サブネットで予約されているIPアドレスの数は？

A) 3個  
B) 4個  
C) 5個  
D) 6個

<details>
<summary>解答: C) 5個</summary>

各サブネットで最初の4個（.0、.1、.2、.3）と最後の1個（.255）の合計5個のIPアドレスが予約されています。
</details>

---

# 学習リソース

## 公式ドキュメント

### Microsoft Learn
- [AZ-104 学習パス](https://learn.microsoft.com/ja-jp/training/courses/az-104t00)
- [Azure Administrator 認定](https://learn.microsoft.com/ja-jp/certifications/azure-administrator/)

### Azureドキュメント
- [Azure Virtual Machines](https://learn.microsoft.com/ja-jp/azure/virtual-machines/)
- [Azure Storage](https://learn.microsoft.com/ja-jp/azure/storage/)
- [Azure Networking](https://learn.microsoft.com/ja-jp/azure/networking/)
- [Azure Monitor](https://learn.microsoft.com/ja-jp/azure/azure-monitor/)

## 実践的リソース

### ハンズオン環境
- [Azure無料アカウント](https://azure.microsoft.com/ja-jp/free/)
  - 12ヶ月間の無料サービス
  - $200クレジット（30日間）
  - 常に無料のサービス

### Terraform
- [Azure Provider ドキュメント](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- 本リポジトリの `infra/` ディレクトリ

## 試験対策

### 模擬試験
- [Microsoft公式模擬試験](https://learn.microsoft.com/ja-jp/certifications/exams/az-104/practice/assessment)
- MeasureUp模擬試験（有料）

### コミュニティ
- [r/AzureCertification](https://www.reddit.com/r/AzureCertification/)
- [Microsoft Tech Community](https://techcommunity.microsoft.com/t5/azure/ct-p/Azure)

## 試験当日のTips

### 準備
1. **早めに会場/システムをセットアップ**（オンライン試験の場合は30分前）
2. **身分証明書を2つ用意**（パスポート、運転免許証等）
3. **静かな環境を確保**（オンライン試験）
4. **ホワイトボード/メモ帳使用可**（試験センターの場合）

### 試験中
1. **時間配分:** 1問あたり2-3分を目安
2. **確信がない問題はマークして後で見直し**
3. **ケーススタディは最後に回す**（時間がかかるため）
4. **選択肢を消去法で絞る**

### 重点分野（出題頻度が高い）
- ✅ RBAC とAzure Policy
- ✅ VNetピアリングとプライベートエンドポイント
- ✅ Load BalancerとApplication Gateway
- ✅ VM の可用性オプション（可用性セット、可用性ゾーン）
- ✅ Storage の冗長性とアクセス層
- ✅ Azure Monitor とアラート

## 最後に

AZ-104試験は、Azureの管理者としての実務能力を証明する重要な資格です。本ガイドで学習した内容を、実際のTerraformコード（`infra/`ディレクトリ）で実践し、理解を深めてください。

**学習のポイント:**
1. **ハンズオン重視:** 実際にリソースを作成・管理する
2. **ドキュメント参照:** 公式ドキュメントで詳細を確認
3. **定期的な復習:** 特に苦手分野を重点的に
4. **模擬試験:** 本番前に必ず受験

**合格を心よりお祈りします！** 🎉

---

**最終更新:** 2024年1月  
**対象試験:** AZ-104 (Microsoft Azure Administrator)  
**難易度:** 中級  
**推奨学習期間:** 2-3ヶ月（実務経験により変動）