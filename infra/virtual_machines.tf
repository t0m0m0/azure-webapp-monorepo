# =============================================================================
# Virtual Machines — Azure VM concepts for AZ-104
# =============================================================================
# AZ-104試験範囲:
#   - 仮想マシンの作成と管理
#   - 可用性セット (Availability Set) vs 可用性ゾーン (Availability Zone)
#   - VM拡張機能 (VM Extensions)
#   - カスタムスクリプト拡張機能
#   - VMサイズとディスクの理解
#   - ネットワークインターフェース (NIC) の構成
#   - パブリックIPアドレスの管理
#
# 試験Tips:
#   - 可用性セットは同一データセンター内で99.95% SLA
#   - 可用性ゾーンは物理的に分離されたゾーンで99.99% SLA
#   - VMスケールセット (VMSS) は自動スケーリング機能を提供
#   - Standard SKU IPは静的割り当てが必須、Basicは動的/静的両方可能
# =============================================================================

# SSH 鍵の自動生成（学習環境用）
# 本番環境では事前に生成した鍵を使用すること
resource "tls_private_key" "vm" {
  count     = var.enable_vm ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

# 変数定義: variables.tf で var.enable_vm, var.vm_admin_username, var.vm_size を定義済み
#
# VM Size (AZ-104試験で覚えるべきシリーズ):
#   - B-series: バースト可能、開発/テスト用、最もコスト効率的
#   - D-series: 汎用、バランスの取れたCPU/メモリ比
#   - E-series: メモリ最適化、高いメモリ対CPU比率
#   - F-series: コンピューティング最適化、高いCPU対メモリ比率
#   - N-series: GPU搭載、ML/グラフィックス処理
#
# 命名規則: Standard_{Series}{Version}_{vCPU}s_{Addons}
#   例: Standard_B2s = Standard SKU, B-series, v2, 2 vCPU, s=小メモリ

# -----------------------------------------------------------------------------
# Public IP Address
# -----------------------------------------------------------------------------
# AZ-104ポイント:
#   - Basic SKU: 動的/静的割り当て、可用性ゾーン非対応、無料
#   - Standard SKU: 静的割り当てのみ、ゾーン冗長対応、99.99% SLA
#   - 割り当て方法: Static (事前割り当て) vs Dynamic (リソース開始時に割り当て)
#   - SKU: Public IPとロードバランサーのSKUは一致する必要がある
# -----------------------------------------------------------------------------

resource "azurerm_public_ip" "vm" {
  count = var.enable_vm ? 1 : 0

  name                = "${local.name_prefix}-vm-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"        # Standard SKUは静的のみ
  sku                 = "Standard"      # 試験推奨: Standardを選択 (ゾーン冗長、予測可能なIP)
  zones               = ["1", "2", "3"] # ゾーン冗長構成 (99.99% SLA)

  tags = merge(
    local.common_tags,
    {
      Purpose = "VM-Management-Access"
      # 試験Note: 本番環境ではBastion/VPN経由が推奨、直接Public IPは避ける
    }
  )
}

# -----------------------------------------------------------------------------
# Network Interface (NIC)
# -----------------------------------------------------------------------------
# AZ-104ポイント:
#   - NICは1つ以上のIPコンフィグ (プライマリ/セカンダリ) を持つ
#   - 1つのVMに複数NICをアタッチ可能 (VMサイズに依存)
#   - NSG (Network Security Group) はNICレベルまたはサブネットレベルで適用
#   - Accelerated Networkingは対応VMサイズで有効化可能 (低レイテンシ)
# -----------------------------------------------------------------------------

resource "azurerm_network_interface" "vm" {
  count = var.enable_vm ? 1 : 0

  name                = "${local.name_prefix}-vm-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Accelerated Networkingの有効化 (試験ポイント: 対応VMサイズのみ)
  # 利点: SR-IOVによる低レイテンシ、高スループット、低CPU使用率
  # 要件: 2 vCPU以上のサポート対応VMサイズ
  accelerated_networking_enabled = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.app.id
    private_ip_address_allocation = "Dynamic" # プライベートIPは動的が一般的
    public_ip_address_id          = azurerm_public_ip.vm[0].id
  }

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Availability Set
# -----------------------------------------------------------------------------
# AZ-104重要概念: 可用性セット (Availability Set) vs 可用性ゾーン (Availability Zone)
#
# 【可用性セット (Availability Set)】
#   - 用途: 同一データセンター内での冗長性
#   - SLA: 99.95% (2台以上のVMが必要)
#   - 構成要素:
#     * 障害ドメイン (Fault Domain): 物理的な電源/ネットワークの分離 (最大3)
#     * 更新ドメイン (Update Domain): 計画メンテナンス時の分離 (最大20)
#   - 利点: 無料、同一データセンター内で低レイテンシ
#   - 欠点: データセンター全体の障害に脆弱
#
# 【可用性ゾーン (Availability Zone)】
#   - 用途: データセンター間の物理的分離 (1リージョンに通常3ゾーン)
#   - SLA: 99.99% (2ゾーン以上のVMが必要)
#   - 利点: データセンター全体の障害から保護
#   - 欠点: ゾーン間のわずかなレイテンシ、ゾーン間データ転送コスト
#
# 【試験Tips】
#   - 可用性セットと可用性ゾーンは併用不可 (どちらか一方)
#   - マネージドディスクが必須
#   - 既存VMは可用性セット/ゾーンに後から追加できない (再作成が必要)
#   - 可用性セット内のVMは同じVMサイズである必要はない
# -----------------------------------------------------------------------------

resource "azurerm_availability_set" "vm" {
  count = var.enable_vm ? 1 : 0

  name                = "${local.name_prefix}-vm-avset"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # 障害ドメイン数 (Azure提供範囲内で最大値を設定、通常3が最大)
  platform_fault_domain_count = 2 # 試験Note: リージョンにより最大値が異なる

  # 更新ドメイン数 (計画メンテナンス時の同時更新台数を制御)
  platform_update_domain_count = 5 # 最大20まで設定可能

  # マネージドディスクの使用 (試験Note: 可用性セットでは managed = true が推奨)
  managed = true

  tags = merge(
    local.common_tags,
    {
      AvailabilityType = "AvailabilitySet"
      # Note: この例では可用性セットを使用していますが、
      # 本番環境では可用性ゾーンの使用を検討してください
    }
  )
}

# -----------------------------------------------------------------------------
# Linux Virtual Machine
# -----------------------------------------------------------------------------
# AZ-104ポイント:
#   - OSイメージ: Marketplace (Ubuntu, RHEL等) またはカスタムイメージ
#   - ディスクタイプ: Standard HDD, Standard SSD, Premium SSD, Ultra Disk
#   - ライセンス: Azure Hybrid Benefit (Windows Server/SQL Server)
#   - 認証: SSH公開鍵 (Linux推奨) またはパスワード
#   - cloud-init: VM初回起動時のカスタマイズスクリプト
# -----------------------------------------------------------------------------

resource "azurerm_linux_virtual_machine" "main" {
  count = var.enable_vm ? 1 : 0

  name                = "${local.name_prefix}-vm"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  size                = var.vm_size
  admin_username      = var.vm_admin_username

  # 可用性セットへの配置 (試験Note: availability_set_id と zone は排他的)
  availability_set_id = azurerm_availability_set.vm[0].id
  # zone = "1" # 可用性ゾーンを使う場合はこちら (availability_set_idと排他的)

  network_interface_ids = [
    azurerm_network_interface.vm[0].id,
  ]

  # -----------------------------------------------------------------------------
  # OS Disk Configuration
  # -----------------------------------------------------------------------------
  # ディスクタイプの比較 (AZ-104試験重要):
  #   - Standard_LRS (HDD): 最も安価、低IOPS、dev/test用
  #   - StandardSSD_LRS: 標準SSD、中程度のIOPS、Web/appサーバー用
  #   - Premium_LRS (SSD): 高IOPS、本番ワークロード用、サイズにより性能が異なる
  #   - UltraSSD_LRS: 最高性能、IOPS/スループットを独立調整可能、特殊用途
  #
  # 冗長性オプション:
  #   - LRS: Locally Redundant Storage (同一データセンター内で3コピー)
  #   - ZRS: Zone Redundant Storage (ゾーン間で冗長化)
  # -----------------------------------------------------------------------------
  os_disk {
    name                 = "${local.name_prefix}-vm-osdisk"
    caching              = "ReadWrite"   # OS用は ReadWrite が一般的
    storage_account_type = "Premium_LRS" # 試験推奨: Premium for production
    disk_size_gb         = 30            # OS用は通常30GB以上
  }

  # -----------------------------------------------------------------------------
  # Source Image Reference
  # -----------------------------------------------------------------------------
  # AZ-104試験: 主要なパブリッシャーとOffer
  #   Ubuntu:  Canonical / UbuntuServer または 0001-com-ubuntu-server-*
  #   RHEL:    RedHat / RHEL
  #   CentOS:  OpenLogic / CentOS
  #   Windows: MicrosoftWindowsServer / WindowsServer
  #
  # イメージの確認: az vm image list --all --publisher Canonical
  # -----------------------------------------------------------------------------
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy" # Ubuntu 22.04 LTS
    sku       = "22_04-lts-gen2"               # Generation 2 (UEFI boot)
    version   = "latest"                       # 試験Note: 本番では特定バージョン指定を推奨
  }

  # -----------------------------------------------------------------------------
  # Admin SSH Key (Linux推奨認証方法)
  # -----------------------------------------------------------------------------
  # 試験Note: パスワード認証を無効化し、SSH鍵のみを使用するのがベストプラクティス
  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = var.enable_vm ? tls_private_key.vm[0].public_key_openssh : ""
  }

  # パスワード認証の無効化 (セキュリティベストプラクティス)
  disable_password_authentication = true

  # -----------------------------------------------------------------------------
  # cloud-init Custom Data
  # -----------------------------------------------------------------------------
  # AZ-104ポイント:
  #   - cloud-init: VM初回起動時に実行されるスクリプト (Linux専用)
  #   - base64エンコードが必須
  #   - パッケージインストール、ユーザー作成、設定変更等が可能
  #   - Windows: Custom Script Extension または Desired State Configuration (DSC)
  # -----------------------------------------------------------------------------
  custom_data = base64encode(<<-EOF
    #!/bin/bash
    # cloud-init script for VM initialization
    # AZ-104 Study: このスクリプトはVM初回起動時に1度だけ実行される
    
    # システムアップデート
    apt-get update
    apt-get upgrade -y
    
    # 必要なパッケージのインストール
    apt-get install -y nginx curl jq
    
    # Nginxの起動と自動起動設定
    systemctl start nginx
    systemctl enable nginx
    
    # カスタムindex.htmlの作成
    cat > /var/www/html/index.html <<HTML
    <!DOCTYPE html>
    <html>
    <head><title>AZ-104 VM Study</title></head>
    <body>
      <h1>Azure Virtual Machine - AZ-104</h1>
      <p>Hostname: $(hostname)</p>
      <p>Environment: ${var.environment}</p>
      <p>Initialized via cloud-init</p>
    </body>
    </html>
    HTML
    
    # ログ記録
    echo "cloud-init completed at $(date)" >> /var/log/custom-init.log
  EOF
  )

  # Boot diagnostics (試験ポイント: VM起動問題のトラブルシューティングに必須)
  boot_diagnostics {
    # マネージドストレージアカウントを使用 (storage_account_uriを空にする)
    # 試験Note: 以前は専用ストレージアカウントが必要だったが、現在はマネージド対応
  }

  tags = merge(
    local.common_tags,
    {
      OS          = "Ubuntu-22.04-LTS"
      Purpose     = "AZ-104-Study"
      Initialized = "cloud-init"
    }
  )
}

