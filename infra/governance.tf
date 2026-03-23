#####################################################################
# governance.tf - Azure ガバナンス設定 (AZ-104試験対策)
#####################################################################
# このファイルはAzureのガバナンス機能を実装します：
# - Azure Policy (ポリシー定義と割り当て)
# - Resource Locks (リソースロック)
# - RBAC (ロールベースアクセス制御)
# - Tags (タグ管理)
# - Management Groups (概念説明)
# - Azure Blueprints (概念説明)
#
# 試験のポイント:
# - ポリシーとロックの違いを理解する
# - ポリシーは「何ができるか」を制御、ロックは「削除/変更」を防ぐ
# - RBACの4つの基本ロールの違いを暗記する
# - タグの継承はデフォルトでは行われない（ポリシーで実装可能）
#####################################################################

#####################################################################
# データソース - Subscription情報
#####################################################################
# 現在のサブスクリプション情報は budget.tf で定義済み:
#   data "azurerm_subscription" "current" {}
# keyvault.tf で定義済み:
#   data "azurerm_client_config" "current" {}

#####################################################################
# 1. AZURE POLICY - ポリシー定義と割り当て
#####################################################################
# Azure Policyは、リソースのプロパティを評価してコンプライアンスを確保
#
# 試験のポイント:
# - Policy Definition (定義): ルールの内容
# - Policy Assignment (割り当て): スコープへの適用
# - Initiative (イニシアチブ): 複数のポリシーをグループ化
# - Effect (効果): Deny, Audit, Append, DeployIfNotExists, Modify
# - スコープ: Management Group > Subscription > Resource Group > Resource
#####################################################################

# 1.1 カスタムポリシー定義: 必須タグの強制
# このポリシーは、リソース作成時に必須タグがない場合、作成を拒否します
resource "azurerm_policy_definition" "require_tags" {
  count = var.enable_governance ? 1 : 0

  name         = "${local.name_prefix}-require-tags-policy"
  display_name = "Require specific tags on resources"
  description  = "このポリシーは、リソースに必須タグ（Environment, Project）が設定されていることを要求します。"
  policy_type  = "Custom"  # Custom or BuiltIn
  mode         = "Indexed" # Indexed (most resources) or All (includes resource groups)

  # ポリシールールの定義（JSON形式）
  # Effect: Deny - 条件に合わない場合、リソース作成を拒否
  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Resources/subscriptions/resourceGroups" # リソースグループに適用
        },
        {
          anyOf = [
            {
              field  = "tags['Environment']"
              exists = "false"
            },
            {
              field  = "tags['Project']"
              exists = "false"
            }
          ]
        }
      ]
    }
    then = {
      effect = "deny" # deny, audit, append, auditIfNotExists, deployIfNotExists, disabled, modify
    }
  })

  # パラメータの定義（オプション）
  # parameters = jsonencode({
  #   tagName = {
  #     type = "String"
  #     metadata = {
  #       displayName = "Tag Name"
  #       description = "Name of the tag, such as 'Environment'"
  #     }
  #   }
  # })

  metadata = jsonencode({
    category = "Tags"
    version  = "1.0.0"
  })
}

# 1.2 カスタムポリシーをリソースグループに割り当て
resource "azurerm_resource_group_policy_assignment" "require_tags" {
  count = var.enable_governance ? 1 : 0

  name                 = "${local.name_prefix}-require-tags-assignment"
  display_name         = "Require Tags Assignment"
  description          = "リソースグループに必須タグポリシーを適用"
  resource_group_id    = azurerm_resource_group.main.id
  policy_definition_id = azurerm_policy_definition.require_tags[0].id

  # 非準拠リソースのメッセージ
  not_scopes = [] # 除外するスコープ（オプション）

  # パラメータの渡し方（ポリシー定義でパラメータを使用している場合）
  # parameters = jsonencode({
  #   tagName = {
  #     value = "Environment"
  #   }
  # })

  metadata = jsonencode({
    assignedBy = "Terraform"
  })
}

