# =============================================================================
# Azure Storage Account — AZ-104 学習用 Terraform 構成
# =============================================================================
#
# 【AZ-104 試験での重要度】★★★★★（最重要トピックの一つ）
#   Azure Storage は AZ-104 試験の「データの実装と管理」セクションで頻出。
#   以下の概念を確実に理解すること：
#     - ストレージアカウントの種類と冗長性オプション
#     - Blob Storage のアクセス層（Hot / Cool / Cold / Archive）
#     - Azure Files（SMB/NFS ファイル共有）
#     - ネットワークセキュリティ（ファイアウォール、Private Endpoint、Service Endpoint）
#     - データ保護（Soft Delete、バージョニング、ライフサイクル管理）
#     - SAS トークンとアクセスキーによる認証
#     - Azure Storage Explorer の使用方法
#
# 【ストレージアカウントの種類】(AZ-104 頻出)
#   - Standard General-purpose v2 (StorageV2): 最も一般的。Blob, File, Queue, Table 対応
#   - Premium Block Blobs (BlockBlobStorage): 低レイテンシが必要な場合
#   - Premium File Shares (FileStorage): エンタープライズファイル共有
#   - Premium Page Blobs: VM ディスク用（通常は Managed Disks を使用）
#
# 【冗長性オプション】(AZ-104 必須知識)
#   ┌─────────────────────────────────────────────────────────────────────┐
#   │ オプション │ コピー数 │ リージョン │ 可用性     │ 用途           │
#   ├─────────────────────────────────────────────────────────────────────┤
#   │ LRS        │ 3        │ 単一       │ 99.999...9%│ 開発/テスト    │
#   │ ZRS        │ 3        │ 単一(3AZ)  │ 99.999...9%│ 高可用性       │
#   │ GRS        │ 6        │ 2リージョン│ 99.999...9%│ DR対応         │
#   │ GZRS       │ 6        │ 2リージョン│ 99.999...9%│ 最高の保護     │
#   │ RA-GRS     │ 6        │ 2リージョン│ 読取り可能 │ 読取りDR       │
#   │ RA-GZRS    │ 6        │ 2リージョン│ 読取り可能 │ 最高+読取りDR  │
#   └─────────────────────────────────────────────────────────────────────┘
#   ※ RA = Read-Access: セカンダリリージョンからの「読み取り」が可能
#   ※ GRS/GZRS のセカンダリは通常読み取り不可。RA 付きで読み取り可能になる
#   ※ AZ-104 では「どの冗長性がどのシナリオに適切か」が頻出
#
# 【SAS トークン（Shared Access Signature）】(AZ-104 頻出)
#   SAS はストレージリソースへの委任アクセスを提供する URI クエリパラメータ。
#
#   3種類の SAS:
#   1. User Delegation SAS (推奨): Azure AD 認証情報で署名。最もセキュア
#      - Blob Storage のみ対応
#      - Azure AD のセキュリティプリンシパルの権限で署名
#   2. Service SAS: ストレージアカウントキーで署名。特定サービスのみ
#      - Blob, Queue, Table, Files の個別サービスへのアクセス
#   3. Account SAS: ストレージアカウントキーで署名。複数サービス可
#      - 1つ以上のストレージサービスへのアクセスを委任
#
#   SAS の構成要素:
#     - sr:  リソースタイプ（b=blob, c=container, s=service）
#     - sp:  権限（r=read, w=write, d=delete, l=list, a=add, c=create）
#     - st:  開始時刻
#     - se:  有効期限 ※必須。短く設定するのがベストプラクティス
#     - sip: 許可する IP アドレス範囲
#     - spr: 許可するプロトコル（https, https+http）
#     - sig: 署名（改ざん防止）
#
#   ※ Terraform では SAS トークンを直接生成しない（有効期限があるため）
#   ※ 実運用では Azure AD + RBAC（Storage Blob Data Reader 等）を推奨
#   ※ Stored Access Policy を使うと SAS の有効期限をサーバー側で制御可能
#
# =============================================================================

