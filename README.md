# Nutanixログほいほい

## 概要
Nutanix環境のログ収集ツールです  
Prism Centralに登録されたクラスターから、CVMのリアルタイムログ、Syslog、ログファイル収集


## 🚀 クイックスタート

### 方法1. Helmパッケージでのインストール（OCIレジストリ）

前提条件：KUBECONFIGが設定済みであること

#### 基本インストール（Namespaceは自動作成される）
```bash
helm install loghoihoi oci://ghcr.io/konchangakita/loghoihoi \
  --version 0.1.0
```

#### ネームスペースを指定したインストール
```bash
helm install loghoihoi oci://ghcr.io/konchangakita/loghoihoi \
  --version 0.1.0 \
  --set namespace=loghoihoi-test
```

#### 削除方法
```bash
helm uninstall loghoihoi
```
 
<br>
<br>
 
### 方法2. デフォルトインストール（git cloneからの方法）

前提条件：KUBECONFIGが設定済みであること
```bash
# リポジトリをクローン
git clone https://github.com/konchangakita/loghoihoi.git
cd loghoihoi

# Helm Chartでインストール（Namespaceは自動作成される）
helm install loghoihoi ./helm/loghoihoi
```
 
<br>
<br>
  
### 開発環境用 docker-compose
```bash
# ホストマシンのIPアドレスを確認
HOST_IP=$(hostname -I | awk '{print $1}')
echo "ホストIPアドレス: ${HOST_IP}"

# カスタムバックエンドURLを指定する場合
NEXT_PUBLIC_BACKEND_URL=http://${HOST_IP}:7776 docker-compose -f docker-compose.yml up -d --build

# アクセス

# フロントエンド: http://${HOST_IP}:7777
# バックエンドAPI: http://${HOST_IP}:7776/docs, http://${HOST_IP}:7776/redoc
# Kibana: http://${HOST_IP}:5601
```
 
<br>
<br>
  
### Kubernetes（helm使わない）
```bash
cd k8s
KUBECONFIG=/path/to/your/kubeconfig.conf ./deploy.sh

# アクセス
# Ingress経由でアクセス（環境に応じて設定）
```

詳細なインストール手順は **[Helm Chart インストールガイド](./helm/loghoihoi/INSTALLATION_GUIDE.md)** を参照してください。

kubectlを使用した手動デプロイ手順は **[Kubernetesデプロイメントガイド](./k8s/DEPLOYMENT_GUIDE.md)** を参照してください。

