# Helm Chart インストールガイド

## 概要

このガイドでは、Helm Chartを使用してLogHoihoi（Nutanixログほいほい）をKubernetes環境にインストールする手順を説明します。

### 特徴

- ✅ **Namespace自動作成**: Helm Chartが自動的に`loghoihoi` Namespaceを作成します
- ✅ **SSH鍵自動生成**: Web UIから初回アクセス時にSSH鍵が自動生成されます
- ✅ **PV永続化**: SSH鍵はPersistent Volumeに保存され、Pod再起動後も保持されます

---

## 前提条件

```bash
export KUBECONFIG=/home/nutanix/nkp/kon-hoihoi.conf
cd /home/nutanix/konchangakita/loghoihoi
```

### 必要なツール

- `kubectl`: Kubernetesクラスタへのアクセス
- `helm`: Helm Chartのインストール（v3以上）

---

## 1. クリーンアップ（既存インストールがある場合）

### 完全クリーンアップ（Namespaceごと削除）

```bash
# Helmリリースを削除（default Namespaceに存在する場合）
helm uninstall loghoihoi 2>/dev/null || echo "Helmリリースが見つかりません"

# Namespaceごと削除（すべてのリソースが削除される）
kubectl delete namespace loghoihoi --wait=true --timeout=300s

# Namespaceが完全に削除されるまで待機
while kubectl get namespace loghoihoi &>/dev/null 2>&1; do
  echo "Namespace削除待機中..."
  sleep 5
done
echo "✓ Namespace削除完了"
```

### 部分クリーンアップ（Namespaceは残す）

```bash
# Helmリリースを削除
helm uninstall loghoihoi -n loghoihoi 2>/dev/null || helm uninstall loghoihoi 2>/dev/null

# 特定のリソースのみ削除
kubectl delete deployment -n loghoihoi --all
kubectl delete service -n loghoihoi --all
kubectl delete ingress -n loghoihoi --all
kubectl delete pvc -n loghoihoi --all
```

---

## 2. インストール

### デフォルトインストール（loghoihoi Namespace）

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

---

## 3. インストール確認

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

### PodがReadyになるまで待機

```bash
# すべてのPodがReadyになるまで待機
kubectl wait --for=condition=ready pod \
  -l app=loghoi \
  -n loghoihoi \
  --timeout=300s
```

### デプロイメントの状態確認

```bash
# デプロイメントの状態確認
kubectl get deployments -n loghoihoi

# 期待される出力（すべてAvailable）:
# NAME              READY   UP-TO-DATE   AVAILABLE   AGE
# elasticsearch     1/1     1            1           XXs
# kibana            1/1     1            1           XXs
# loghoi-backend    1/1     1            1           XXs
# loghoi-frontend   1/1     1            1           XXs
# loghoi-syslog     1/1     1            1           XXs
```

### サービスの状態確認

```bash
# サービスの状態確認
kubectl get services -n loghoihoi
```

### PVCの状態確認

```bash
# PVCの状態確認
kubectl get pvc -n loghoihoi

# 期待される出力（すべてBound）:
# NAME                      STATUS   VOLUME                                     CAPACITY   STORAGECLASS     AGE
# elasticsearch-data        Bound    pvc-xxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx        10Gi       nutanix-volume   XXs
# loghoi-backend-output     Bound    pvc-xxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx        10Gi       nutanix-volume   XXs
```

### Helmリリースの状態確認

```bash
# Helmリリースの状態確認
helm status loghoihoi -n loghoihoi 2>/dev/null || helm status loghoihoi

# 期待される出力:
# NAME: loghoihoi
# STATUS: deployed
# REVISION: 1
```

---

## 4. アクセスURLの確認

### Ingress IPアドレスの取得

```bash
# Ingress IPアドレスを取得
INGRESS_IP=$(kubectl get ingress -n loghoihoi -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')

# IPアドレスを表示
echo "Ingress IP: ${INGRESS_IP}"
```

### すべてのアクセスURLを一括表示