# =============================================================================
# 変数定義: variables.tf で var.enable_storage を定義済み
# =============================================================================
# Storage Account（ストレージアカウント）
# =============================================================================
#
# 【AZ-104 ポイント】
#   - ストレージアカウント名はグローバルに一意（3〜24文字、小文字英数字のみ）
#   - account_tier: Standard / Premium
#     Standard = HDD ベース（汎用）
#     Premium  = SSD ベース（低レイテンシ要件）
#   - account_kind: StorageV2（推奨）/ BlobStorage / Storage(レガシー)
#   - access_tier: Hot（頻繁アクセス）/ Cool（低頻度アクセス、30日以上保持推奨）
#     ※ Archive 層は Blob レベルでのみ設定可能（アカウントレベルでは不可）
#   - min_tls_version: セキュリティのため TLS 1.2 を強制
#   - enable_https_traffic_only: HTTPS のみ許可（HTTP を拒否）
#
# 【試験で問われるシナリオ例】
#   Q: 「コストを最小化しつつ、30日以内にアクセスしないデータを自動的に
#       安価な層に移動したい」→ ライフサイクル管理ポリシーを使用
#   Q: 「セカンダリリージョンから読み取りたい」→ RA-GRS または RA-GZRS
#   Q: 「3つの可用性ゾーンにまたがってデータを保護したい」→ ZRS
#
# =============================================================================

resource "azurerm_storage_account" "main" {
  count               = var.enable_storage ? 1 : 0
  name                = replace("${local.name_prefix}st", "-", "")
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.common_tags

  # ---------------------------------------------------------------------------
  # アカウント基本設定
  # ---------------------------------------------------------------------------
  # account_tier:
  #   "Standard" = 汎用 (HDD)、コスト重視
  #   "Premium"  = 高性能 (SSD)、低レイテンシ要件
  account_tier = "Standard"

  # account_replication_type: 冗長性 (上記の表を参照)
  #   開発環境:   LRS（コスト最小）
  #   本番環境:   GRS または GZRS（リージョン障害対策）
  #   読取りDR:   RA-GRS（セカンダリからの読み取りが必要な場合）
  account_replication_type = local.is_production ? "GRS" : "LRS"

  # account_kind: ストレージアカウントの種類
  #   "StorageV2" = 推奨。全機能対応（Blob, File, Queue, Table）
  account_kind = "StorageV2"

  # access_tier: デフォルトのアクセス層（Blob Storage 用）
  #   "Hot"  = 頻繁にアクセスするデータ（ストレージコスト高、アクセスコスト低）
  #   "Cool" = 低頻度アクセス（ストレージコスト低、アクセスコスト高、30日以上推奨）
  #   ※ "Cold" 層（180日以上推奨）と "Archive" 層（Blob レベルのみ設定可）もある
  access_tier = "Hot"

  # ---------------------------------------------------------------------------
  # セキュリティ設定
  # ---------------------------------------------------------------------------
  # TLS 1.2 を強制（AZ-104: セキュリティのベストプラクティス）
  min_tls_version = "TLS1_2"

  # HTTPS のみ許可（HTTP トラフィックを拒否）
  https_traffic_only_enabled = true

  # 共有キーによるアクセスを許可するか
  #   false にすると Azure AD 認証のみ許可（よりセキュア）
  #   ※ 一部のツール（AzCopy 旧バージョン等）は共有キーが必要
  shared_access_key_enabled = true

  # パブリック Blob アクセスを無効化
  #   true にすると、コンテナレベルで匿名アクセスを設定できなくなる
  #   ※ セキュリティのベストプラクティス: 常に false
  allow_nested_items_to_be_public = false

  # ---------------------------------------------------------------------------
  # Blob サービスの設定
  # ---------------------------------------------------------------------------
  blob_properties {
    # =========================================================================
    # Blob バージョニング（Blob Versioning）
    # =========================================================================
    # 【AZ-104 ポイント】
    #   - Blob が変更されるたびに、自動的に以前のバージョンが保持される
    #   - 誤った上書きからの復旧に使用
    #   - バージョンごとにストレージコストが発生（不要なバージョンは
    #     ライフサイクルポリシーで自動削除推奨）
    #   - スナップショットとの違い:
    #     スナップショット = 手動で作成する特定時点のコピー
    #     バージョニング   = 自動で作成される変更履歴
    # =========================================================================
    versioning_enabled = true

    # =========================================================================
    # Blob の論理的な削除（Soft Delete）
    # =========================================================================
    # 【AZ-104 ポイント】
    #   - 削除された Blob を指定期間保持（復元可能）
    #   - 誤削除からの保護に必須
    #   - 保持期間: 1〜365 日
    #   - 本番環境では最低 30 日を推奨
    #   - 論理的に削除された Blob もストレージコストが発生
    #   - 完全削除（Purge）は保持期間終了後に自動実行
    #
    # 【試験シナリオ】
    #   Q: 「誤って Blob を削除してしまった。14日以内なら復元可能にしたい」
    #   A: → delete_retention_policy を 14 日以上に設定
    # =========================================================================
    delete_retention_policy {
      days = local.is_production ? 30 : 7
    }

    # コンテナの論理的な削除
    #   コンテナレベルでも同様に削除保護を設定可能
    container_delete_retention_policy {
      days = local.is_production ? 30 : 7
    }

    # 変更フィード（Change Feed）
    #   Blob の作成・変更・削除イベントのトランザクションログ
    #   監査、イベント駆動処理、データレイク同期に使用
    change_feed_enabled = true

    # ポイントインタイムリストア（Point-in-Time Restore）
    #   ※ バージョニング、変更フィード、Blob Soft Delete が必要
    #   ブロック Blob を過去の特定時点に復元可能
    restore_policy {
      days = local.is_production ? 29 : 6
    }
  }

  # ---------------------------------------------------------------------------
  # Azure Files の論理的な削除
  # ---------------------------------------------------------------------------
  # 【AZ-104 ポイント】
  #   ファイル共有にも Soft Delete を設定可能
  #   誤削除されたファイル共有を保持期間内に復元できる
  # ---------------------------------------------------------------------------
  share_properties {
    retention_policy {
      days = local.is_production ? 30 : 7
    }
  }
}