# -----------------------------------------------------------------------------
# Data Disk (追加データディスク)
# -----------------------------------------------------------------------------
# AZ-104ポイント:
#   - OS Diskとは別に、データ用ディスクをアタッチ可能
#   - ディスクキャッシング: None, ReadOnly, ReadWrite
#     * データベース: None または ReadOnly (書き込みキャッシュは危険)
#     * ファイルサーバー: ReadOnly
#   - LUN (Logical Unit Number): 0-63の範囲で一意に指定
# -----------------------------------------------------------------------------

resource "azurerm_managed_disk" "data" {
  count = var.enable_vm ? 1 : 0

  name                 = "${local.name_prefix}-vm-datadisk"
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty" # 空のディスクを作成
  disk_size_gb         = 128

  # 試験Note: ゾーン指定する場合はVMと同じゾーンに配置
  # zones = ["1"]

  tags = merge(
    local.common_tags,
    {
      DiskType = "Data"
      Purpose  = "Application-Data"
    }
  )
}

resource "azurerm_virtual_machine_data_disk_attachment" "data" {
  count = var.enable_vm ? 1 : 0

  managed_disk_id    = azurerm_managed_disk.data[0].id
  virtual_machine_id = azurerm_linux_virtual_machine.main[0].id
  lun                = 0          # Logical Unit Number (0-63)
  caching            = "ReadOnly" # データディスクは ReadOnly が一般的
}

