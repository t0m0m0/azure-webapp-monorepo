# =============================================================================
# Load Balancer — Azure Load Balancer concepts for AZ-104
# =============================================================================
# AZ-104試験範囲:
#   - Azure Load Balancerの構成と管理
#   - フロントエンドIP構成
#   - バックエンドプール
#   - ヘルスプローブ
#   - 負荷分散ルール
#   - インバウンドNATルール
#   - Basic vs Standard SKUの違い
#
# 試験Tips:
#   - Standard LBはゾーン冗長対応、Basic LBは非対応
#   - Standard LBのバックエンドプールはNIC単位、同一VNet内のVM/VMSS
#   - Standard LBはデフォルトでインバウンド通信を拒否 (NSGが必要)
#   - Basic LBはデフォルトでインバウンド通信を許可
# =============================================================================

# 変数定義: variables.tf で var.enable_load_balancer を定義済み

# =============================================================================
# Basic SKU vs Standard SKU — AZ-104頻出比較
# =============================================================================
# ┌────────────────────────┬──────────────────────┬────────────────────────┐
# │        機能            │    Basic SKU         │    Standard SKU        │
# ├────────────────────────┼──────────────────────┼────────────────────────┤
# │ バックエンドプール     │ 可用性セット内のVM   │ VNet内の任意のVM/VMSS  │
# │ バックエンドプール上限 │ 300                  │ 1000                   │
# │ ヘルスプローブ         │ TCP, HTTP            │ TCP, HTTP, HTTPS       │
# │ 可用性ゾーン           │ 非対応               │ ゾーン冗長/ゾーン指定  │
# │ 診断ログ               │ 非対応               │ Azure Monitor対応      │
# │ HA Ports               │ 非対応               │ 対応                   │
# │ アウトバウンドルール    │ 非対応               │ 対応                   │
# │ SLA                    │ なし                 │ 99.99%                 │
# │ セキュリティ           │ デフォルト開放        │ デフォルト閉鎖 (NSG必須)│
# │ 料金                   │ 無料                 │ 有料                   │
# │ SKU混在               │ 不可 (PIP SKU一致)   │ 不可 (PIP SKU一致)     │
# └────────────────────────┴──────────────────────┴────────────────────────┘
#
# 重要: Basic SKUは2025年9月に廃止予定。Standard SKUを使用すること。
# 試験ポイント: Public IPとLoad BalancerのSKUは必ず一致させる
# =============================================================================

# -----------------------------------------------------------------------------
# Public IP for Load Balancer
# -----------------------------------------------------------------------------
# AZ-104ポイント:
#   - Load Balancer用のPublic IPはLBと同じSKUにする
#   - Standard SKU → Static割り当て必須
#   - ゾーン冗長構成でリージョン全体の障害に対応
# -----------------------------------------------------------------------------

resource "azurerm_public_ip" "lb" {
  count = var.enable_load_balancer ? 1 : 0

  name                = "${local.name_prefix}-lb-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"        # Standard SKUはStatic必須
  sku                 = "Standard"      # LBのSKUと一致させる
  zones               = ["1", "2", "3"] # ゾーン冗長 (全ゾーンに分散)

  # 試験Note: sku_tier = "Regional" (デフォルト) vs "Global" (クロスリージョンLB用)

  tags = merge(
    local.common_tags,
    {
      Purpose = "LoadBalancer-Frontend"
    }
  )
}

# -----------------------------------------------------------------------------
# Public Load Balancer (Standard SKU)
# -----------------------------------------------------------------------------
# AZ-104ポイント:
#   - パブリックLB: インターネットからのトラフィックを分散
#   - 内部LB: VNet内のトラフィックを分散 (Private IP使用)
#   - L4 (Transport Layer): TCP/UDPベースの負荷分散
#   - ハッシュベースの分散: ソースIP、ソースポート、宛先IP、宛先ポート、プロトコル
#
# 分散モード (Session Persistence / セッション永続化):
#   - None (5タプル): デフォルト、最も均等に分散
#   - Client IP (2タプル): 同じクライアントIPは同じVMへ
#   - Client IP and Protocol (3タプル): 同じIP+プロトコルは同じVMへ
# -----------------------------------------------------------------------------