# =============================================================================
# Blob Container（Blob コンテナ）
# =============================================================================
#
# 【AZ-104 ポイント】
#   Blob Storage の階層構造:
#     ストレージアカウント → コンテナ → Blob
#
#   Blob の種類（AZ-104 必須知識）:
#     1. Block Blob:  テキスト・バイナリデータ（最大 190.7 TiB）
#                     ドキュメント、画像、動画など一般的な用途
#     2. Append Blob: 追記操作に最適化（最大 195 GiB）
#                     ログファイルなど
#     3. Page Blob:   ランダム読み書き（最大 8 TiB）
#                     VHD ファイル（VM ディスク）
#
#   アクセス層（Access Tier）— Blob レベルで設定可能:
#   ┌──────────────────────────────────────────────────────────────────┐
#   │ 層       │ ストレージ │ アクセス  │ 最低保持 │ 取出し時間      │
#   │          │ コスト     │ コスト    │ 期間     │                 │
#   ├──────────────────────────────────────────────────────────────────┤
#   │ Hot      │ 高い       │ 低い     │ なし     │ 即座            │
#   │ Cool     │ やや低い   │ やや高い │ 30日     │ 即座            │
#   │ Cold     │ 低い       │ 高い     │ 90日     │ 即座            │
#   │ Archive  │ 最も低い   │ 最も高い │ 180日    │ 数時間〜最大15h │
#   └──────────────────────────────────────────────────────────────────┘
#   ※ Archive 層の Blob はオフライン。アクセスするにはリハイドレート
#    （Hot/Cool に層変更）が必要
#   ※ リハイドレート優先度:
#     - Standard: 最大 15 時間
#     - High:     1 時間未満（追加コストあり）
#
#   コンテナのアクセスレベル:
#     - Private (デフォルト):        認証必須
#     - Blob (匿名読み取り):         Blob URL を知っていれば誰でも読み取り可
#     - Container (匿名リスト+読み取り): コンテナ内の Blob 一覧も公開
#     ※ allow_nested_items_to_be_public=false の場合、Private のみ
#
# =============================================================================

# アプリケーションデータ用コンテナ
resource "azurerm_storage_container" "app_data" {
  count                 = var.enable_storage ? 1 : 0
  name                  = "app-data"
  storage_account_name  = azurerm_storage_account.main[0].name
  container_access_type = "private"
}

# バックアップ用コンテナ
# ※ ライフサイクル管理ポリシーにより自動的に Cool → Archive に移行
resource "azurerm_storage_container" "backups" {
  count                 = var.enable_storage ? 1 : 0
  name                  = "backups"
  storage_account_name  = azurerm_storage_account.main[0].name
  container_access_type = "private"
}

# ログ用コンテナ（Append Blob の使用を想定）
resource "azurerm_storage_container" "logs" {
  count                 = var.enable_storage ? 1 : 0
  name                  = "logs"
  storage_account_name  = azurerm_storage_account.main[0].name
  container_access_type = "private"
}