# -----------------------------------------------------------------------------
# VM Extension — Custom Script Extension
# -----------------------------------------------------------------------------
# AZ-104重要概念:
#   - VM Extensions: VM作成後に追加機能を提供する小さなアプリケーション
#   - 種類:
#     * Custom Script Extension: スクリプト実行 (Linux/Windows)
#     * Desired State Configuration (DSC): Windows構成管理
#     * Azure Monitor Agent: 監視エージェント
#     * Anti-malware Extension: マルウェア対策
#     * Azure Disk Encryption Extension: ディスク暗号化
#
# Custom Script Extension vs cloud-init:
#   - cloud-init: VM初回起動時のみ実行、OSイメージに組み込み
#   - Custom Script Extension: いつでも追加/更新可能、外部スクリプト実行可
# -----------------------------------------------------------------------------

resource "azurerm_virtual_machine_extension" "custom_script" {
  count = var.enable_vm ? 1 : 0

  name                 = "custom-script"
  virtual_machine_id   = azurerm_linux_virtual_machine.main[0].id
  publisher            = "Microsoft.Azure.Extensions" # Linux用パブリッシャー
  type                 = "CustomScript"               # Windows用は "CustomScriptExtension"
  type_handler_version = "2.1"

  # 試験Note: 拡張機能の自動アップグレード有効化 (セキュリティパッチ適用)
  automatic_upgrade_enabled = true

  # スクリプトの実行
  # Option 1: インラインスクリプト (commandToExecute)
  # Option 2: 外部スクリプト (fileUris + commandToExecute)
  settings = jsonencode({
    # fileUris = ["https://raw.githubusercontent.com/example/script.sh"] # 外部スクリプトURL
    commandToExecute = <<-EOT
      #!/bin/bash
      # AZ-104 Custom Script Extension Example
      # この拡張機能はVM作成後に実行される
      
      echo "Custom Script Extension started at $(date)" | tee -a /var/log/extension.log
      
      # データディスクのフォーマットとマウント
      # 試験Note: 追加ディスクは手動でフォーマット/マウントが必要
      if [ -b /dev/sdc ]; then
        # パーティション作成
        parted /dev/sdc --script mklabel gpt mkpart primary ext4 0% 100%
        
        # ファイルシステム作成
        mkfs.ext4 /dev/sdc1
        
        # マウントポイント作成とマウント
        mkdir -p /data
        mount /dev/sdc1 /data
        
        # fstabに追加 (再起動後も自動マウント)
        UUID=$(blkid -s UUID -o value /dev/sdc1)
        echo "UUID=$UUID /data ext4 defaults,nofail 0 2" >> /etc/fstab
        
        echo "Data disk mounted at /data" | tee -a /var/log/extension.log
      fi
      
      # アプリケーションの追加構成
      systemctl restart nginx
      
      echo "Custom Script Extension completed at $(date)" | tee -a /var/log/extension.log
    EOT
  })

  # 保護された設定 (パスワード、キー等の機密情報用)
  # protected_settings = jsonencode({
  #   storageAccountName = "mystorageaccount"
  #   storageAccountKey  = "secret-key-here"
  # })

  tags = local.common_tags
}