# 1.3 組み込みポリシー: 許可された場所の制限
# Built-inポリシーを使用する例
# Policy Definition IDは Azure Portal または Azure CLI で確認可能
# 試験のポイント: 組み込みポリシーの代表例を覚える
# - Allowed locations
# - Allowed virtual machine size SKUs
# - Require tag and its value
resource "azurerm_resource_group_policy_assignment" "allowed_locations" {
  count = var.enable_governance ? 1 : 0

  name                 = "${local.name_prefix}-allowed-locations"
  display_name         = "Allowed Locations Policy"
  description          = "このポリシーは、リソースを作成できる地域を制限します。"
  resource_group_id    = azurerm_resource_group.main.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"

  # パラメータ: 許可する地域を指定
  parameters = jsonencode({
    listOfAllowedLocations = {
      value = [
        "japaneast",
        "japanwest"
      ]
    }
  })
}

#####################################################################
# 2. RESOURCE LOCKS - リソースロック
#####################################################################
# リソースロックは、誤削除や意図しない変更を防ぐための保護機能
#
# 試験のポイント:
# - CanNotDelete: 削除は不可、変更は可能
# - ReadOnly: 読み取り専用、変更・削除ともに不可
# - ロックは継承される（親スコープのロックは子に適用される）
# - ロックを削除するには、まずロック自体を削除する必要がある
# - Ownerロールでもロックがあれば削除できない
# - ロックはPolicyより強力（Policyは作成を防ぐ、Lockは削除/変更を防ぐ）
#####################################################################

# 2.1 CanNotDelete ロック - リソースグループに適用
# このロックにより、リソースグループとその中のリソースを誤って削除できない
resource "azurerm_management_lock" "resource_group_cannot_delete" {
  count = var.enable_governance ? 1 : 0

  name       = "${local.name_prefix}-rg-lock"
  scope      = azurerm_resource_group.main.id
  lock_level = "CanNotDelete" # CanNotDelete or ReadOnly
  notes      = "このリソースグループは本番環境で使用されているため、削除を防止します。"
}

# 2.2 ReadOnly ロック - 例（コメントアウト）
# ReadOnlyロックは、リソースの変更も削除もできなくなるため、運用中は注意が必要
# 例: ストレージアカウントにReadOnlyを設定すると、データの書き込みもできなくなる
#
# resource "azurerm_management_lock" "storage_readonly" {
#   name       = "${local.name_prefix}-storage-readonly-lock"
#   scope      = azurerm_storage_account.main.id  # 個別リソースにロック
#   lock_level = "ReadOnly"
#   notes      = "監査目的でストレージアカウントを読み取り専用にします。"
# }
#
# 試験のポイント:
# - ReadOnlyロックを設定すると、VMの起動/停止もできなくなる（状態変更と見なされる）
# - App ServiceにReadOnlyを設定すると、アプリのデプロイもできなくなる

#####################################################################
# 3. RBAC (Role-Based Access Control) - ロールベースアクセス制御
#####################################################################
# RBACは、「誰が」「何に対して」「何ができるか」を制御する仕組み
#
# 試験のポイント - 4つの基本ロールの違い（重要！）:
#
# 1. Owner (所有者)
#    - すべての操作が可能
#    - RBAC権限の管理も可能（他のユーザーにロールを割り当てられる）
#    - リソースの削除も可能
#    - 使用例: プロジェクトの責任者
#
# 2. Contributor (共同作成者)
#    - リソースの作成、更新、削除が可能
#    - RBAC権限の管理はできない（他のユーザーにロールを割り当てられない）
#    - 使用例: 開発者、運用担当者
#
# 3. Reader (閲覧者)
#    - リソースの読み取りのみ可能
#    - 変更、削除、作成はできない
#    - 使用例: 監査担当者、レポート作成者
#
# 4. User Access Administrator (ユーザーアクセス管理者)
#    - RBAC権限の管理のみ可能
#    - リソースの作成・変更・削除はできない
#    - 使用例: セキュリティ管理者
#
# スコープの継承:
# Management Group > Subscription > Resource Group > Resource
# 上位スコープで付与された権限は下位に継承される
#####################################################################

