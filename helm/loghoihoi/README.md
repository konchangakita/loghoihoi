# LogHoihoi Helm Chart

Nutanixログほいほい - ログ収集・分析システムのHelm Chart

## クイックスタート

### 方法A: 自動インストールスクリプトを使用（推奨）

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

### 方法B: 手動でインストールする場合

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

#### 方法B-2: ヘルパースクリプトを使用する場合

```bash
# SSH鍵を自動生成または既存の鍵を使用
export KUBECONFIG=/path/to/kubeconfig.conf
./helm/loghoihoi/scripts/create-ssh-secret.sh
```

**注意**: SSH鍵がroot所有の場合、スクリプトが読み取れない可能性があります。その場合は、方法Aを使用してください。

#### 方法B-3: 新規にSSH鍵を生成する場合

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
helm install loghoihoi ./helm/loghoihoi --namespace loghoihoi
```

#### カスタムStorageClass使用（本番環境向け）

```bash
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

詳細は `values.yaml` を参照してください。

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

