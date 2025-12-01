# 手動デプロイ手順

## 前提条件

```bash
export KUBECONFIG=/home/nutanix/nkp/kon-hoihoi.conf
cd /home/nutanix/konchangakita/loghoihoi
```

---

## 1. クリーンアップコマンド

### 完全クリーンアップ（Namespaceごと削除）

```bash
# Helmリリースを削除（default Namespaceに存在する場合）
helm uninstall loghoihoi 2>/dev/null || echo "Helmリリースが見つかりません"

# Namespaceのこっていれば、削除（すべてのリソースが削除される）
kubectl get namespace
kubectl delete namespace loghoihoi --wait=true --timeout=300s
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

## 2. デプロイコマンド

```bash
# Helm Chartでデプロイ（Namespaceは自動作成される）
helm install loghoihoi ./helm/loghoihoi
```

---

## 3. デプロイ完了の確認コマンド

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

## 4. IngressのURL確認方法

### フロントエンドURLの確認

```bash
# Ingress IPを取得
INGRESS_IP=$(kubectl get ingress -n loghoihoi -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')

# フロントエンドURLを表示
echo "フロントエンドURL: http://${INGRESS_IP}/"
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

---

## 6. 鍵の状態確認

### SSH鍵ディレクトリの確認

```bash
# SSH鍵ディレクトリの存在確認
kubectl exec -n loghoihoi $(kubectl get pod -n loghoihoi -l app=loghoi,component=backend -o jsonpath='{.items[0].metadata.name}') -- ls -la /app/output/.ssh/
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