resource "azurerm_lb" "main" {
  count = var.enable_load_balancer ? 1 : 0

  name                = "${local.name_prefix}-lb"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard" # 本番環境では必ずStandard
  sku_tier            = "Regional" # "Regional" (デフォルト) or "Global"

  # -------------------------------------------------------------------------
  # Frontend IP Configuration
  # -------------------------------------------------------------------------
  # 試験ポイント:
  #   - パブリックLB: Public IPを関連付け
  #   - 内部LB: サブネットとPrivate IPを指定
  #   - 1つのLBに複数のフロントエンドIPを構成可能
  #   - ゾーン冗長 vs ゾーン指定 (zones パラメータ)
  # -------------------------------------------------------------------------
  frontend_ip_configuration {
    name                 = "PublicFrontend"
    public_ip_address_id = azurerm_public_ip.lb[0].id
    # zones = ["1", "2", "3"] # ゾーン冗長 (Public IPのzonesで制御)
  }

  # 内部LBの場合の構成例 (コメント参照):
  # frontend_ip_configuration {
  #   name                          = "InternalFrontend"
  #   subnet_id                     = azurerm_subnet.app.id
  #   private_ip_address_allocation = "Static"
  #   private_ip_address            = "10.0.1.100"
  #   zones                         = ["1", "2", "3"]
  # }

  tags = merge(
    local.common_tags,
    {
      SKU     = "Standard"
      Purpose = "AZ-104-Study-LoadBalancer"
    }
  )
}

# -----------------------------------------------------------------------------
# Backend Address Pool
# -----------------------------------------------------------------------------
# AZ-104ポイント:
#   - バックエンドプール: トラフィックを受け取るVM/VMSSのグループ
#   - Standard SKU: 同一VNet内の任意のVM (最大1000)
#   - Basic SKU: 同一可用性セット内のVM (最大300)
#   - NICベースまたはIPベースの関連付け
#   - VMSSと統合する場合、VMSS側でbackend_pool_idsを指定
# -----------------------------------------------------------------------------

resource "azurerm_lb_backend_address_pool" "main" {
  count = var.enable_load_balancer ? 1 : 0

  name            = "${local.name_prefix}-backend-pool"
  loadbalancer_id = azurerm_lb.main[0].id
}

# バックエンドプールへのNIC関連付け
# 試験Note: VM個別にNICをプールに関連付ける方法
# VMSSの場合はVMSS設定内でbackend_pool_idsを指定する
resource "azurerm_network_interface_backend_address_pool_association" "vm" {
  count = (var.enable_load_balancer && var.enable_vm) ? 1 : 0

  network_interface_id    = azurerm_network_interface.vm[0].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.main[0].id
}

# -----------------------------------------------------------------------------
# Health Probe
# -----------------------------------------------------------------------------
# AZ-104ポイント:
#   - ヘルスプローブ: バックエンドVMの正常性を監視
#   - プローブタイプ:
#     * TCP: ポートへのTCP接続確認 (Basic/Standard)
#     * HTTP: HTTPステータスコード200の確認 (Basic/Standard)
#     * HTTPS: HTTPS接続+ステータスコード200 (Standard SKUのみ)
#   - 間隔 (interval): プローブの実行間隔 (秒)
#   - しきい値 (number_of_probes): 連続失敗回数で「異常」と判定
#
# 試験Tips:
#   - プローブが失敗したVMはバックエンドプールから自動除外される
#   - VMが復旧するとプローブ成功後に自動的にプールに戻る
#   - HTTPプローブはカスタムパス (/health など) を指定可能
#   - Standard LBのみHTTPSプローブをサポート
# -----------------------------------------------------------------------------

resource "azurerm_lb_probe" "http" {
  count = var.enable_load_balancer ? 1 : 0

  name                = "http-health-probe"
  loadbalancer_id     = azurerm_lb.main[0].id
  protocol            = "Http" # "Tcp", "Http", "Https"
  port                = 80
  request_path        = "/" # HTTPプローブの場合は必須
  interval_in_seconds = 15  # 15秒ごとにプローブ実行
  number_of_probes    = 2   # 2回連続失敗で異常と判定
}

