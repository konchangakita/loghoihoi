# SSH鍵セットアップ自動化機能 デプロイ確認事項

## 1. コンテナイメージの更新について

### 開発環境（docker-compose）

**✅ イメージの再ビルドは不要**

理由：
- コードはボリュームマウントされているため、ホストの変更が即座に反映される
- バックエンド: `./backend/fastapi_app:/usr/src/fastapi_app:z` + `--reload` フラグ
- フロントエンド: `./frontend/next-app:/usr/src/next-app:z` + `yarn dev`

**動作確認方法**:
```bash
# docker-composeを再起動（既存コンテナを停止・起動）
docker-compose restart backend frontend

# または、完全に再起動
docker-compose down
docker-compose up -d
```

**注意事項**:
- バックエンドの `subprocess` モジュールと `ssh-keygen` コマンドは既に利用可能
  - `dockerfile` で `openssh-client` がインストール済み
  - Python標準ライブラリの `subprocess` は利用可能
- フロントエンドの `'use client'` ディレクティブはNext.js 13+でサポート済み

### 本番環境（Kubernetes）

**⚠️ イメージの再ビルドとプッシュが必要**

#### バックエンドイメージ
```bash
# イメージのビルド
cd /path/to/loghoihoi
docker build -t <registry>/loghoi-backend:<tag> -f backend/Dockerfile.k8s .

# イメージのプッシュ
docker push <registry>/loghoi-backend:<tag>

# Kubernetesデプロイメントの更新
# values.yamlまたはHelm Chartでイメージタグを更新
helm upgrade loghoihoi ./helm/loghoihoi --set image.backend.tag=<tag>
```

**確認事項**:
- ✅ `Dockerfile.k8s` で `ssh-client` がインストール済み（`apt-get install ssh-client`）
- ✅ Python標準ライブラリの `subprocess` は利用可能
- ✅ `stat` モジュールもPython標準ライブラリ

#### フロントエンドイメージ
```bash
# イメージのビルド
cd /path/to/loghoihoi/frontend/next-app/loghoi
docker build -t <registry>/loghoi-frontend:<tag> -f Dockerfile.k8s .

# イメージのプッシュ
docker push <registry>/loghoi-frontend:<tag>

# Kubernetesデプロイメントの更新
helm upgrade loghoihoi ./helm/loghoihoi --set image.frontend.tag=<tag>
```

**確認事項**:
- ✅ Next.js 13+ のApp Routerで `'use client'` ディレクティブはサポート済み
- ✅ `useState`, `useEffect` はReact標準フック

## 2. docker-compose検証環境での動作

### SSH鍵のパスとボリュームマウント

**設定内容**:
```yaml
# docker-compose.yml
backend:
  volumes:
    - ./config/.ssh:/app/config/.ssh:z  # SSH鍵ディレクトリ
  environment:
    - SSH_KEY_PATH=/app/config/.ssh/loghoi-key
```

**動作フロー**:

1. **初回起動時（鍵が存在しない場合）**:
   - バックエンドコンテナ内で `/app/config/.ssh/loghoi-key` に鍵を生成
   - ホストの `./config/.ssh/` ディレクトリに鍵ファイルが作成される
   - 権限: 秘密鍵 `600`, 公開鍵 `644`

2. **2回目以降（鍵が既に存在する場合）**:
   - 既存の鍵を読み込んで `status=exists` を返す
   - 鍵生成はスキップ

3. **フロントエンド**:
   - 起動時に `/api/ssh-key/setup` を呼び出す
   - ローディング表示（鍵生成中は「SSH鍵を生成しています（初回のみ）...」）
   - セットアップ完了後に通常のトップ画面を表示

### 検証手順

#### 1. クリーンな状態での検証（鍵が存在しない場合）

```bash
# 既存の鍵を削除（検証用）
rm -rf ./config/.ssh

# docker-composeを起動
docker-compose up -d

# バックエンドのログを確認
docker-compose logs -f backend

# フロントエンドにアクセス
# http://localhost:7777
# → ローディング表示が表示され、「SSH鍵を生成しています（初回のみ）...」が表示される
# → 数秒後に通常のトップ画面に遷移

# 鍵が生成されたか確認
ls -la ./config/.ssh/
# loghoi-key (600)
# loghoi-key.pub (644)
```

#### 2. 既存鍵がある場合の検証