```bash
# Ingress IPを取得
INGRESS_IP=$(kubectl get ingress -n loghoihoi -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')

# すべてのURLを表示
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 WebブラウザでアクセスするURL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "フロントエンド:     http://${INGRESS_IP}/"
echo "バックエンドAPI:    http://${INGRESS_IP}/api/"
echo "API ドキュメント:   http://${INGRESS_IP}/docs"
echo "API ドキュメント:   http://${INGRESS_IP}/redoc"
echo "Kibana:            http://${INGRESS_IP}/kibana"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

### API ドキュメントのURL

```bash
# Ingress IPを取得
INGRESS_IP=$(kubectl get ingress -n loghoihoi -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')

# Swagger UI (docs)
echo "Swagger UI: http://${INGRESS_IP}/docs"

# ReDoc
echo "ReDoc: http://${INGRESS_IP}/redoc"

# OpenAPI JSON
echo "OpenAPI JSON: http://${INGRESS_IP}/openapi.json"
```

---

## 5. SSH鍵の確認

### SSH鍵ディレクトリの確認

```bash
# バックエンドPod名を取得
POD_NAME=$(kubectl get pod -n loghoihoi -l app=loghoi,component=backend -o jsonpath='{.items[0].metadata.name}')

# SSH鍵ディレクトリの存在確認
kubectl exec -n loghoihoi $POD_NAME -- ls -la /app/output/.ssh/
```

### SSH鍵ファイルの確認

```bash
# バックエンドPod名を取得
POD_NAME=$(kubectl get pod -n loghoihoi -l app=loghoi,component=backend -o jsonpath='{.items[0].metadata.name}')

# 秘密鍵の存在確認
kubectl exec -n loghoihoi $POD_NAME -- test -f /app/output/.ssh/ntnx-lockdown && echo "✓ 秘密鍵が存在します" || echo "✗ 秘密鍵が存在しません"

# 公開鍵の存在確認
kubectl exec -n loghoihoi $POD_NAME -- test -f /app/output/.ssh/ntnx-lockdown.pub && echo "✓ 公開鍵が存在します" || echo "✗ 公開鍵が存在しません"
```

### 公開鍵の内容確認

```bash
# バックエンドPod名を取得
POD_NAME=$(kubectl get pod -n loghoihoi -l app=loghoi,component=backend -o jsonpath='{.items[0].metadata.name}')

# 公開鍵の内容を表示
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 SSH公開鍵"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl exec -n loghoihoi $POD_NAME -- cat /app/output/.ssh/ntnx-lockdown.pub 2>&1
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

### 鍵の権限確認

```bash
# バックエンドPod名を取得
POD_NAME=$(kubectl get pod -n loghoihoi -l app=loghoi,component=backend -o jsonpath='{.items[0].metadata.name}')

# ディレクトリの権限確認
kubectl exec -n loghoihoi $POD_NAME -- stat -c "%a %n" /app/output/.ssh/

# 秘密鍵の権限確認
kubectl exec -n loghoihoi $POD_NAME -- stat -c "%a %n" /app/output/.ssh/ntnx-lockdown 2>&1

# 公開鍵の権限確認
kubectl exec -n loghoihoi $POD_NAME -- stat -c "%a %n" /app/output/.ssh/ntnx-lockdown.pub 2>&1
```

### SSH鍵セットアップAPIの確認

```bash
# バックエンドサービスのポートフォワード（一時的）
kubectl port-forward -n loghoihoi svc/loghoi-backend-service 7776:7776 > /dev/null 2>&1 &
PORT_FORWARD_PID=$!
sleep 2

# SSH鍵セットアップAPIを呼び出し
curl -s http://localhost:7776/api/ssh-key/setup | python3 -m json.tool

# ポートフォワードを停止
kill $PORT_FORWARD_PID 2>/dev/null
```

### 環境変数の確認

```bash
# バックエンドPod名を取得
POD_NAME=$(kubectl get pod -n loghoihoi -l app=loghoi,component=backend -o jsonpath='{.items[0].metadata.name}')

# SSH_KEY_PATH環境変数の確認
kubectl exec -n loghoihoi $POD_NAME -- env | grep SSH_KEY_PATH

# SSH_PUBLIC_KEY_PATH環境変数の確認
kubectl exec -n loghoihoi $POD_NAME -- env | grep SSH_PUBLIC_KEY_PATH
```

### 永続化の確認（Pod再起動テスト）

```bash
# バックエンドPod名を取得
POD_NAME=$(kubectl get pod -n loghoihoi -l app=loghoi,component=backend -o jsonpath='{.items[0].metadata.name}')

# 再起動前の公開鍵を保存
BEFORE_KEY=$(kubectl exec -n loghoihoi $POD_NAME -- cat /app/output/.ssh/ntnx-lockdown.pub 2>&1)
echo "再起動前の公開鍵:"
echo "$BEFORE_KEY"
echo ""

# Podを再起動
kubectl rollout restart deployment/loghoi-backend -n loghoihoi

# Podの再起動完了を待機
kubectl rollout status deployment/loghoi-backend -n loghoihoi --timeout=300s

# 新しいPod名を取得
sleep 5
NEW_POD_NAME=$(kubectl get pod -n loghoihoi -l app=loghoi,component=backend -o jsonpath='{.items[0].metadata.name}')

# 再起動後の公開鍵を確認
AFTER_KEY=$(kubectl exec -n loghoihoi $NEW_POD_NAME -- cat /app/output/.ssh/ntnx-lockdown.pub 2>&1)
echo "再起動後の公開鍵:"
echo "$AFTER_KEY"
echo ""

# 比較
if [ "$BEFORE_KEY" = "$AFTER_KEY" ]; then
  echo "✅ 永続化確認: 鍵が保持されています"
else
  echo "❌ 永続化確認: 鍵が失われています"
fi
```

---

## 6. トラブルシューティング

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

---

## 7. アップグレード

既存のインストールをアップグレードする場合:

```bash
# Helm Chartをアップグレード
helm upgrade loghoihoi ./helm/loghoihoi --wait --timeout=10m

# アップグレード状態の確認
helm status loghoihoi -n loghoihoi 2>/dev/null || helm status loghoihoi
```

---

## 8. アンインストール

```bash
# Helmリリースを削除
helm uninstall loghoihoi -n loghoihoi 2>/dev/null || helm uninstall loghoihoi 2>/dev/null

# Namespaceごと削除（すべてのリソースが削除される）
kubectl delete namespace loghoihoi --wait=true --timeout=300s
```

**注意**: Namespaceを削除すると、PVCも削除されます。データを保持したい場合は、事前にバックアップを取得してください。

---

## まとめ

このガイドで以下を確認できます：

1. ✅ 完全クリーンアップ
2. ✅ Helm Chartでのインストール
3. ✅ インストール状態の確認
4. ✅ アクセスURLの確認
5. ✅ SSH鍵の生成と確認
6. ✅ 永続化の確認（Pod再起動後も保持）
7. ✅ トラブルシューティング

---

## 関連ドキュメント

- [Kubernetesデプロイメントガイド](./k8s/DEPLOYMENT_GUIDE.md) - kubectlを使用した手動デプロイ手順
- [SSH鍵管理機能仕様](./docs/SSH_KEY_MANAGEMENT_SPEC.md) - SSH鍵管理の詳細仕様