# =============================================================================
# Azure Files（ファイル共有）
# =============================================================================
#
# 【AZ-104 ポイント】
#   Azure Files は完全マネージドのクラウドファイル共有サービス。
#
#   プロトコル:
#     - SMB (Server Message Block): Windows/Linux/macOS 対応
#       SMB 2.1, 3.0, 3.1.1 をサポート
#     - NFS (Network File System): Linux 対応（Premium のみ）
#       NFS 4.1 をサポート
#
#   主な用途:
#     1. オンプレミスファイルサーバーの置き換え/拡張
#     2. アプリケーションの共有ストレージ（設定ファイル等）
#     3. Azure File Sync でオンプレミスとのハイブリッド構成
#     4. コンテナの永続ストレージ（AKS/ACI から直接マウント可能）
#
#   クォータ（容量制限）:
#     - Standard: 最大 100 TiB（Large File Share 有効時）
#     - Premium:  プロビジョニングされたサイズに基づく IOPS
#
#   Azure File Sync（AZ-104 出題範囲）:
#     - オンプレミスの Windows Server と Azure Files を同期
#     - クラウド階層化: 使用頻度の低いファイルをクラウドに自動移行
#     - マルチサイト同期: 複数の Windows Server 間でファイルを同期
#     - 構成要素: Storage Sync Service → Sync Group → Cloud Endpoint +
#       Server Endpoint
#
# 【試験シナリオ】
#   Q: 「オンプレミスのファイルサーバーをクラウドに拡張し、
#       ローカルにはよく使うファイルだけ保持したい」
#   A: → Azure File Sync + クラウド階層化
#
# =============================================================================

resource "azurerm_storage_share" "app_share" {
  count                = var.enable_storage ? 1 : 0
  name                 = "app-share"
  storage_account_name = azurerm_storage_account.main[0].name

  # クォータ (GiB): ファイル共有の最大サイズ
  quota = 50

  # アクセス層（Standard ファイル共有のみ）:
  #   - TransactionOptimized: トランザクション重視（デフォルト）
  #   - Hot:  頻繁なアクセス
  #   - Cool: 低頻度アクセス（コスト削減）
  access_tier = "TransactionOptimized"
}

# =============================================================================
# ストレージアカウント ネットワークルール
# =============================================================================
#
# 【AZ-104 ポイント】
#   ストレージアカウントのネットワークセキュリティは多層防御で構成:
#
#   1. ファイアウォール規則（IP ルール）:
#      - 特定のパブリック IP アドレス/範囲からのアクセスのみ許可
#      - 最大 200 個の IP ルール
#
#   2. 仮想ネットワークルール（Service Endpoint）:
#      - 特定の VNet/サブネットからのアクセスのみ許可
#      - サブネットに Service Endpoint (Microsoft.Storage) が必要
#      - トラフィックは Microsoft バックボーンネットワーク経由
#
#   3. Private Endpoint（プライベートエンドポイント）:
#      - VNet 内のプライベート IP でストレージにアクセス
#      - パブリックインターネットを完全に経由しない
#      - 最もセキュアなアプローチ
#
#   4. default_action:
#      - "Deny"  = ホワイトリスト方式（推奨）
#      - "Allow" = 全アクセス許可（非推奨）
#
#   5. bypass:
#      - "AzureServices" = 信頼された Azure サービスからのアクセスを許可
#        （Azure Backup, Azure Monitor, Azure Event Grid 等）
#      - "Logging", "Metrics" = ログ/メトリクスサービスのバイパス
#
#   Service Endpoint vs Private Endpoint（AZ-104 頻出比較）:
#   ┌─────────────────────────────────────────────────────────────────┐
#   │              │ Service Endpoint    │ Private Endpoint          │
#   ├─────────────────────────────────────────────────────────────────┤
#   │ IP アドレス  │ パブリック IP        │ プライベート IP           │
#   │ DNS          │ パブリック DNS       │ プライベート DNS ゾーン   │
#   │ オンプレ接続 │ 不可（VNet 内のみ）  │ VPN/ExpressRoute 経由可能 │
#   │ コスト       │ 無料                 │ 有料（時間+データ転送）   │
#   │ 設定場所     │ サブネット           │ サブネット（専用不要）    │
#   │ スコープ     │ リージョン全体       │ 特定リソースのみ          │
#   └─────────────────────────────────────────────────────────────────┘
#
# =============================================================================