# =============================================================================
# VM Scale Sets (VMSS) — AZ-104重要トピック
# =============================================================================
# 【VM Scale Sets (仮想マシンスケールセット)】
#   - 用途: 同一構成のVMグループを自動管理、自動スケーリング
#   - 利点:
#     * 自動スケーリング: CPU/メモリメトリクスに基づいてVMを増減
#     * 高可用性: 複数の障害ドメイン/更新ドメインに自動配置
#     * ロードバランサー統合: Azure Load BalancerまたはApplication Gatewayと連携
#     * 大規模デプロイ: 最大1000台 (カスタムイメージ使用時は600台)
#
# 【スケーリングモード】
#   - Uniform (統一): 全VMが同一構成、VMインスタンスは直接管理不可
#   - Flexible (柔軟): VMを個別管理可能、異なる構成も可能、新規推奨
#
# 【自動スケーリングルール】
#   - メトリクスベース: CPU、メモリ、ディスクI/O、ネットワーク等
#   - スケジュールベース: 特定時間帯にスケールアウト/イン
#   - カスタムメトリクス: Application Insightsメトリクス等
#
# 【アップグレードポリシー】
#   - Automatic: 新しいモデルを自動的に全インスタンスに適用
#   - Rolling: ローリングアップグレード (一部ずつ更新)
#   - Manual: 手動でインスタンスごとにアップグレード
#
# 【試験Tips】
#   - VMSSは単一VMよりも高可用性とスケーラビリティを提供
#   - Application GatewayまたはLoad Balancerとの統合が一般的
#   - カスタムイメージの使用でデプロイ時間を短縮
#   - オーバープロビジョニング: デフォルトで有効、高速スケールアウト
# =============================================================================