```bash
# 鍵が既に存在する状態でdocker-composeを起動
docker-compose up -d

# フロントエンドにアクセス
# http://localhost:7777
# → ローディング表示が短時間表示される（鍵チェックのみ）
# → すぐに通常のトップ画面に遷移
```

#### 3. APIの直接確認

```bash
# バックエンドAPIを直接呼び出し
curl http://localhost:7776/api/ssh-key/setup

# レスポンス例（鍵が存在する場合）
{
  "status": "exists",
  "data": {
    "public_key": "ssh-rsa AAAAB3...",
    "message": "SSH鍵が既に存在します"
  }
}

# レスポンス例（鍵が生成された場合）
{
  "status": "generated",
  "data": {
    "public_key": "ssh-rsa AAAAB3...",
    "message": "SSH鍵を生成しました"
  }
}
```

### 注意事項

#### 1. ディレクトリの権限
- ホストの `./config/.ssh/` ディレクトリはコンテナから書き込み可能である必要がある
- 初回起動時にディレクトリが存在しない場合は、コンテナ内で自動作成される（`os.makedirs(key_dir, mode=0o700, exist_ok=True)`）

#### 2. ボリュームマウントの確認
- `docker-compose.yml` で `./config/.ssh:/app/config/.ssh:z` が設定されていることを確認
- SELinux環境では `:z` フラグが必要

#### 3. エラーハンドリング
- API呼び出しが失敗してもアプリは続行（既存の動作を維持）
- エラーはコンソールに出力される（開発時のデバッグ用）

## 3. Kubernetes環境での動作

### SSH鍵の保存場所

**設定内容**:
- 環境変数: `SSH_KEY_PATH=/app/config/.ssh/loghoi-key`（デフォルト）
- Kubernetes Secretからマウントされる場合: Secretのマウントパスに合わせて設定

### 動作フロー

1. **初回起動時（鍵が存在しない場合）**:
   - Pod内で `/app/config/.ssh/loghoi-key` に鍵を生成
   - 鍵はPodの一時ストレージに保存される
   - **注意**: Pod再起動時に鍵は失われる可能性がある

2. **既存鍵がある場合（Secretからマウント）**:
   - Secretからマウントされた鍵を使用
   - `status=exists` を返す

### 推奨される運用方法

#### オプション1: Secretからマウント（推奨）
```yaml
# Helm Chartのvalues.yaml
sshKeys:
  create: true
  existingSecret: loghoi-secrets
```

#### オプション2: 自動生成 + PVCで永続化（将来の拡張）
- 生成した鍵をPVCに保存
- Pod再起動時も鍵が保持される

## 4. トラブルシューティング

### 問題: 鍵が生成されない

**確認事項**:
1. `ssh-keygen` コマンドが利用可能か
   ```bash
   docker-compose exec backend which ssh-keygen
   # /usr/bin/ssh-keygen が表示されればOK
   ```

2. ディレクトリの書き込み権限
   ```bash
   docker-compose exec backend ls -la /app/config/.ssh/
   # ディレクトリが存在し、書き込み可能であることを確認
   ```

3. バックエンドのログを確認
   ```bash
   docker-compose logs backend | grep -i ssh
   ```

### 問題: フロントエンドでローディングが終わらない

**確認事項**:
1. バックエンドAPIが正常に応答しているか
   ```bash
   curl http://localhost:7776/api/ssh-key/setup
   ```

2. フロントエンドのコンソールエラーを確認
   - ブラウザの開発者ツール > Console
   - ネットワークタブで `/api/ssh-key/setup` のレスポンスを確認

3. CORSエラーの確認
   - バックエンドのCORS設定を確認

## 5. まとめ

### 開発環境（docker-compose）
- ✅ **イメージの再ビルド不要**（コードはボリュームマウント）
- ✅ `docker-compose restart` で変更が反映される
- ✅ SSH鍵はホストの `./config/.ssh/` に保存される

### 本番環境（Kubernetes）
- ⚠️ **イメージの再ビルドとプッシュが必要**
- ⚠️ デプロイメントの更新が必要
- ⚠️ SSH鍵の永続化方法を検討（Secretマウント推奨）

### 動作確認
- ✅ docker-compose環境で動作確認済み（想定）
- ⚠️ Kubernetes環境での動作確認は別途実施が必要