resource "azurerm_storage_account_network_rules" "main" {
  count              = var.enable_storage ? 1 : 0
  storage_account_id = azurerm_storage_account.main[0].id

  # デフォルトアクション: Deny = ホワイトリスト方式
  default_action = "Deny"

  # 信頼された Azure サービスのバイパス
  #   Azure Backup, Monitor, Event Grid, Log Analytics 等がアクセス可能
  bypass = ["AzureServices", "Logging", "Metrics"]

  # 仮想ネットワークルール: App Service サブネットからのアクセスを許可
  #   ※ サブネット側に service_endpoints = ["Microsoft.Storage"] が必要
  virtual_network_subnet_ids = [
    azurerm_subnet.app.id,
  ]

  # IP ルール: 特定のパブリック IP からのアクセスを許可
  #   ※ 管理者の IP や CI/CD ランナーの IP を追加
  #   例: ip_rules = ["203.0.113.0/24"]
  ip_rules = []
}

# =============================================================================
# ライフサイクル管理ポリシー（Lifecycle Management Policy）
# =============================================================================
#
# 【AZ-104 ポイント】
#   ライフサイクル管理ポリシーは、Blob データを自動的に適切なアクセス層に
#   移動またはデータを削除するルールベースのポリシー。
#
#   対応アクション:
#     - tierToCool:    → Cool 層に移動
#     - tierToCold:    → Cold 層に移動
#     - tierToArchive: → Archive 層に移動
#     - delete:        → Blob を削除
#     - enableAutoTierToHotFromCool: アクセス時に自動的に Hot に戻す
#
#   フィルター条件:
#     - prefix_match: Blob 名のプレフィックスでフィルタリング
#     - blob_types:   blockBlob, appendBlob
#
#   適用対象:
#     - base_blob:    現在の Blob バージョン
#     - snapshot:     スナップショット
#     - version:      以前のバージョン
#
# 【試験シナリオ】
#   Q: 「90日間アクセスされていない Blob を自動的に Cool 層に移動し、
#       365日後に削除したい」
#   A: → ライフサイクル管理ポリシーを以下のように構成
#
# 【コスト最適化の実例】
#   月間ストレージコスト (1TB, Japan East, 概算):
#     Hot:     約 ¥2,700/月
#     Cool:    約 ¥1,350/月（50% 削減）
#     Cold:    約 ¥540/月（80% 削減）
#     Archive: 約 ¥270/月（90% 削減）
#   → ライフサイクルポリシーで自動移行すれば大幅なコスト削減が可能
#
# =============================================================================

resource "azurerm_storage_management_policy" "main" {
  count              = var.enable_storage ? 1 : 0
  storage_account_id = azurerm_storage_account.main[0].id

  # ---------------------------------------------------------------------------
  # ルール 1: アプリケーションデータの階層化
  # ---------------------------------------------------------------------------
  # 30日後 → Cool、90日後 → Cold、180日後 → Archive、365日後 → 削除
  rule {
    name    = "app-data-lifecycle"
    enabled = true

    filters {
      prefix_match = ["app-data/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 30
        tier_to_cold_after_days_since_modification_greater_than    = 90
        tier_to_archive_after_days_since_modification_greater_than = 180
        delete_after_days_since_modification_greater_than          = 365
      }

      # 以前のバージョンも同様にライフサイクル管理
      version {
        change_tier_to_cool_after_days_since_creation    = 30
        change_tier_to_archive_after_days_since_creation = 90
        delete_after_days_since_creation                 = 180
      }

      # スナップショットの自動削除
      snapshot {
        delete_after_days_since_creation_greater_than = 90
      }
    }
  }

  # ---------------------------------------------------------------------------
  # ルール 2: バックアップデータの長期保管
  # ---------------------------------------------------------------------------
  # バックアップは即座に Cool、30日後 → Archive、730日（2年）後 → 削除
  rule {
    name    = "backup-lifecycle"
    enabled = true

    filters {
      prefix_match = ["backups/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 0
        tier_to_archive_after_days_since_modification_greater_than = 30
        delete_after_days_since_modification_greater_than          = 730
      }
    }
  }

  # ---------------------------------------------------------------------------
  # ルール 3: ログデータの自動削除
  # ---------------------------------------------------------------------------
  # ログは 90 日後に削除（コンプライアンス要件に応じて調整）
  rule {
    name    = "logs-cleanup"
    enabled = true

    filters {
      prefix_match = ["logs/"]
      blob_types   = ["blockBlob", "appendBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than = 30
        delete_after_days_since_modification_greater_than       = 90
      }
    }
  }
}