# TCPプローブの例 (SSH接続確認用)
resource "azurerm_lb_probe" "tcp_ssh" {
  count = var.enable_load_balancer ? 1 : 0

  name                = "tcp-ssh-probe"
  loadbalancer_id     = azurerm_lb.main[0].id
  protocol            = "Tcp" # TCP接続の確認のみ
  port                = 22
  interval_in_seconds = 15
  number_of_probes    = 2
}

# -----------------------------------------------------------------------------
# Load Balancing Rule
# -----------------------------------------------------------------------------
# AZ-104ポイント:
#   - 負荷分散ルール: フロントエンドIPの特定ポートをバックエンドプールに転送
#   - フローティングIP (Direct Server Return): SQL AlwaysOn、特殊構成用
#   - セッション永続化 (Session Persistence):
#     * "Default" (None): 5タプルハッシュ (最も均等な分散)
#     * "SourceIP": クライアントIP固定 (2タプル)
#     * "SourceIPProtocol": クライアントIP+プロトコル固定 (3タプル)
#   - アイドルタイムアウト: 4-30分 (デフォルト4分)
#     * TCP Keep-aliveまたはアプリ側でタイムアウト対策
#
# 試験Tips:
#   - HA Ports: protocol="All", port=0 で全ポート転送 (Standard SKUのみ)
#   - HA Portsは内部LBでのみ使用可能
#   - 1つのフロントエンドIPに複数のルールを設定可能
# -----------------------------------------------------------------------------

resource "azurerm_lb_rule" "http" {
  count = var.enable_load_balancer ? 1 : 0

  name                           = "http-rule"
  loadbalancer_id                = azurerm_lb.main[0].id
  frontend_ip_configuration_name = "PublicFrontend"
  protocol                       = "Tcp" # "Tcp", "Udp", "All"
  frontend_port                  = 80    # クライアントが接続するポート
  backend_port                   = 80    # バックエンドVMのポート
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.main[0].id]
  probe_id                       = azurerm_lb_probe.http[0].id

  # セッション永続化 (試験頻出)
  load_distribution = "Default" # "Default" (5タプル), "SourceIP" (2タプル), "SourceIPProtocol" (3タプル)

  # アイドルタイムアウト
  idle_timeout_in_minutes = 4 # デフォルト4分、最大30分

  # フローティングIP (Direct Server Return)
  # 試験Note: SQL AlwaysOn、Windows NLB等の特殊構成で使用
  enable_floating_ip = false

  # TCP Reset (Standard SKUのみ)
  # アイドルタイムアウト時にTCP RSTパケットを送信
  enable_tcp_reset = true

  # アウトバウンドSNAT無効化
  # 試験Note: アウトバウンドルールを使用する場合はfalseにする
  disable_outbound_snat = true
}

# HTTPS負荷分散ルール (追加例)
resource "azurerm_lb_rule" "https" {
  count = var.enable_load_balancer ? 1 : 0

  name                           = "https-rule"
  loadbalancer_id                = azurerm_lb.main[0].id
  frontend_ip_configuration_name = "PublicFrontend"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.main[0].id]
  probe_id                       = azurerm_lb_probe.http[0].id
  load_distribution              = "Default"
  idle_timeout_in_minutes        = 4
  enable_floating_ip             = false
  enable_tcp_reset               = true
  disable_outbound_snat          = true
}

# -----------------------------------------------------------------------------
# Inbound NAT Rule
# -----------------------------------------------------------------------------
# AZ-104ポイント:
#   - NATルール: 特定のフロントエンドポートを特定のバックエンドVMにマッピング
#   - 用途: SSH/RDP等の管理アクセスを個別VMに転送
#   - 例: フロントエンドポート 50001 → VM1:22、50002 → VM2:22
#
# NATルール vs 負荷分散ルール:
#   - NATルール: 1対1マッピング (特定VMへの直接アクセス)
#   - 負荷分散ルール: 1対多 (バックエンドプール全体に分散)
#
# 試験Tips:
#   - NATルールはバックエンドプールを必要としない (個別VM指定)
#   - NATプール: 連続ポート範囲をVMSSインスタンスに自動マッピング
#   - 本番環境ではBastion/VPN経由が推奨 (NATルールは開発/テスト用)
# -----------------------------------------------------------------------------

