# LogHoihoi Helm Chart

Nutanixログほいほい - ログ収集・分析システムのHelm Chart

## クイックスタート

### 方法A: Helm単体でインストール（生成済み鍵を使用、推奨）

**前提条件**: SSH鍵が既に生成されていること

Helm単体で完結する方法です。NamespaceとSecretもHelmテンプレートで自動作成されます。

```bash
# 1. SSH鍵をbase64エンコード
PRIVATE_KEY_B64=$(cat config/.ssh/loghoi-key | base64 -w 0)
PUBLIC_KEY_B64=$(cat config/.ssh/loghoi-key.pub | base64 -w 0)

# 2. Helmでインストール（NamespaceとSecretも自動作成）
helm install loghoihoi ./helm/loghoihoi \
  --create-namespace \
  --namespace loghoihoi \
  --set sshKeys.create=true \
  --set sshKeys.privateKey="${PRIVATE_KEY_B64}" \
  --set sshKeys.publicKey="${PUBLIC_KEY_B64}" \
  --set storageClass=nutanix-volume
```

**この方法のメリット**:
- Helm単体で完結（追加スクリプト不要）
- NamespaceとSecretもHelmテンプレートで自動作成
- Helmパッケージ化後も同じ方法で使用可能

**注意**: 
- SSH鍵は事前に生成済みである必要があります
- 新規にSSH鍵を生成した場合、公開鍵をNutanix Prismに登録する必要があります

### 方法B: 自動インストールスクリプトを使用

SSH鍵の自動チェック・生成とHelm Chartのインストールを一度に実行します：

```bash
export KUBECONFIG=/path/to/kubeconfig.conf
./helm/loghoihoi/install.sh
```

このスクリプトは以下を自動的に実行します：
- SSH鍵の存在確認（なければ自動生成）
- SSH鍵の権限チェック
- Namespaceの作成
- Secretの作成
- Helm Chartのインストール

**注意**: 新規にSSH鍵を生成した場合、公開鍵をNutanix Prismに登録する必要があります。

### 方法C: 手動でインストールする場合

#### 1. SSH鍵のSecret作成（必須）

Helm Chartをインストールする前に、SSH鍵のSecretを作成する必要があります。

#### 方法B-1: 既存のSSH鍵を使用する場合

```bash
# SSH鍵のパスを指定してSecretを作成
kubectl create secret generic loghoi-secrets \
  --namespace=loghoihoi \
  --from-file=SSH_PRIVATE_KEY=/path/to/private/key \
  --from-file=SSH_PUBLIC_KEY=/path/to/public/key.pub
```

#### 方法B-2: 新規にSSH鍵を生成する場合

```bash
# SSH鍵を生成
ssh-keygen -t rsa -b 4096 \
  -f /tmp/loghoi-key \
  -N "" \
  -C "loghoi@kubernetes"

# Secretを作成
kubectl create secret generic loghoi-secrets \
  --namespace=loghoihoi \
  --from-file=SSH_PRIVATE_KEY=/tmp/loghoi-key \
  --from-file=SSH_PUBLIC_KEY=/tmp/loghoi-key.pub

# 公開鍵を表示（Nutanix Prismに登録）
cat /tmp/loghoi-key.pub
```

**重要**: 新規にSSH鍵を生成した場合、公開鍵をNutanix Prismに登録する必要があります：
1. Prism Element > Settings > Cluster Lockdown
2. 「Add Public Key」をクリック
3. 公開鍵を貼り付けて保存

#### 2. Helm Chartのインストール

#### HostPath使用（デフォルト、開発環境向け）

```bash
# Namespaceが存在しない場合は事前に作成
kubectl create namespace loghoihoi

helm install loghoihoi ./helm/loghoihoi --namespace loghoihoi
```

#### カスタムStorageClass使用（本番環境向け）

```bash
# Namespaceが存在しない場合は事前に作成
kubectl create namespace loghoihoi

helm install loghoihoi ./helm/loghoihoi \
  --namespace loghoihoi \
  --set storageClass=nutanix-volume
```

### 3. デプロイ状態の確認

```bash
kubectl get pods,pvc,svc,ingress -n loghoihoi
```

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

## Helmパッケージ化後の使用方法

Helm Chartをパッケージ化した後も、同じ方法でインストールできます：

```bash
# パッケージ化
helm package helm/loghoihoi

# パッケージからインストール（方法Aと同じ）
PRIVATE_KEY_B64=$(cat config/.ssh/loghoi-key | base64 -w 0)
PUBLIC_KEY_B64=$(cat config/.ssh/loghoi-key.pub | base64 -w 0)

helm install loghoihoi ./loghoihoi-0.1.0.tgz \
  --namespace loghoihoi \
  --set sshKeys.create=true \
  --set sshKeys.privateKey="${PRIVATE_KEY_B64}" \
  --set sshKeys.publicKey="${PUBLIC_KEY_B64}" \
  --set storageClass=nutanix-volume
```

## アンインストール

```bash
helm uninstall loghoihoi -n loghoihoi

# HostPath使用時は、PVも削除
kubectl delete pv elasticsearch-data-pv backend-output-pv
```

## トラブルシューティング

### SSH鍵のSecretが見つからない

```bash
# Secretの存在確認
kubectl get secret loghoi-secrets -n loghoihoi

# 存在しない場合は作成
kubectl create secret generic loghoi-secrets \
  --namespace=loghoihoi \
  --from-file=SSH_PRIVATE_KEY=/path/to/private/key \
  --from-file=SSH_PUBLIC_KEY=/path/to/public/key.pub
```

### PVCがPending状態

```bash
# PVCの状態確認
kubectl describe pvc -n loghoihoi

# HostPath使用時は、PVが作成されているか確認
kubectl get pv | grep loghoi
```

### Podが起動しない

```bash
# Podの状態確認
kubectl describe pod <pod-name> -n loghoihoi

# ログ確認
kubectl logs <pod-name> -n loghoihoi
```

## 参考資料

- [Kubernetesデプロイメントガイド](../../k8s/DEPLOYMENT_GUIDE.md)
- [Kubernetes仕様書](../../k8s/KUBERNETES_SPEC.md)