# =============================================================================
# Private Endpoint — Storage Account（Blob サブリソース）
# =============================================================================
#
# 【AZ-104 ポイント】
#   Private Endpoint を使用すると、ストレージアカウントに VNet 内の
#   プライベート IP アドレスでアクセスできる。
#
#   ストレージの Private Endpoint サブリソース:
#     - "blob"         : Blob Storage 用
#     - "file"         : Azure Files 用
#     - "queue"        : Queue Storage 用
#     - "table"        : Table Storage 用
#     - "web"          : 静的 Web サイト用
#     - "dfs"          : Azure Data Lake Storage Gen2 用
#   ※ 各サブリソースごとに個別の Private Endpoint が必要
#
#   Private DNS ゾーン:
#     - Blob:  privatelink.blob.core.windows.net
#     - File:  privatelink.file.core.windows.net
#     - Queue: privatelink.queue.core.windows.net
#     - Table: privatelink.table.core.windows.net
#   ※ DNS 解決により、パブリック FQDN がプライベート IP に解決される
#
# 【試験シナリオ】
#   Q: 「ストレージアカウントへのすべてのトラフィックを
#       プライベートネットワーク経由にしたい」
#   A: → Private Endpoint を作成し、パブリックアクセスを無効化
#
# =============================================================================

resource "azurerm_private_endpoint" "storage_blob" {
  count               = var.enable_storage ? 1 : 0
  name                = "${local.name_prefix}-st-blob-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "${local.name_prefix}-st-blob-psc"
    private_connection_resource_id = azurerm_storage_account.main[0].id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "storage-blob-dns"
    private_dns_zone_ids = [azurerm_private_dns_zone.storage_blob[0].id]
  }
}

# File 用の Private Endpoint
resource "azurerm_private_endpoint" "storage_file" {
  count               = var.enable_storage ? 1 : 0
  name                = "${local.name_prefix}-st-file-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "${local.name_prefix}-st-file-psc"
    private_connection_resource_id = azurerm_storage_account.main[0].id
    is_manual_connection           = false
    subresource_names              = ["file"]
  }

  private_dns_zone_group {
    name                 = "storage-file-dns"
    private_dns_zone_ids = [azurerm_private_dns_zone.storage_file[0].id]
  }
}

# =============================================================================
# Private DNS Zones — Storage
# =============================================================================
#
# 【AZ-104 ポイント】
#   Private DNS ゾーンにより、パブリック FQDN（例:
#   <account>.blob.core.windows.net）がプライベート IP に解決される。
#
#   VNet リンクにより、VNet 内の DNS クエリが Private DNS ゾーンを参照する。
#   registration_enabled = false: VM の自動 DNS 登録を無効化
#   （Private Endpoint の A レコードは自動で作成される）
#
# =============================================================================

# Blob 用 Private DNS ゾーン
resource "azurerm_private_dns_zone" "storage_blob" {
  count               = var.enable_storage ? 1 : 0
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage_blob" {
  count                 = var.enable_storage ? 1 : 0
  name                  = "${local.name_prefix}-st-blob-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.storage_blob[0].name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = local.common_tags
}

# File 用 Private DNS ゾーン
resource "azurerm_private_dns_zone" "storage_file" {
  count               = var.enable_storage ? 1 : 0
  name                = "privatelink.file.core.windows.net"
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage_file" {
  count                 = var.enable_storage ? 1 : 0
  name                  = "${local.name_prefix}-st-file-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.storage_file[0].name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = local.common_tags
}

# =============================================================================
# Diagnostic Settings — Storage Account → Log Analytics
# =============================================================================
#
# 【AZ-104 ポイント】
#   ストレージアカウントの監視は以下を含む:
#     - メトリクス: 可用性、レイテンシ、スループット、トランザクション数
#     - ログ: 読み取り/書き込み/削除オペレーション、認証エラー
#   ※ Blob, File, Queue, Table それぞれ個別に診断設定が必要
#
# =============================================================================

resource "azurerm_monitor_diagnostic_setting" "storage_blob" {
  count                      = var.enable_storage ? 1 : 0
  name                       = "${local.name_prefix}-st-blob-diag"
  target_resource_id         = "${azurerm_storage_account.main[0].id}/blobServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "Transaction"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "storage_file" {
  count                      = var.enable_storage ? 1 : 0
  name                       = "${local.name_prefix}-st-file-diag"
  target_resource_id         = "${azurerm_storage_account.main[0].id}/fileServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "Transaction"
    enabled  = true
  }
}