# VMSS Terraform例 (参考用コメント):
#
# resource "azurerm_linux_virtual_machine_scale_set" "example" {
#   name                = "${local.name_prefix}-vmss"
#   resource_group_name = azurerm_resource_group.main.name
#   location            = azurerm_resource_group.main.location
#   sku                 = "Standard_B2s"
#   instances           = 2 # 初期インスタンス数
#   admin_username      = "azureuser"
#   zones               = ["1", "2", "3"] # ゾーン間分散
#
#   admin_ssh_key {
#     username   = "azureuser"
#     public_key = file("~/.ssh/id_rsa.pub")
#   }
#
#   source_image_reference {
#     publisher = "Canonical"
#     offer     = "0001-com-ubuntu-server-jammy"
#     sku       = "22_04-lts-gen2"
#     version   = "latest"
#   }
#
#   os_disk {
#     caching              = "ReadWrite"
#     storage_account_type = "Premium_LRS"
#   }
#
#   network_interface {
#     name    = "vmss-nic"
#     primary = true
#
#     ip_configuration {
#       name                                   = "internal"
#       primary                                = true
#       subnet_id                              = azurerm_subnet.app.id
#       load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.main.id]
#     }
#   }
#
#   # 自動スケーリング設定 (別途 azurerm_monitor_autoscale_setting リソース)
#   # アップグレードポリシー
#   upgrade_mode = "Rolling"
#
#   rolling_upgrade_policy {
#     max_batch_instance_percent              = 20
#     max_unhealthy_instance_percent          = 20
#     max_unhealthy_upgraded_instance_percent = 20
#     pause_time_between_batches              = "PT2M"
#   }
#
#   health_probe_id = azurerm_lb_probe.main.id
# }
#
# resource "azurerm_monitor_autoscale_setting" "example" {
#   name                = "${local.name_prefix}-autoscale"
#   resource_group_name = azurerm_resource_group.main.name
#   location            = azurerm_resource_group.main.location
#   target_resource_id  = azurerm_linux_virtual_machine_scale_set.example.id
#
#   profile {
#     name = "defaultProfile"
#
#     capacity {
#       default = 2
#       minimum = 2
#       maximum = 10
#     }
#
#     rule {
#       metric_trigger {
#         metric_name        = "Percentage CPU"
#         metric_resource_id = azurerm_linux_virtual_machine_scale_set.example.id
#         time_grain         = "PT1M"
#         statistic          = "Average"
#         time_window        = "PT5M"
#         time_aggregation   = "Average"
#         operator           = "GreaterThan"
#         threshold          = 75
#       }
#
#       scale_action {
#         direction = "Increase"
#         type      = "ChangeCount"
#         value     = "1"
#         cooldown  = "PT5M"
#       }
#     }
#
#     rule {
#       metric_trigger {
#         metric_name        = "Percentage CPU"
#         metric_resource_id = azurerm_linux_virtual_machine_scale_set.example.id
#         time_grain         = "PT1M"
#         statistic          = "Average"
#         time_window        = "PT5M"
#         time_aggregation   = "Average"
#         operator           = "LessThan"
#         threshold          = 25
#       }
#
#       scale_action {
#         direction = "Decrease"
#         type      = "ChangeCount"
#         value     = "1"
#         cooldown  = "PT5M"
#       }
#     }
#   }
# }
