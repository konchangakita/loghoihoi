# 完全クリーンアップ・デプロイ・動作確認手順

## 前提条件

```bash
export KUBECONFIG=/home/nutanix/nkp/kon-hoihoi.conf
cd /home/nutanix/konchangakita/loghoihoi
```

## Step 1: 完全クリーンアップ

```bash
# Namespace内のリソースをすべて削除
kubectl delete namespace loghoihoi --wait=true --timeout=300s

# Namespaceが完全に削除されるまで待機
while kubectl get namespace loghoihoi &>/dev/null; do
  echo "Namespace削除待機中..."
  sleep 5
done
echo "✓ Namespace削除完了"

# PVCが残っている場合は手動で削除（必要に応じて）
# kubectl get pvc -A | grep loghoi
# kubectl delete pvc <pvc-name> -n <namespace>
```

## Step 2: デプロイ

```bash
# Helm Chartでデプロイ（Namespaceは自動作成される）
helm install loghoihoi ./helm/loghoihoi \
  --wait \
  --timeout=10m
```

**注意**: `-n loghoihoi`と`--create-namespace`オプションは不要です。Helm Chartの`templates/namespace.yaml`により、`loghoihoi` Namespaceが自動的に作成されます。

**オプション: 別のNamespaceを使用する場合**:

```bash
helm install loghoihoi ./helm/loghoihoi \
  --set namespace=my-custom-namespace \
  --wait \
  --timeout=10m
```

## Step 3: デプロイ状態の確認

```bash
# Podの状態確認
echo "=== Pod Status ==="
kubectl get pods -n loghoihoi

# すべてのPodがRunningになるまで待機
echo "=== Pod起動待機中 ==="
kubectl wait --for=condition=ready pod \
  -l app=loghoi \
  -n loghoihoi \
  --timeout=300s

# デプロイメントの状態確認
echo "=== Deployment Status ==="
kubectl get deployments -n loghoihoi

# サービスの状態確認
echo "=== Service Status ==="
kubectl get services -n loghoihoi

# PVCの状態確認
echo "=== PVC Status ==="
kubectl get pvc -n loghoihoi
```

## Step 4: SSH鍵ディレクトリの確認

```bash
# バックエンドPod名を取得
POD_NAME=$(kubectl get pod -n loghoihoi -l app=loghoi,component=backend -o jsonpath='{.items[0].metadata.name}')

# SSH鍵ディレクトリの存在確認
echo "=== SSH鍵ディレクトリ確認 ==="
kubectl exec -n loghoihoi $POD_NAME -- ls -la /app/output/.ssh/ 2>&1 || echo "ディレクトリがまだ作成されていません（初回アクセス時に作成されます）"

# ディレクトリの権限確認
kubectl exec -n loghoihoi $POD_NAME -- stat -c "%a %n" /app/output/.ssh/ 2>&1 || echo "ディレクトリがまだ作成されていません"
```

## Step 5: Web UIアクセスとSSH鍵生成確認

```bash
# バックエンドサービスのポートフォワード（一時的）
kubectl port-forward -n loghoihoi svc/loghoi-backend-service 7776:7776 > /dev/null 2>&1 &
PORT_FORWARD_PID=$!
sleep 2

# SSH鍵セットアップAPIの呼び出し
echo "=== SSH鍵セットアップAPI呼び出し ==="
curl -s http://localhost:7776/api/ssh-key/setup | python3 -m json.tool

# ポートフォワードを停止
kill $PORT_FORWARD_PID 2>/dev/null
```

## Step 6: SSH鍵の生成確認

```bash
# バックエンドPod名を取得
POD_NAME=$(kubectl get pod -n loghoihoi -l app=loghoi,component=backend -o jsonpath='{.items[0].metadata.name}')

# SSH鍵ファイルの確認
echo "=== SSH鍵ファイル確認 ==="
kubectl exec -n loghoihoi $POD_NAME -- ls -la /app/output/.ssh/

# 公開鍵の内容確認
echo "=== 公開鍵の内容 ==="
kubectl exec -n loghoihoi $POD_NAME -- cat /app/output/.ssh/ntnx-lockdown.pub 2>&1

# 秘密鍵の権限確認
echo "=== 秘密鍵の権限 ==="
kubectl exec -n loghoihoi $POD_NAME -- stat -c "%a %n" /app/output/.ssh/ntnx-lockdown 2>&1
```

