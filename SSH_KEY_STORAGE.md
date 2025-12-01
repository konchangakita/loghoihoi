# SSH鍵の保存場所について

## 現在の実装

### 鍵の保存場所

#### 1. バックエンドAPIでの生成時

**保存パス**:
- 環境変数 `SSH_KEY_PATH` で指定（デフォルト: `/app/config/.ssh/loghoi-key`）
- Kubernetes環境: `/app/config/.ssh/ntnx-lockdown` (環境変数で設定)

**実装コード**:
```python
# backend/fastapi_app/app_fastapi.py
key_file = os.getenv("SSH_KEY_PATH", "/app/config/.ssh/loghoi-key")
pub_key_file = f"{key_file}.pub"
key_dir = os.path.dirname(key_file)

# ディレクトリ作成
os.makedirs(key_dir, mode=0o700, exist_ok=True)

# SSH鍵生成
subprocess.run([
    "ssh-keygen",
    "-t", "rsa",
    "-b", "4096",
    "-f", key_file,  # ← ここに保存
    "-N", "",
    "-C", "loghoi@kubernetes"
])
```

### 環境ごとの保存場所

#### Kubernetes環境

**現在の設定**:
```yaml
# helm/loghoihoi/templates/backend-deployment.yaml
env:
  - name: SSH_KEY_PATH
    value: "/app/config/.ssh/ntnx-lockdown"

volumeMounts:
  - name: ssh-keys
    mountPath: /app/config/.ssh
    readOnly: true  # ← 読み取り専用
```

**問題点**:
- `/app/config/.ssh/` はSecretからマウントされている（`readOnly: true`）
- Pod内で鍵を生成しても、**Pod再起動時に失われる**
- Secretからマウントされた鍵（`ntnx-lockdown`）が存在する場合は、それを使用

**実際の保存場所**:
- Pod内: `/app/config/.ssh/ntnx-lockdown` (Secretからマウント)
- または: `/app/config/.ssh/loghoi-key` (Pod内で生成、ただし永続化されない)

#### docker-compose環境

**現在の設定**:
```yaml
# docker-compose.yml
volumes:
  - ./config/.ssh:/app/config/.ssh:z  # ホストと共有

environment:
  - SSH_KEY_PATH=/app/config/.ssh/loghoi-key
```

**保存場所**:
- コンテナ内: `/app/config/.ssh/loghoi-key`
- ホスト: `./config/.ssh/loghoi-key`
- **永続化**: ホストのディレクトリに保存されるため、コンテナ再起動後も保持される

## 現在の動作

### Kubernetes環境での動作

1. **Secretが存在する場合**:
   - Secretから `/app/config/.ssh/ntnx-lockdown` にマウント
   - APIは既存の鍵を検出して `status: "exists"` を返す
   - 鍵は永続化される（Secretに保存されているため）

2. **Secretが存在しない場合**:
   - `/app/config/.ssh/` ディレクトリは存在しない（マウントされない）
   - APIが鍵を生成しようとすると、ディレクトリを作成して鍵を生成
   - **問題**: Pod再起動時に鍵が失われる（一時ストレージに保存されるため）

### docker-compose環境での動作

1. **鍵が存在しない場合**:
   - APIが `/app/config/.ssh/loghoi-key` に鍵を生成
   - ホストの `./config/.ssh/loghoi-key` に保存される
   - **永続化**: ホストに保存されるため、コンテナ再起動後も保持される

2. **鍵が既に存在する場合**:
   - 既存の鍵を使用
   - APIは `status: "exists"` を返す

## 問題点と改善案

### 現在の問題点

1. **Kubernetes環境での永続化問題**:
   - Secretが存在しない場合、Pod内で生成した鍵はPod再起動時に失われる
   - `/app/config/.ssh/` がSecretからマウントされていない場合、鍵は一時ストレージに保存される

2. **環境変数の不一致**:
   - Kubernetes環境: `SSH_KEY_PATH=/app/config/.ssh/ntnx-lockdown`
   - デフォルト値: `/app/config/.ssh/loghoi-key`
   - 環境変数が設定されていれば問題ないが、デフォルト値との不一致がある

### 改善案

#### オプション1: PVCを使用して永続化（推奨）

```yaml
# backend-deployment.yaml
volumeMounts:
  - name: ssh-keys-storage
    mountPath: /app/config/.ssh
    readOnly: false  # 書き込み可能

volumes:
  - name: ssh-keys-storage
    persistentVolumeClaim:
      claimName: loghoi-ssh-keys-pvc
```

**メリット**:
- 鍵が永続化される
- Pod再起動後も鍵が保持される

**デメリット**:
- 追加のPVCが必要
- ストレージコストが発生

#### オプション2: InitContainerで鍵を生成してSecretに反映（将来の拡張）

```yaml
initContainers:
  - name: generate-ssh-key
    image: busybox
    command:
      - sh
      - -c
      - |
        if [ ! -f /keys/loghoi-key ]; then
          ssh-keygen -t rsa -b 4096 -f /keys/loghoi-key -N "" -C "loghoi@kubernetes"
          # Secretに反映する処理
        fi
```

**メリット**:
- 鍵がSecretに保存される
- 永続化される

**デメリット**:
- 実装が複雑
- Secretの更新が必要

#### オプション3: 現在の実装を維持（簡易版）

**現在の動作**:
- Secretが存在する場合はそれを使用（推奨）
- Secretが存在しない場合はPod内で生成（一時的）

**推奨される運用**:
1. 初回デプロイ時: Secretを作成してからデプロイ
2. または: Web UIから鍵を生成後、Secretに反映する手順を案内

## まとめ

### 現在の保存場所

| 環境 | 保存場所 | 永続化 | 備考 |
|------|----------|--------|------|
| Kubernetes (Secretあり) | `/app/config/.ssh/ntnx-lockdown` | ✅ 永続化 | Secretからマウント |
| Kubernetes (Secretなし) | `/app/config/.ssh/loghoi-key` | ❌ 一時的 | Pod再起動で失われる |
| docker-compose | `./config/.ssh/loghoi-key` (ホスト) | ✅ 永続化 | ホストに保存 |

### 推奨される運用

1. **Kubernetes環境**:
   - 初回デプロイ時はSecretを作成してからデプロイ
   - または、Web UIから鍵を生成後、手動でSecretを作成

2. **docker-compose環境**:
   - 現在の実装で問題なし（ホストに保存されるため）

### 今後の改善

- PVCを使用した永続化（オプション1）
- または、鍵生成後に自動的にSecretに反映する機能（オプション2）