resource "azurerm_lb_nat_rule" "ssh_vm1" {
  count = var.enable_load_balancer ? 1 : 0

  name                           = "ssh-nat-vm1"
  resource_group_name            = azurerm_resource_group.main.name
  loadbalancer_id                = azurerm_lb.main[0].id
  frontend_ip_configuration_name = "PublicFrontend"
  protocol                       = "Tcp"
  frontend_port                  = 50001 # 外部からのアクセスポート
  backend_port                   = 22    # VMのSSHポート
  enable_floating_ip             = false
  enable_tcp_reset               = true
  idle_timeout_in_minutes        = 4
}

# NATルールとNICの関連付け
resource "azurerm_network_interface_nat_rule_association" "vm" {
  count = (var.enable_load_balancer && var.enable_vm) ? 1 : 0

  network_interface_id  = azurerm_network_interface.vm[0].id
  ip_configuration_name = "internal"
  nat_rule_id           = azurerm_lb_nat_rule.ssh_vm1[0].id
}

# -----------------------------------------------------------------------------
# Outbound Rule (Standard SKU Only)
# -----------------------------------------------------------------------------
# AZ-104ポイント:
#   - アウトバウンドルール: バックエンドVMからインターネットへの送信トラフィック制御
#   - Standard LBはデフォルトでアウトバウンド接続を許可しない
#   - アウトバウンド接続方法:
#     * 負荷分散ルール (暗黙的SNAT) — disable_outbound_snat=false
#     * アウトバウンドルール (明示的SNAT) — 推奨
#     * NAT Gateway — 最も推奨される方法
#     * インスタンスレベルPublic IP
#
# 試験Tips:
#   - SNATポートの枯渇: 大量のアウトバウンド接続時に発生
#   - NAT Gatewayが最も推奨されるアウトバウンド方法
#   - Basic LBは暗黙的にアウトバウンドSNATが有効
# -----------------------------------------------------------------------------

# resource "azurerm_lb_outbound_rule" "main" {
#   count = var.enable_load_balancer ? 1 : 0
#
#   name                    = "outbound-rule"
#   loadbalancer_id         = azurerm_lb.main[0].id
#   protocol                = "All"
#   backend_address_pool_id = azurerm_lb_backend_address_pool.main[0].id
#
#   frontend_ip_configuration {
#     name = "PublicFrontend"
#   }
#
#   # SNATポート割り当て
#   allocated_outbound_ports = 1024 # VMあたりのSNATポート数
#   idle_timeout_in_minutes  = 4
# }