# 3.1 カスタムロール定義
# 組み込みロールで要件を満たせない場合、カスタムロールを作成
resource "azurerm_role_definition" "vm_operator" {
  count = var.enable_governance ? 1 : 0

  name        = "${local.name_prefix}-vm-operator"
  scope       = data.azurerm_subscription.current.id # スコープ: サブスクリプション全体
  description = "仮想マシンの起動・停止のみ可能なカスタムロール（作成・削除は不可）"

  permissions {
    actions = [
      "Microsoft.Compute/virtualMachines/read",              # VM情報の読み取り
      "Microsoft.Compute/virtualMachines/start/action",      # VM起動
      "Microsoft.Compute/virtualMachines/restart/action",    # VM再起動
      "Microsoft.Compute/virtualMachines/deallocate/action", # VM停止（割り当て解除）
    ]

    not_actions = [
      # 明示的に禁止する操作（通常はactionsで限定するため不要）
    ]

    data_actions = [
      # データプレーン操作（例: Blobストレージへのアクセス）
    ]

    not_data_actions = []
  }

  assignable_scopes = [
    data.azurerm_subscription.current.id # このロールを割り当て可能なスコープ
  ]
}

# 3.2 カスタムロールの割り当て例（コメントアウト）
# 実際の運用では、ユーザーまたはサービスプリンシパルに割り当てる
#
# resource "azurerm_role_assignment" "vm_operator_assignment" {
#   scope                = azurerm_resource_group.main.id
#   role_definition_id   = azurerm_role_definition.vm_operator[0].role_definition_resource_id
#   principal_id         = "<ユーザーまたはサービスプリンシパルのオブジェクトID>"
# }

# 3.3 組み込みロールの割り当て例: Reader
# 現在の実行ユーザー（サービスプリンシパル）にReaderロールを割り当てる例
resource "azurerm_role_assignment" "reader_example" {
  count = var.enable_governance ? 1 : 0

  scope                = azurerm_resource_group.main.id
  role_definition_name = "Reader" # 組み込みロール名
  principal_id         = data.azurerm_client_config.current.object_id

  # 注: この例は説明目的です。実際には既に権限がある可能性が高いです。
}

# 3.4 よく使う組み込みロールのID（参考）
# Azure Portal やドキュメントで確認可能
#
# Owner:                        8e3af657-a8ff-443c-a75c-2fe8c4bcb635
# Contributor:                  b24988ac-6180-42a0-ab88-20f7382dd24c
# Reader:                       acdd72a7-3385-48ef-bd42-f606fba81ae7
# User Access Administrator:    18d7d88d-d35e-4fb5-a5c3-7773c20a72d9
# Virtual Machine Contributor:  9980e02c-c2be-4d73-94e8-173b1dc7cf3c
# Storage Blob Data Contributor: ba92f5b4-2d11-453d-a403-e96b0029c9fe
#
# role_definition_id を使う場合:
# role_definition_id = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"

#####################################################################
# 4. TAGS - タグ管理とポリシーによる強制
#####################################################################
# タグは、リソースの分類、コスト管理、自動化に使用されるメタデータ
#
# 試験のポイント:
# - タグは key:value のペア（最大50個/リソース）
# - タグは親から子に自動継承されない（ポリシーで実装可能）
# - すべてのリソースタイプがタグをサポートするわけではない
# - タグを使ったコスト分析が可能（Cost Management）
# - Azure Policyでタグの継承や必須化を実装できる
#
# タグの一般的な用途:
# - Environment: dev, staging, production
# - CostCenter: 部門コード
# - Owner: 責任者
# - Project: プロジェクト名
# - Application: アプリケーション名
#####################################################################

