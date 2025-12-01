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

### 自動生成（推奨）

デフォルトでは、Web UIに初回アクセス時にSSH鍵が自動生成されます：

1. フロントエンドにアクセス
2. 初回アクセス時に「SSH鍵を生成しています（初回のみ）」と表示
3. 生成完了後、通常のトップ画面に遷移
4. SSH鍵は`/app/output/.ssh/ntnx-lockdown`に保存され、PVに永続化されます

### 既存のSSH鍵を使用する場合（オプション）

既存のSSH鍵をSecretとして使用したい場合：

```bash
# 1. SSH鍵をbase64エンコード
PRIVATE_KEY_B64=$(cat config/.ssh/loghoi-key | base64 -w 0)
PUBLIC_KEY_B64=$(cat config/.ssh/loghoi-key.pub | base64 -w 0)

# 2. Helmでインストール（Secretも自動作成）
helm install loghoihoi ./helm/loghoihoi \
  --set sshKeys.create=true \
  --set sshKeys.privateKey="${PRIVATE_KEY_B64}" \
  --set sshKeys.publicKey="${PUBLIC_KEY_B64}" \
  --wait \
  --timeout=10m
```

**注意**: Secretを使用する場合でも、Web UIでの自動生成機能は引き続き動作します。

## インストール確認

### Podの状態確認

```bash
# すべてのPodの状態を確認
kubectl get pods -n loghoihoi

# 期待される出力（すべてRunning）:
# NAME                               READY   STATUS    RESTARTS   AGE
# elasticsearch-xxxx                 1/1     Running   0          XXs
# kibana-xxxx                        1/1     Running   0          XXs
# loghoi-backend-xxxx                1/1     Running   0          XXs
# loghoi-frontend-xxxx               1/1     Running   0          XXs
# loghoi-syslog-xxxx                 1/1     Running   0          XXs
```

### アクセスURLの確認

```bash
# Ingress IPを取得
INGRESS_IP=$(kubectl get ingress -n loghoihoi -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')

# すべてのURLを表示
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 WebブラウザでアクセスするURL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "フロントエンド:     https://${INGRESS_IP}/"
echo "API ドキュメント:   https://${INGRESS_IP}/docs"
echo "API ドキュメント:   https://${INGRESS_IP}/redoc"
echo "Kibana:            https://${INGRESS_IP}/kibana"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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
helm uninstall loghoihoi -n loghoihoi 2>/dev/null || helm uninstall loghoihoi 2>/dev/null

# Namespaceごと削除（すべてのリソースが削除される）
kubectl delete namespace loghoihoi --wait=true --timeout=300s
```

**注意**: Namespaceを削除すると、PVCも削除されます。データを保持したい場合は、事前にバックアップを取得してください。

## トラブルシューティング

### Podが起動しない場合

```bash
# Podの詳細情報を確認
kubectl describe pod -n loghoihoi <pod-name>

# Podのログを確認
kubectl logs -n loghoihoi <pod-name> --tail=50
```

### Ingress IPが取得できない場合

```bash
# Ingressの状態を確認
kubectl get ingress -n loghoihoi -o yaml

# Ingress Controllerが動作しているか確認
kubectl get pods -n hoihoi-workspace-vgpxm-f4ff6 -l app.kubernetes.io/name=traefik
```

### SSH鍵が生成されない場合

```bash
# バックエンドPod名を取得
POD_NAME=$(kubectl get pod -n loghoihoi -l app=loghoi,component=backend -o jsonpath='{.items[0].metadata.name}')

# バックエンドのログを確認
kubectl logs -n loghoihoi $POD_NAME | grep -i "ssh\|鍵"

# ディレクトリの確認
kubectl exec -n loghoihoi $POD_NAME -- ls -la /app/output/

# 権限の確認
kubectl exec -n loghoihoi $POD_NAME -- stat -c "%a %n" /app/output/.ssh/
```

### PVCが作成されない場合

```bash
# StorageClassの確認
kubectl get storageclass

# PVCの詳細確認
kubectl describe pvc -n loghoihoi
```

## 参考資料

- [Helm Chart インストールガイド](../../HELM_INSTALLATION_GUIDE.md) - 詳細なインストール手順とトラブルシューティング
- [Kubernetesデプロイメントガイド](../../k8s/DEPLOYMENT_GUIDE.md) - kubectlを使用した手動デプロイ手順
- [SSH鍵管理機能仕様](../../docs/SSH_KEY_MANAGEMENT_SPEC.md) - SSH鍵管理の詳細仕様
