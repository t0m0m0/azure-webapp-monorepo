# AZ-104 Sample

## はじめに

本文。

# Domain 1: IDとガバナンスの管理 (20-25%)

## 1.1 セクション概念

本文。

## Domain 1 練習問題

### 問題1
タグがないリソースの作成を防ぐには、どのAzure Policy効果を使用すべきですか？

A) Audit  
B) Append  
C) Deny  
D) DeployIfNotExists

<details>
<summary>解答と解説</summary>

**正解: C) Deny**

**解説:**
- Deny: タグがない場合にリソース作成を拒否します。

**参照:** `governance.tf` - ポリシー定義の例
</details>

### 問題2
Contributorロールの説明として正しいものは？

A) 全権限  
B) 権限管理を除く全て  
C) 読み取り専用  
D) VM専用

<details>
<summary>解答と解説</summary>

**正解: B) 権限管理を除く全て**

**解説:**
Contributor は権限管理以外のすべての操作ができます。

**参照:** `governance.tf`
</details>

# Domain 2: ストレージの実装と管理 (15-20%)

## Domain 2 練習問題

### 問題1
GRSとRA-GRSの違いは？

A) 容量  
B) セカンダリ読み取り可否  
C) 価格  
D) リージョン数

<details>
<summary>解答と解説</summary>

**正解: B) セカンダリ読み取り可否**

RA-GRS のみセカンダリから読み取り可能です。
</details>

# 総合模擬問題（20問）

### 問題1
Policy の Deny 効果は？

A) 記録のみ  
B) 拒否  
C) 追加  
D) 変更

<details>
<summary>解答: B) 拒否</summary>

Deny はリソース作成を拒否します。
</details>

### 問題2
RA-GRS の特徴は？

A) ローカルのみ  
B) ゾーン冗長  
C) プライマリとセカンダリで読み取り可  
D) バックアップ不可

<details>
<summary>解答: C) プライマリとセカンダリで読み取り可</summary>

RA-GRS はセカンダリからも読み取りアクセスできます。
</details>
