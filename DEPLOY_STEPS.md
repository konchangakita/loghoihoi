# デプロイ手順

## 現在の状況

### ビルド済みイメージ
- ✅ `ghcr.io/konchangakita/loghoi-backend:v1.1.2` (ローカル)
- ✅ `ghcr.io/konchangakita/loghoi-frontend:v1.1.2` (ローカル)
- ✅ `ghcr.io/konchangakita/loghoi-syslog:v1.1.2` (ローカル)

### 既存のデプロイメント
- Helmリリース: `loghoihoi` (v1.1.1)
- Namespace: `loghoihoi`

## デプロイ手順

### 1. イメージのプッシュ（認証が必要）

```bash
# GitHub Container Registryへの認証
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# または、Personal Access Tokenを使用
docker login ghcr.io -u konchangakita -p <TOKEN>

# イメージのプッシュ
cd /home/nutanix/konchangakita/loghoihoi
VERSION=v1.1.2 PUSH_IMAGES=true bash k8s/build-and-push.sh
```

### 2. クリーンアップ（既存デプロイメントの削除）

```bash
export KUBECONFIG=/home/nutanix/nkp/kon-hoihoi.conf

# Helmリリースのアンインストール
helm uninstall loghoihoi -n loghoihoi

# 必要に応じて、PVCやPVも削除（データを保持したい場合はスキップ）
kubectl delete pvc -n loghoihoi --all
kubectl delete pv --selector=app=loghoi

# Secretも削除（新しい鍵を生成する場合）
kubectl delete secret loghoi-secrets -n loghoihoi
```

### 3. 新しいバージョンでデプロイ

#### オプションA: Helm Chartを使用（推奨）

```bash
export KUBECONFIG=/home/nutanix/nkp/kon-hoihoi.conf

# SSH鍵を生成（まだない場合）
cd /home/nutanix/konchangakita/loghoihoi
./helm/loghoihoi/scripts/create-ssh-secret.sh

# または、Web UIで自動生成されるので、Secret作成はスキップ可能

# Helm Chartでデプロイ
helm install loghoihoi ./helm/loghoihoi \
  --namespace loghoihoi \
  --create-namespace \
  --set storageClass=nutanix-volume
```

#### オプションB: 既存のdeploy.shを使用

```bash
export KUBECONFIG=/home/nutanix/nkp/kon-hoihoi.conf
cd /home/nutanix/konchangakita/loghoihoi/k8s
./deploy.sh
```

### 4. デプロイ状態の確認

```bash
export KUBECONFIG=/home/nutanix/nkp/kon-hoihoi.conf

# Podの状態確認
kubectl get pods -n loghoihoi

# ログ確認
kubectl logs -n loghoihoi -l app=loghoi,component=backend --tail=50
kubectl logs -n loghoihoi -l app=loghoi,component=frontend --tail=50

# サービス確認
kubectl get svc -n loghoihoi
kubectl get ingress -n loghoihoi
```

### 5. 動作確認

1. **フロントエンドにアクセス**
   - Ingress経由でアクセス
   - または、Port Forwardでアクセス:
     ```bash
     kubectl port-forward -n loghoihoi svc/loghoi-frontend 7777:7777
     ```
   - ブラウザで `http://localhost:7777` にアクセス

2. **SSH鍵セットアップの確認**
   - 初回アクセス時に「SSH鍵を生成しています（初回のみ）...」が表示される
   - 数秒後に通常のトップ画面に遷移
   - バックエンドのログで鍵生成を確認:
     ```bash
     kubectl logs -n loghoihoi -l app=loghoi,component=backend | grep -i ssh
     ```

3. **APIの直接確認**
   ```bash
   kubectl port-forward -n loghoihoi svc/loghoi-backend 7776:7776
   curl http://localhost:7776/api/ssh-key/setup
   ```

## トラブルシューティング

### イメージのプルエラー

```bash
# イメージが存在するか確認
docker pull ghcr.io/konchangakita/loghoi-backend:v1.1.2

# 認証を確認
docker login ghcr.io
```

### Podが起動しない

```bash
# Podの詳細を確認
kubectl describe pod -n loghoihoi <pod-name>

# イベントを確認
kubectl get events -n loghoihoi --sort-by='.lastTimestamp'
```

### SSH鍵の生成エラー

```bash
# バックエンドのログを確認
kubectl logs -n loghoihoi -l app=loghoi,component=backend | grep -i "ssh\|key"

# Secretの確認
kubectl get secret loghoi-secrets -n loghoihoi -o yaml
```