> **注意**: Syslog機能を使用する場合は、デプロイ後にNutanixクラスター（Prism Element）でSyslog設定を行い、デプロイしたSyslogサーバ宛てにSyslogを転送するよう設定する必要があります。
>
> 設定手順の詳細は参考ブログ「[【Nutanix ログほいほい】シスログ ほいほい](https://konchangakita.hatenablog.com/entry/2024/05/20/090000)」を参照してください。なお、AOS（Acropolis Operating System）のバージョンによってコマンドが変更になる可能性があります。

 
<br>
<br>
 
## 📚 ドキュメント

### Kubernetes デプロイメントガイド

| ドキュメント | 説明 |
|---|---|
| [Helm Chart インストールガイド](./helm/loghoihoi/INSTALLATION_GUIDE.md) | **Helm Chartを使用したインストール手順（推奨）**<br>- Namespace自動作成<br>- SSH鍵自動生成<br>- インストール確認<br>- トラブルシューティング |
| [Kubernetesデプロイメントガイド](./k8s/DEPLOYMENT_GUIDE.md) | **kubectlを使用した手動デプロイ手順**<br>- クイックスタート<br>- 詳細な手動デプロイ手順<br>- トラブルシューティング<br>- 環境別設定 |

### 機能仕様書

各機能の詳細な仕様、API、実装方法を記載しています。

| ドキュメント | 説明 | バージョン | 最終更新 |
|---|---|---|---|
| [COLLECT_LOG_SPECIFICATION.md](./docs/COLLECT_LOG_SPECIFICATION.md) | **ログ収集機能**<br>CVMからログファイルを収集してZIP化<br>- リアルタイム進捗表示<br>- バックグラウンド処理<br>- 自動キャッシュクリーンアップ | v1.3.0 | 2025-10-29 |
| [REALTIME_LOG_SPECIFICATION.md](./docs/REALTIME_LOG_SPECIFICATION.md) | **リアルタイムログ機能**<br>CVMのログファイルをリアルタイム表示<br>- tail -f相当の機能<br>- フィルタリング機能<br>- CVM選択機能 | v1.2.0 | 2025-10-29 |
| [SYSLOG_SPECIFICATION.md](./docs/SYSLOG_SPECIFICATION.md) | **Syslog機能**<br>Nutanix SyslogをElasticsearchで検索<br>- クラスター判別機能<br>- hostname自動取得<br>- 高度な検索クエリ | v1.3.0 | 2025-10-29 |
| [SSH_KEY_MANAGEMENT_SPEC.md](./docs/SSH_KEY_MANAGEMENT_SPEC.md) | **SSH鍵管理機能**<br>SSH鍵の自動生成・管理<br>- 自動生成と永続化<br>- エラー時のモーダル自動表示<br>- Kubernetes/docker-compose対応 | v1.3.0 | 2025-10-29 |
| [UUID_EXPLORER_SPECIFICATION.md](./docs/UUID_EXPLORER_SPECIFICATION.md) | **UUID Explorer機能**<br>Nutanix UUIDの検索・分析<br>- UUID検索<br>- 関連エンティティ表示<br>- 履歴管理 | v1.1.0 | 2025-10-29 |

### アーカイブドキュメント

過去の開発計画やマイグレーション記録は[docs/archive/](./docs/archive/)に保管されています。

## 🏗️ アーキテクチャ

### 技術スタック

| レイヤー | 技術 | 説明 |
|---|---|---|
| **フロントエンド** | Next.js 14, React, TypeScript | App Router、DaisyUI |
| **バックエンド** | FastAPI, Python 3.11 | 非同期処理、型ヒント |
| **データストア** | Elasticsearch 7.17 | ログ検索・分析 |
| **インフラ** | Docker, Kubernetes | コンテナ化、オーケストレーション |
| **SSH接続** | Paramiko | Nutanix CVM接続 |

### ディレクトリ構成

```
/
├── backend/
│   ├── fastapi_app/          # FastAPIアプリケーション
│   ├── core/                 # コアロジック（SSH接続、ログ収集）
│   └── config/               # 設定ファイル
├── frontend/
│   └── next-app/loghoi/      # Next.jsアプリケーション
├── shared/
│   └── gateways/             # 共通Gateway（Elasticsearch、Prism API）
├── k8s/                      # Kubernetes マニフェスト
├── config/.ssh/              # SSH鍵（永続化）
├── scripts/                  # ユーティリティスクリプト
└── docs/archive/             # 過去ドキュメント
```

## 🔑 主要機能

### 1. PC/クラスター登録
- Prism Central APIで情報取得
- Elasticsearchに保存
- SSH公開鍵の自動生成・表示

### 2. リアルタイムログ
- CVMのログファイルをリアルタイム表示
- 複数ログファイル対応
- フィルタリング機能

### 3. Syslog検索
- Elasticsearchでの高度な検索
- クラスター自動判別
- 時間範囲指定

### 4. ログ収集
- CVMからログファイルを収集
- ZIP圧縮・ダウンロード
- リアルタイム進捗表示

### 5. UUID Explorer
- Nutanix UUIDの検索
- 関連エンティティ表示
- 履歴管理

## 🔧 開発ガイド

### 環境構築

```bash
# docker-compose起動
docker-compose -f docker-compose.yml up -d --build

# SSH鍵の確認（自動生成される）
cat config/.ssh/loghoi-key.pub
```

### SSH鍵の登録

1. UIの「Open SSH KEY」ボタンをクリック
2. 表示された公開鍵をコピー
3. Prism Element > Settings > Cluster Lockdown
4. 「Add Public Key」で公開鍵を登録

詳細は[SSH_KEY_MANAGEMENT_SPEC.md](./docs/SSH_KEY_MANAGEMENT_SPEC.md)を参照。

### API仕様

バックエンドAPIドキュメント:
```
http://localhost:7776/docs
```

## 🔒 セキュリティ

- SSH秘密鍵は`.gitignore`で除外
- 環境変数で機密情報を管理
- Kubernetes Secretで鍵を管理

## 📖 関連リンク

- [ブログ: Nutanixログほいほい](https://konchangakita.hatenablog.com/)
- [GitHub 開発ブログ リポジトリ](https://github.com/konchangakita/blog-loghoi)

## 🙋 トラブルシューティング

### SSH接続エラー
→ [SSH_KEY_MANAGEMENT_SPEC.md](./docs/SSH_KEY_MANAGEMENT_SPEC.md) のトラブルシューティングセクションを参照

### Elasticsearch接続エラー
→ docker-composeでElasticsearchが起動しているか確認

### フロントエンドが起動しない
→ `yarn install`を実行してから再起動

## 📜 ライセンス

このプロジェクトは個人のブログ記事用のサンプルコードです。

本プロジェクトは [MIT License](LICENSE) の下で公開されています。

Copyright (c) 2024 konchangakita