## Step 7: 永続化の確認（Pod再起動テスト）

```bash
# バックエンドPod名を取得
POD_NAME=$(kubectl get pod -n loghoihoi -l app=loghoi,component=backend -o jsonpath='{.items[0].metadata.name}')

# 現在の公開鍵を保存
echo "=== 再起動前の公開鍵 ==="
BEFORE_KEY=$(kubectl exec -n loghoihoi $POD_NAME -- cat /app/output/.ssh/ntnx-lockdown.pub 2>&1)
echo "$BEFORE_KEY"

# Podを再起動
echo "=== Pod再起動 ==="
kubectl rollout restart deployment/loghoi-backend -n loghoihoi

# Podの再起動完了を待機
kubectl rollout status deployment/loghoi-backend -n loghoihoi --timeout=300s

# 新しいPod名を取得
sleep 5
NEW_POD_NAME=$(kubectl get pod -n loghoihoi -l app=loghoi,component=backend -o jsonpath='{.items[0].metadata.name}')

# 再起動後の公開鍵を確認
echo "=== 再起動後の公開鍵 ==="
AFTER_KEY=$(kubectl exec -n loghoihoi $NEW_POD_NAME -- cat /app/output/.ssh/ntnx-lockdown.pub 2>&1)
echo "$AFTER_KEY"

# 比較
if [ "$BEFORE_KEY" = "$AFTER_KEY" ]; then
  echo "✅ 永続化確認: 鍵が保持されています"
else
  echo "❌ 永続化確認: 鍵が失われています"
fi
```

## Step 8: 環境変数の確認

```bash
# バックエンドPod名を取得
POD_NAME=$(kubectl get pod -n loghoihoi -l app=loghoi,component=backend -o jsonpath='{.items[0].metadata.name}')

# SSH_KEY_PATH環境変数の確認
echo "=== SSH_KEY_PATH環境変数 ==="
kubectl exec -n loghoihoi $POD_NAME -- env | grep SSH_KEY_PATH

# SSH_PUBLIC_KEY_PATH環境変数の確認
echo "=== SSH_PUBLIC_KEY_PATH環境変数 ==="
kubectl exec -n loghoihoi $POD_NAME -- env | grep SSH_PUBLIC_KEY_PATH
```

## Step 9: ログの確認

```bash
# バックエンドPod名を取得
POD_NAME=$(kubectl get pod -n loghoihoi -l app=loghoi,component=backend -o jsonpath='{.items[0].metadata.name}')

# バックエンドのログ確認（SSH鍵生成関連）
echo "=== バックエンドログ（SSH鍵関連） ==="
kubectl logs -n loghoihoi $POD_NAME | grep -i "ssh\|鍵" | tail -20
```

## トラブルシューティング

### Podが起動しない場合

```bash
# Podの詳細確認
kubectl describe pod -n loghoihoi -l app=loghoi,component=backend

# Podのログ確認
kubectl logs -n loghoihoi -l app=loghoi,component=backend --tail=50
```

### PVCが作成されない場合

```bash
# StorageClassの確認
kubectl get storageclass

# PVCの詳細確認
kubectl describe pvc -n loghoihoi
```

### SSH鍵が生成されない場合

```bash
# バックエンドPod名を取得
POD_NAME=$(kubectl get pod -n loghoihoi -l app=loghoi,component=backend -o jsonpath='{.items[0].metadata.name}')

# ディレクトリの確認
kubectl exec -n loghoihoi $POD_NAME -- ls -la /app/output/

# 権限の確認
kubectl exec -n loghoihoi $POD_NAME -- stat -c "%a %n" /app/output/.ssh/
```

## まとめ

上記の手順で以下を確認できます：

1. ✅ 完全クリーンアップ
2. ✅ デプロイ
3. ✅ SSH鍵ディレクトリの作成
4. ✅ SSH鍵の生成
5. ✅ 永続化（Pod再起動後も保持）
6. ✅ 環境変数の設定

