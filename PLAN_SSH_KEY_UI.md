# Web UIでのSSH鍵生成機能 実装計画

## 概要
Web UIからSSH鍵を生成・管理できる機能を実装します。これにより、コマンドラインでの操作を不要にし、より使いやすいインターフェースを提供します。

## 現在の実装状況

### 既存機能
- `/api/sshkey` (GET): 公開鍵を取得
- SSH鍵の保存場所: `/app/config/.ssh/loghoi-key`
- `connect_ssh`関数: SSH接続に使用

### 不足している機能
- SSH鍵の生成機能
- SSH鍵の削除機能
- SSH鍵の再生成機能
- Web UIでの鍵管理画面

## 実装計画

### Phase 1: バックエンドAPI実装

#### 1.1 SSH鍵生成API
- **エンドポイント**: `POST /api/ssh-key/generate`
- **機能**: 新しいSSH鍵ペアを生成
- **リクエスト**: なし（または鍵タイプ、鍵長などのオプション）
- **レスポンス**: 
  ```json
  {
    "status": "success",
    "data": {
      "public_key": "ssh-rsa AAAAB3...",
      "private_key_path": "/app/config/.ssh/loghoi-key",
      "public_key_path": "/app/config/.ssh/loghoi-key.pub",
      "message": "SSH鍵が正常に生成されました"
    }
  }
  ```

#### 1.2 SSH鍵情報取得API
- **エンドポイント**: `GET /api/ssh-key/info`
- **機能**: 現在のSSH鍵の情報を取得（存在確認、生成日時など）
- **レスポンス**:
  ```json
  {
    "status": "success",
    "data": {
      "exists": true,
      "public_key": "ssh-rsa AAAAB3...",
      "created_at": "2024-01-01T00:00:00Z",
      "key_type": "rsa",
      "key_size": 4096
    }
  }
  ```

#### 1.3 SSH鍵削除API
- **エンドポイント**: `DELETE /api/ssh-key`
- **機能**: 既存のSSH鍵を削除（注意が必要な操作）
- **レスポンス**:
  ```json
  {
    "status": "success",
    "data": {
      "message": "SSH鍵が削除されました"
    }
  }
  ```

#### 1.4 SSH鍵再生成API
- **エンドポイント**: `POST /api/ssh-key/regenerate`
- **機能**: 既存の鍵を削除して新しい鍵を生成
- **レスポンス**: 生成APIと同じ

### Phase 2: フロントエンド実装

#### 2.1 設定画面の作成
- **パス**: `/settings/ssh-key`
- **機能**: SSH鍵の管理画面
- **コンポーネント**:
  - SSH鍵生成ボタン
  - 公開鍵表示エリア
  - 公開鍵コピーボタン
  - Nutanix Prismへの登録案内
  - 鍵情報表示（生成日時、鍵タイプなど）

#### 2.2 SSH鍵生成モーダル
- **機能**: 鍵生成の確認と結果表示
- **内容**:
  - 生成前の警告（既存鍵がある場合）
  - 生成中のローディング表示
  - 生成後の公開鍵表示
  - Prismへの登録案内

#### 2.3 公開鍵表示コンポーネント
- **機能**: 公開鍵を読みやすい形式で表示
- **機能**:
  - ワンクリックでコピー
  - 表示/非表示の切り替え
  - フォーマット済み表示

#### 2.4 Nutanix Prism登録案内
- **機能**: 公開鍵をPrismに登録する手順を表示
- **内容**:
  - ステップバイステップの手順
  - 公開鍵のコピー機能
  - リンク（可能であれば）

### Phase 3: Helm Chart連携

#### 3.1 Kubernetes Secretへの反映
- **機能**: 生成した鍵をKubernetes Secretに自動反映
- **方法**:
  - バックエンドからKubernetes APIを呼び出してSecretを更新
  - または、フロントエンドからHelm Chartの更新を促す

#### 3.2 鍵の同期機能
- **機能**: Web UIで生成した鍵をHelm Chartで使用可能にする
- **実装**: 
  - Secretの自動更新
  - または、鍵ファイルのマウント方法の案内

## 実装の優先順位

### 高優先度
1. SSH鍵生成API (`POST /api/ssh-key/generate`)
2. SSH鍵情報取得API (`GET /api/ssh-key/info`)
3. 設定画面の基本UI (`/settings/ssh-key`)
4. SSH鍵生成モーダル

### 中優先度
5. 公開鍵表示・コピー機能
6. Nutanix Prism登録案内
7. 鍵情報表示（生成日時など）

### 低優先度
8. SSH鍵削除API
9. SSH鍵再生成API
10. Helm Chart連携（自動反映）

## 技術的な考慮事項

### セキュリティ
- 秘密鍵は絶対にフロントエンドに送信しない
- 公開鍵のみを表示・コピー可能にする
- 鍵生成時の権限チェック（適切な権限で実行）

### エラーハンドリング
- 鍵生成失敗時の適切なエラーメッセージ
- 既存鍵がある場合の警告
- 権限エラーの適切な処理

### UI/UX
- 生成中のローディング表示
- 成功/失敗の明確なフィードバック
- 公開鍵のコピー機能
- Prism登録の手順を分かりやすく表示

## 参考資料
- [Helm Chart README](../helm/loghoihoi/README.md)
- [既存SSH鍵管理スクリプト](../helm/loghoihoi/scripts/create-ssh-secret.sh)
- [FastAPI ドキュメント](https://fastapi.tiangolo.com/)