# 4.1 タグ継承ポリシー（組み込み）の割り当て例
# リソースグループのタグをリソースに継承させる
resource "azurerm_resource_group_policy_assignment" "inherit_tags" {
  count = var.enable_governance ? 1 : 0

  name                 = "${local.name_prefix}-inherit-tags"
  display_name         = "Inherit Environment tag from resource group"
  description          = "リソースグループの Environment タグを子リソースに継承します。"
  resource_group_id    = azurerm_resource_group.main.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/cd3aa116-8754-49c9-a813-28dc5c5d0f7f"

  # パラメータ: 継承するタグ名
  parameters = jsonencode({
    tagName = {
      value = "Environment"
    }
  })
}

# タグのベストプラクティス:
# - 命名規則を統一する（PascalCase vs camelCase vs snake_case）
# - 必須タグをポリシーで強制する
# - タグの値も制限する（例: Environment は dev, staging, prod のみ）
# - コスト分析用のタグを必ず付ける（CostCenter, Project など）

#####################################################################
# 5. AZURE BLUEPRINTS - ブループリント（概念説明）
#####################################################################
# Azure Blueprintsは、環境全体を一貫してデプロイするためのパッケージ
#
# 注意: Terraform には azurerm_blueprint リソースがないため、
#       ARM テンプレートまたは Azure Portal / CLI で実装します。
#
# 試験のポイント:
# - Blueprintsは以下を含むパッケージ:
#   * Role Assignments (RBAC)
#   * Policy Assignments
#   * ARM Templates
#   * Resource Groups
#
# - Blueprintsの利点:
#   * 環境の標準化（ガバナンス要件を満たした環境を自動作成）
#   * バージョン管理（Blueprint定義をバージョン管理可能）
#   * 追跡可能性（Blueprintから作成されたリソースを追跡）
#   * 更新の適用（Blueprintを更新して既存環境に反映）
#
# - Blueprints vs ARM Templates:
#   * ARM Templates: リソースのデプロイのみ
#   * Blueprints: リソース + ポリシー + RBAC + 追跡
#
# - Blueprints vs Terraform:
#   * Blueprintsは Azure ネイティブのガバナンス機能
#   * Terraformはマルチクラウド対応のIaCツール
#   * 両方を組み合わせることも可能
#
# 使用例:
# 1. 新規サブスクリプションに標準的なガバナンス設定を適用
# 2. コンプライアンス要件（ISO 27001、PCI DSS）を満たす環境を作成
# 3. 開発/本番環境のベースラインを統一
#####################################################################

#####################################################################
# 6. MANAGEMENT GROUPS - 管理グループ（概念説明）
#####################################################################
# Management Groupsは、複数のサブスクリプションを階層的に管理する仕組み
#
# 試験のポイント:
# - 階層構造:
#   Tenant Root Group (ルート)
#     └─ Management Group (例: Production)
#          └─ Management Group (例: App1, App2)
#               └─ Subscription
#                    └─ Resource Group
#                         └─ Resource
#
# - 最大6階層まで（ルートを除く）
# - ポリシーとRBACは上位から下位に継承される
# - サブスクリプションは1つの管理グループにのみ所属
#
# - 使用例:
#   * 組織全体でのガバナンス（全サブスクリプションに共通ポリシー適用）
#   * 環境の分離（Production, Development, Sandboxを分ける）
#   * コスト管理（部門ごとに管理グループを作成）
#
# - Terraform での実装:
#   resource "azurerm_management_group" "example" {
#     display_name = "Example Management Group"
#     parent_management_group_id = data.azurerm_client_config.current.tenant_id
#   }
#
# - Management Group へのポリシー割り当て:
#   resource "azurerm_management_group_policy_assignment" "example" {
#     name                 = "example-policy"
#     management_group_id  = azurerm_management_group.example.id
#     policy_definition_id = "..."
#   }
#
# 試験でよく出る質問:
# Q: 管理グループとサブスクリプションの違いは？
# A: 管理グループは複数のサブスクリプションをグループ化する論理コンテナ。
#    サブスクリプションは課金とリソースの境界。
#
# Q: ポリシーは管理グループとサブスクリプションのどちらに割り当てるべき？
# A: 複数のサブスクリプションに適用する場合は管理グループ、
#    特定のサブスクリプションのみの場合はサブスクリプション。
#####################################################################

