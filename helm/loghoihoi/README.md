# LogHoihoi Helm Chart

Nutanixログほいほい - ログ収集・分析システムのHelm Chart

## 概要

このHelm Chartを使用してLogHoihoiをKubernetes環境にインストールできます。

### 特徴

- ✅ **Namespace自動作成**: Helm Chartが自動的に`loghoihoi` Namespaceを作成します
- ✅ **SSH鍵自動生成**: Web UIから初回アクセス時にSSH鍵が自動生成されます
- ✅ **PV永続化**: SSH鍵はPersistent Volumeに保存され、Pod再起動後も保持されます

## クイックスタート

### デフォルトインストール（推奨）

```bash
# Helm Chartでインストール（Namespaceは自動作成される）
helm install loghoihoi ./helm/loghoihoi --wait --timeout=10m
```

**注意**: `-n loghoihoi`や`--create-namespace`オプションは不要です。Helm Chartの`templates/namespace.yaml`により、`loghoihoi` Namespaceが自動的に作成されます。

### カスタムNamespaceを使用する場合

```bash
# 別のNamespaceを使用する場合
helm install loghoihoi ./helm/loghoihoi \
  --set namespace=my-custom-namespace \
  --wait \
  --timeout=10m
```

この場合、`my-custom-namespace`が自動作成されます。

### カスタムStorageClassを使用する場合

```bash
# カスタムStorageClassを指定
helm install loghoihoi ./helm/loghoihoi \
  --set storageClass=nutanix-volume \
  --wait \
  --timeout=10m
```

## SSH鍵について

デフォルトでは、Web UIに初回アクセス時にSSH鍵が自動生成されます：

1. フロントエンドにアクセス
2. 初回アクセス時に「SSH鍵を生成しています（初回のみ）」と表示
3. 生成完了後、通常のトップ画面に遷移
4. SSH鍵は`/app/output/.ssh/ntnx-lockdown`に保存され、PVに永続化されます

## 設定値

主要な設定値は `values.yaml` で定義されています：

- `storageClass`: ストレージクラス（デフォルト: `manual` = HostPath）
- `namespace`: 名前空間（デフォルト: `loghoihoi`）
- `image.backend.repository`: バックエンドイメージリポジトリ
- `image.backend.tag`: バックエンドイメージタグ
- `image.frontend.repository`: フロントエンドイメージリポジトリ
- `image.frontend.tag`: フロントエンドイメージタグ
- `ingress.enabled`: Ingressの有効化
- `ingress.className`: Ingressクラス名
- `sshKeys.create`: Secretを作成するか（デフォルト: `false`）
- `sshKeys.privateKey`: base64エンコードされた秘密鍵
- `sshKeys.publicKey`: base64エンコードされた公開鍵

詳細は `values.yaml` を参照してください。

## アップグレード

既存のインストールをアップグレードする場合:

```bash
# Helm Chartをアップグレード
helm upgrade loghoihoi ./helm/loghoihoi --wait --timeout=10m

# アップグレード状態の確認
helm status loghoihoi -n loghoihoi 2>/dev/null || helm status loghoihoi
```

## アンインストール

```bash
# Helmリリースを削除
helm uninstall loghoihoi

# Namespace状態確認
kubectl get namespace

# Namespace残っていれば、Namespaceごと削除（すべてのリソースが削除される）
kubectl delete namespace loghoihoi --wait=true --timeout=300s
```

**注意**: Namespaceを削除すると、PVCも削除されます。データを保持したい場合は、事前にバックアップを取得してください。

## 詳細なインストール手順

詳細なインストール手順、確認方法、トラブルシューティングについては、[インストールガイド](./INSTALLATION_GUIDE.md)を参照してください。

## 参考資料

- [Kubernetesデプロイメントガイド](../../k8s/DEPLOYMENT_GUIDE.md) - kubectlを使用した手動デプロイ手順
- [SSH鍵管理機能仕様](../../docs/SSH_KEY_MANAGEMENT_SPEC.md) - SSH鍵管理の詳細仕様
