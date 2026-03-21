# インフラざっくりガイド 🏗️

> Azure も Terraform も初めての人向け。
> 「何がどこにあって、なぜ必要か」だけわかれば OK。

---

## 全体像：1 枚の絵で理解する

```
┌─ Azure クラウド ─────────────────────────────────────────────┐
│                                                              │
│  ┌─ Resource Group (箱) ──────────────────────────────────┐  │
│  │                                                        │  │
│  │   ┌─ VNet (社内ネットワーク) ──────────────────────┐   │  │
│  │   │                                                │   │  │
│  │   │   ┌──────────┐       ┌──────────────────┐      │   │  │
│  │   │   │ App      │──────▶│ PostgreSQL       │      │   │  │
│  │   │   │ Service  │  DB   │ (データベース)    │      │   │  │
│  │   │   │ (アプリ) │ 接続  │                  │      │   │  │
│  │   │   └────┬─────┘       └──────────────────┘      │   │  │
│  │   │        │                                       │   │  │
│  │   └────────┼───────────────────────────────────────┘   │  │
│  │            │                                           │  │
│  │   ┌────────▼────────┐  ┌────────────┐  ┌───────────┐  │  │
│  │   │ Key Vault       │  │ ACR        │  │ App       │  │  │
│  │   │ (金庫)          │  │ (イメージ  │  │ Insights  │  │  │
│  │   │ パスワード等保管 │  │  置き場)   │  │ (監視)    │  │  │
│  │   └─────────────────┘  └────────────┘  └───────────┘  │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
└──────────────────────────────────────────────────────────────┘
         ▲
         │ HTTPS
    ┌────┴────┐
    │ ユーザー │
    └─────────┘
```

---

## 各パーツの役割（たとえ話つき）

### 🗂️ Resource Group（リソースグループ）

**たとえ：引き出し付きの箱**

Azure 上のリソースを「まとめて管理する入れ物」。
消すときは箱ごと捨てれば全部消える。これだけで十分便利。

### 🌐 VNet + Subnet（仮想ネットワーク）

**たとえ：会社のオフィスビル**

- **VNet** = ビル全体
- **Subnet** = フロア（用途別に分ける）

| サブネット | 用途 | たとえ |
|---|---|---|
| `app` | アプリが動く場所 | 執務フロア |
| `db` | データベース専用 | 金庫室のあるフロア |
| `private-endpoints` | 将来の拡張用 | 空きフロア |

フロアを分ける理由は **セキュリティ**。
DB のフロアにはアプリからしか入れないようにする。

### 🚀 App Service（アプリの実行環境）

**たとえ：レンタルサーバー（でも Docker が動く）**

あなたのアプリが実際に動く場所。
Docker コンテナをそのまま載せるだけ。サーバーの管理は Azure がやってくれる。

覚えておくこと：
- **App Service Plan** = 「どのくらいの性能のマシンを借りるか」（B1 = 一番安い）
- **Linux Web App** = 「そのマシン上で動くアプリ本体」
- `/health` を定期的にチェックして、アプリが死んでたら自動再起動する

### 🐘 PostgreSQL Flexible Server（データベース）

**たとえ：Excel の超高性能バージョン**

アプリのデータを保存する場所。
Azure がバックアップや更新を勝手にやってくれるマネージド型。

ポイント：
- VNet の中にあるので **インターネットから直接触れない**（安全）
- SSL 通信を強制（盗聴防止）

### 📦 ACR（Azure Container Registry）

**たとえ：アプリの配送倉庫**

Docker イメージ（= アプリを箱詰めしたもの）を保管する場所。
`docker push` で送って、App Service がそこから取り出して動かす。

```
開発者 ──docker push──▶ ACR ──pull──▶ App Service
```

### 🔐 Key Vault（キー コンテナー）

**たとえ：貸し金庫**

パスワード・API キー・証明書など「漏れたらまずいもの」を保管する。
アプリは金庫から都度取り出して使う。
ソースコードにパスワードをベタ書きしなくて済む。

### 📊 Application Insights + Log Analytics（監視）

**たとえ：防犯カメラ + 監視モニター**

- **Application Insights** = アプリの動作を記録（レスポンス速度、エラー率など）
- **Log Analytics** = ログをまとめて検索できる場所