#####################################################################
# 7. COST MANAGEMENT - コスト管理の追加概念
#####################################################################
# budget.tf で実装済みのコスト管理に加え、ガバナンスの観点からの追加情報
#
# 試験のポイント:
# - Cost Management の主要機能:
#   * Cost Analysis (コスト分析): 過去のコストを視覚化
#   * Budgets (予算): しきい値でアラート（budget.tfで実装済み）
#   * Recommendations (推奨事項): コスト削減の提案
#   * Exports (エクスポート): コストデータを定期的にエクスポート
#
# - タグを使ったコスト分析:
#   * Environment タグでdev/prod環境のコストを分離
#   * CostCenter タグで部門別のコストを集計
#   * Project タグでプロジェクト別のコストを追跡
#
# - Azure Advisor のコスト最適化:
#   * 未使用のリソースの検出
#   * 適切なVMサイズの提案
#   * Reserved Instances の推奨
#
# - コスト削減のベストプラクティス:
#   1. 自動シャットダウン: 開発環境のVMを夜間/週末に停止
#   2. Auto-scaling: 負荷に応じてリソースを増減
#   3. Reserved Instances: 長期利用するリソースは予約購入
#   4. Spot VMs: 中断可能なワークロードに低価格VMを使用
#   5. ストレージの階層化: アクセス頻度に応じてHot/Cool/Archiveを選択
#
# - Azure Hybrid Benefit:
#   * 既存のWindows Server/SQL Serverライセンスを Azure で利用
#   * 最大40%のコスト削減が可能
#####################################################################

# 7.1 コストアラートの追加設定（概念）
# budget.tf で実装済みだが、追加の考慮事項：
#
# - アラートのしきい値: 通常は 50%, 75%, 90%, 100% を設定
# - アクション: メール通知 + Logic App でチケット作成や自動停止
# - 予算のスコープ: Subscription, Resource Group, Management Group
#
# Terraform での実装例（budget.tf参照）:
# resource "azurerm_consumption_budget_resource_group" "example" {
#   name              = "budget-rg"
#   resource_group_id = azurerm_resource_group.main.id
#   amount            = 1000
#   time_grain        = "Monthly"
#   # ...
# }

#####################################################################
# ガバナンスのベストプラクティス まとめ
#####################################################################
# 1. ポリシー優先:
#    - 組み込みポリシーをまず検討
#    - カスタムポリシーは必要最小限に
#
# 2. 最小権限の原則:
#    - 必要な権限のみを付与
#    - Ownerは最小限の人数に
#
# 3. タグの標準化:
#    - 組織全体でタグ規則を統一
#    - 必須タグをポリシーで強制
#
# 4. リソースロックの活用:
#    - 本番環境のリソースグループにCanNotDeleteを設定
#    - ReadOnlyは慎重に（運用に影響）
#
# 5. 管理グループの活用:
#    - 大規模組織では管理グループで階層化
#    - 共通ポリシーは上位レベルで適用
#
# 6. 継続的な監視:
#    - Azure Policy のコンプライアンスダッシュボードを定期確認
#    - Cost Management で予算超過を監視
#    - Azure Advisor の推奨事項を確認
#####################################################################

# 試験対策 - よく出る質問:
#
# Q1: ポリシーとロックの違いは？
# A1: ポリシーは作成時のルールを強制、ロックは既存リソースの削除/変更を防止
#
# Q2: Contributorロールでリソースを削除できないのはなぜ？
# A2: リソースにロック（CanNotDeleteまたはReadOnly）が設定されている
#
# Q3: タグは自動的に継承される？
# A3: いいえ。Azure Policyで継承ポリシーを実装する必要がある
#
# Q4: 管理グループの最大階層は？
# A4: 6階層（ルート管理グループを除く）
#
# Q5: ポリシーの効果（Effect）の種類は？
# A5: Deny, Audit, Append, AuditIfNotExists, DeployIfNotExists, Disabled, Modify