# =============================================================================
# Azure 負荷分散サービスの比較 — AZ-104頻出トピック
# =============================================================================
#
# ┌──────────────────────┬───────────┬──────────┬──────────────┬──────────────┐
# │        項目          │ Load      │ App      │ Traffic      │ Front Door   │
# │                      │ Balancer  │ Gateway  │ Manager      │              │
# ├──────────────────────┼───────────┼──────────┼──────────────┼──────────────┤
# │ レイヤー             │ L4        │ L7       │ DNS          │ L7           │
# │                      │ (TCP/UDP) │ (HTTP/S) │ (DNS解決)    │ (HTTP/S)     │
# ├──────────────────────┼───────────┼──────────┼──────────────┼──────────────┤
# │ スコープ             │ リージョン│ リージョン│ グローバル   │ グローバル   │
# │                      │ (※1)     │          │              │              │
# ├──────────────────────┼───────────┼──────────┼──────────────┼──────────────┤
# │ プロトコル           │ TCP/UDP   │ HTTP/S   │ 全て         │ HTTP/S       │
# │                      │           │ /WS      │              │              │
# ├──────────────────────┼───────────┼──────────┼──────────────┼──────────────┤
# │ SSL終端              │ ×        │ ○       │ ×           │ ○           │
# ├──────────────────────┼───────────┼──────────┼──────────────┼──────────────┤
# │ WAF                  │ ×        │ ○       │ ×           │ ○           │
# ├──────────────────────┼───────────┼──────────┼──────────────┼──────────────┤
# │ URL/パスベース       │ ×        │ ○       │ ×           │ ○           │
# │ ルーティング         │           │          │              │              │
# ├──────────────────────┼───────────┼──────────┼──────────────┼──────────────┤
# │ セッション           │ ○        │ ○       │ ×           │ ○           │
# │ アフィニティ         │ (ハッシュ)│ (Cookie) │              │ (Cookie)     │
# ├──────────────────────┼───────────┼──────────┼──────────────┼──────────────┤
# │ ルーティング方法     │ ハッシュ  │ ラウンド │ 優先度       │ 重み付け     │
# │                      │           │ ロビン   │ 重み付け     │ レイテンシ   │
# │                      │           │          │ パフォーマンス│              │
# │                      │           │          │ 地理的       │              │
# ├──────────────────────┼───────────┼──────────┼──────────────┼──────────────┤
# │ ヘルスプローブ       │ TCP/HTTP  │ HTTP/S   │ HTTP/S       │ HTTP/S       │
# │                      │ /HTTPS    │          │              │              │
# ├──────────────────────┼───────────┼──────────┼──────────────┼──────────────┤
# │ 主な用途             │ VM/VMSS   │ Web      │ マルチ       │ グローバル   │
# │                      │ の負荷分散│ アプリ   │ リージョン   │ Webアプリ    │
# │                      │           │ WAF      │ DR           │ CDN+WAF      │
# └──────────────────────┴───────────┴──────────┴──────────────┴──────────────┘
#
# ※1: Cross-region Load Balancer (Global tier) も利用可能
#
# =============================================================================
# 各サービスの詳細解説:
# =============================================================================
#
# 【Azure Load Balancer (L4)】
#   - TCP/UDPレベルの負荷分散、HTTPヘッダーは解析しない
#   - 最も高速 (L4のため低レイテンシ)
#   - パブリックLB: インターネットトラフィック
#   - 内部LB: VNet内部トラフィック
#   - HA Ports: 全ポートの負荷分散 (NVA、ファイアウォール用)
#   - Cross-region LB: グローバル負荷分散 (Standard Global tier)
#
# 【Application Gateway (L7)】
#   - HTTPレベルの負荷分散、URLパスベースルーティング
#   - SSL終端/オフロード: バックエンドの負荷軽減
#   - WAF (Web Application Firewall): OWASP Core Rule Set
#   - Cookie-based セッションアフィニティ
#   - WebSocket/HTTP/2サポート
#   - URL書き換え、リダイレクト機能
#   - 自動スケーリング (v2 SKU)
#
# 【Traffic Manager (DNS)】
#   - DNSレベルの負荷分散 (クライアントにIPを返すだけ)
#   - グローバル分散: 複数リージョンのエンドポイントに分散
#   - ルーティング方法:
#     * Priority (優先度): プライマリ/セカンダリのフェイルオーバー
#     * Weighted (重み付け): トラフィックの割合指定
#     * Performance (パフォーマンス): 最寄りリージョンへルーティング
#     * Geographic (地理的): ユーザーの地域に基づくルーティング
#     * MultiValue: 複数のIPを返す
#     * Subnet: クライアントIPのサブネットに基づくルーティング
#   - ネストされたプロファイルで複雑なルーティングが可能
#
# 【Azure Front Door (L7 Global)】
#   - グローバルL7負荷分散 + CDN + WAF
#   - エニキャストプロトコル: Microsoftグローバルネットワーク経由
#   - SSL終端、URL書き換え、キャッシュ機能
#   - セッションアフィニティ (Cookie-based)
#   - WAF + DDoS保護の統合
#   - CDN機能で静的コンテンツを高速配信
#
# =============================================================================
# AZ-104試験での選択ガイド:
# =============================================================================
#
# Q: VM/VMSSへのTCP負荷分散が必要？
# A: → Azure Load Balancer
#
# Q: URLパスベースのルーティングやWAFが必要？
# A: → Application Gateway (リージョン内) or Front Door (グローバル)
#
# Q: 複数リージョン間のフェイルオーバーが必要？
# A: → Traffic Manager (DNS) or Front Door (L7)
#
# Q: グローバルなWebアプリでCDN+WAF+負荷分散を一括で？
# A: → Azure Front Door
#
# Q: 非HTTP (SQL, SSH等) のグローバル分散が必要？
# A: → Traffic Manager + Load Balancer (組み合わせ)
#
# Q: NVA (Network Virtual Appliance) への全ポート転送が必要？
# A: → Load Balancer (HA Ports)
# =============================================================================