「なんかアプリ遅い？」→ ここを見ればわかる。

---

## Terraform って何？

**たとえ：インフラの設計図（兼・自動施工ロボット）**

```
設計図 (.tf ファイル)
       │
       ▼
  terraform apply  ←── 「この通りに作って」と命令
       │
       ▼
  Azure 上にリソースが出来上がる
```

### 知っておけばいいコマンド 3 つ

| コマンド | やること | 実行タイミング |
|---|---|---|
| `terraform init` | 準備（プラグインのDL） | 最初の 1 回 |
| `terraform plan` | 「何が変わるか」の確認 | 変更前に必ず |
| `terraform apply` | 実際に作る・変更する | 確認後 |

⚠️ `terraform destroy` は **全部消す** コマンド。本番では慎重に。

### ファイルの読み方

```
infra/
├── versions.tf        ← 使うツールのバージョン指定（触らない）
├── variables.tf       ← 設定値の定義（変えていいやつ）
├── resource_group.tf  ← 箱を作る
├── network.tf         ← ネットワークを作る
├── database.tf        ← DB を作る
├── acr.tf             ← イメージ倉庫を作る
├── app_service.tf     ← アプリの実行環境を作る
├── keyvault.tf        ← 金庫を作る
├── monitoring.tf      ← 監視を設定する
└── outputs.tf         ← 作った後に表示する情報
```

設定を変えたいときは `terraform.tfvars` ファイルを作る：

```hcl
# 例：本番環境を東日本リージョンに作る
project     = "myapp"
environment = "prod"
location    = "japaneast"
app_sku_name = "P1v3"   # 性能を上げる
```

---

## デプロイの流れ

```
1. コードを書く
       │
2. make docker-build     # アプリを箱詰め
       │
3. make docker-push      # 倉庫(ACR)に送る
       │
4. make deploy           # App Service に「新しい箱使って」と伝える
       │
5. App Service が新イメージで再起動
       │
6. ユーザーに新バージョンが届く 🎉
```

---

## よくある「これどうするの？」

### アプリのログを見たい

Azure Portal → App Service → 「ログ ストリーム」
または CLI:
```bash
az webapp log tail --name webapp-dev-app --resource-group webapp-dev-rg
```

### DB に接続したい

VNet 内からしかアクセスできない（安全のため）。
Azure Portal → PostgreSQL → 「接続文字列」で確認。
ローカルから繋ぎたい場合は、一時的にファイアウォール規則を追加する。

### 性能が足りない

`terraform.tfvars` で SKU を変更 → `terraform apply`：
```hcl
app_sku_name      = "P1v3"          # App Service を強化
postgres_sku_name = "GP_Standard_D2s_v3"  # DB を強化
```

### 環境を分けたい（dev / staging / prod）

`environment` 変数を変えるだけ。リソース名に自動で入る：
```
webapp-dev-rg    ← 開発
webapp-staging-rg ← ステージング
webapp-prod-rg   ← 本番
```

### 全部消したい

```bash
make infra-destroy
```

---

## コスト感（目安）

| リソース | デフォルト SKU | 月額目安 |
|---|---|---|
| App Service | B1 | ¥2,000 前後 |
| PostgreSQL | B_Standard_B1ms | ¥3,000 前後 |
| ACR | Basic | ¥700 前後 |
| Log Analytics | 従量課金 | ¥0〜数百円 |
| Key Vault | Standard | ほぼ無料 |
| **合計** | | **¥6,000〜7,000/月** |

※ 2024年時点の東日本リージョンの参考値。実際の利用量で変動します。

---

## まとめ：最低限これだけ覚える

1. **Terraform** = インフラを「コードで管理」するツール。`plan` → `apply` の順で使う
2. **VNet** = リソース間のネットワーク。外から DB に触れない仕組み
3. **App Service** = アプリが動く場所。Docker コンテナを載せるだけ
4. **ACR** = Docker イメージの倉庫。push して App Service が pull する
5. **Key Vault** = パスワードの金庫。コードにベタ書きしない
6. **Application Insights** = 「アプリ遅い？」の時に見る場所
7. 消すときは `terraform destroy`。**箱（Resource Group）ごと全部消える**
