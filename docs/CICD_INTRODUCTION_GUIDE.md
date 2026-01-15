# CI/CD導入ガイド

## 概要

このドキュメントでは、loghoihoiプロジェクトにCI/CDパイプラインを導入する手順と設計方針について説明します。

## 現状分析

### プロジェクト構成

- **フロントエンド**: Next.js 14, React, TypeScript
- **バックエンド**: FastAPI, Python 3.11
- **Syslog**: Elastic Filebeat 7.17.9
- **コンテナレジストリ**: GitHub Container Registry (ghcr.io)
- **Helm Chart**: OCIレジストリに公開済み

### 既存のビルド・デプロイプロセス

1. **手動ビルドスクリプト**: `k8s/build-and-push.sh`
   - 3つのコンテナイメージをビルド・プッシュ
   - バージョン管理は環境変数で制御
   - レジストリ: `ghcr.io/konchangakita`

2. **Helm Chart**: `helm/loghoihoi/`
   - OCIレジストリに公開済み (`oci://ghcr.io/konchangakita/loghoihoi`)
   - バージョン: 0.1.0

3. **テスト環境**:
   - フロントエンド: Jest (単体テスト), Playwright (E2Eテスト)
   - バックエンド: pytest

## CI/CDパイプライン設計

### 推奨プラットフォーム: GitHub Actions

**理由**:
- 既にGitHub Container Registry (ghcr.io) を使用している
- Helm ChartもOCIレジストリに公開済み
- GitHubリポジトリと統合しやすい
- 無料プランで十分な機能を提供

### パイプライン構成

#### 1. プルリクエスト時のCIパイプライン

**トリガー**: Pull Request作成・更新時

**ステップ**:
1. **コードチェック**
   - Lint (ESLint, flake8/black)
   - 型チェック (TypeScript, mypy)
   - フォーマットチェック

2. **テスト実行**
   - フロントエンド: Jest (単体テスト)
   - バックエンド: pytest (単体テスト)
   - E2Eテスト: Playwright (オプション、時間がかかるため)

3. **セキュリティスキャン**
   - 依存関係の脆弱性チェック (Dependabot, Snyk)
   - コンテナイメージのスキャン (Trivy)

4. **ビルド検証**
   - Dockerイメージのビルドテスト（プッシュはしない）
   - Helm Chartの構文チェック

#### 2. メインブランチへのマージ時のCDパイプライン

**トリガー**: メインブランチへのマージ時

**ステップ**:
1. **テスト実行** (CIと同じ)
2. **コンテナイメージのビルド・プッシュ**
   - バックエンド: `ghcr.io/konchangakita/loghoi-backend:${VERSION}`
   - フロントエンド: `ghcr.io/konchangakita/loghoi-frontend:${VERSION}`
   - Syslog: `ghcr.io/konchangakita/loghoi-syslog:${VERSION}`
   - タグ: バージョンタグ + `latest`

3. **Helm Chartのパッケージ化・公開**
   - Helm Chartのバージョン更新
   - OCIレジストリへのプッシュ

4. **デプロイ通知** (オプション)
   - Slack/Discord通知
   - リリースノートの自動生成

#### 3. リリースタグ作成時のパイプライン

**トリガー**: Gitタグ作成時 (`v*` 形式)

**ステップ**:
1. **フルテストスイート実行**
2. **コンテナイメージのビルド・プッシュ** (リリースバージョン)
3. **Helm Chartのリリース**
4. **GitHub Release作成**
   - リリースノート自動生成
   - 変更履歴の追加

## 実装手順

### ステップ1: GitHub Actionsワークフローの作成

#### 1.1 ディレクトリ構造の作成

```bash
mkdir -p .github/workflows
```

#### 1.2 CIワークフローの作成

**ファイル**: `.github/workflows/ci.yml`

**主な機能**:
- プルリクエスト時の自動テスト
- Lint/フォーマットチェック
- セキュリティスキャン
- ビルド検証

#### 1.3 CDワークフローの作成

**ファイル**: `.github/workflows/cd.yml`

**主な機能**:
- メインブランチマージ時の自動ビルド・プッシュ
- Helm Chartの更新・公開
- バージョン管理

#### 1.4 リリースワークフローの作成

**ファイル**: `.github/workflows/release.yml`

**主な機能**:
- リリースタグ作成時の処理
- GitHub Release作成
- リリースノート生成

### ステップ2: GitHub Secretsの設定

以下のSecretsをGitHubリポジトリに設定する必要があります:

1. **`GHCR_TOKEN`** (必須)
   - GitHub Personal Access Token (PAT)
   - スコープ: `write:packages`, `read:packages`
   - 用途: コンテナイメージのプッシュ

2. **`KUBECONFIG`** (オプション、自動デプロイする場合)
   - Kubernetesクラスターへの接続情報
   - 用途: 自動デプロイ

### ステップ3: バージョン管理戦略の決定

#### オプションA: セマンティックバージョニング

- **形式**: `v1.2.3`
- **ルール**:
  - メジャー: 破壊的変更
  - マイナー: 新機能追加
  - パッチ: バグ修正

#### オプションB: 日付ベースバージョニング

- **形式**: `v2024.01.15` または `v1.1.3` (現在の形式)
- **メリット**: 日付が分かりやすい

#### 推奨: セマンティックバージョニング

既存の `v1.1.3` 形式と互換性があるため、セマンティックバージョニングを推奨します。

### ステップ4: バージョン管理の自動化

#### 4.1 バージョンファイルの統一

以下のファイルでバージョンを管理:

- `backend/__init__.py` または `backend/fastapi_app/__init__.py`
- `frontend/next-app/loghoi/package.json`
- `helm/loghoihoi/Chart.yaml`
- `helm/loghoihoi/values.yaml`

#### 4.2 バージョン更新スクリプトの作成

**ファイル**: `scripts/update-version.sh`

バージョンタグ作成時に、すべてのバージョンファイルを自動更新するスクリプト。

### ステップ5: テスト環境の整備

#### 5.1 テストカバレッジの向上

- フロントエンド: Jestカバレッジレポートの生成
- バックエンド: pytestカバレッジレポートの生成
- カバレッジ閾値の設定 (例: 80%)

#### 5.2 E2Eテストの最適化

- Playwrightテストの並列実行
- テスト時間の短縮
- フレーキーテストの対策

### ステップ6: セキュリティスキャンの設定

#### 6.1 Dependabotの有効化

**ファイル**: `.github/dependabot.yml`

依存関係の自動更新と脆弱性チェック。

#### 6.2 Trivyスキャンの追加

コンテナイメージの脆弱性スキャン。

### ステップ7: デプロイ戦略の決定

#### オプションA: 手動デプロイ（推奨）

- CI/CDでイメージとHelm Chartをビルド・公開
- デプロイは手動で実行
- **メリット**: 安全性が高い、デプロイタイミングを制御可能

#### オプションB: 自動デプロイ

- メインブランチマージ時に自動デプロイ
- **メリット**: デプロイが自動化される
- **デメリット**: リスクが高い、ロールバックが困難

**推奨**: オプションA（手動デプロイ）

## ワークフローファイルの例

### CIワークフロー (`.github/workflows/ci.yml`)

```yaml
name: CI

on:
  pull_request:
    branches: [ main, develop ]
  push:
    branches: [ main, develop ]

jobs:
  lint-frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: cd frontend/next-app/loghoi && yarn install
      - run: cd frontend/next-app/loghoi && yarn lint

  test-frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: cd frontend/next-app/loghoi && yarn install
      - run: cd frontend/next-app/loghoi && yarn test

  lint-backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - run: pip install black flake8
      - run: black --check backend/ shared/
      - run: flake8 backend/ shared/

  test-backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - run: pip install -r backend/requirements.txt
      - run: pytest backend/ -v --cov=backend --cov-report=xml

  build-images:
    runs-on: ubuntu-latest
    needs: [lint-frontend, test-frontend, lint-backend, test-backend]
    steps:
      - uses: actions/checkout@v4
      - name: Build Docker images
        run: |
          docker build -t loghoi-backend:test -f backend/Dockerfile.k8s .
          docker build -t loghoi-frontend:test -f frontend/next-app/loghoi/Dockerfile.k8s frontend/next-app/loghoi
          docker build -t loghoi-syslog:test -f syslog/Dockerfile.k8s syslog
```

### CDワークフロー (`.github/workflows/cd.yml`)

```yaml
name: CD

on:
  push:
    branches: [ main ]

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      
      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Extract version
        id: version
        run: |
          VERSION=$(git describe --tags --always --dirty | sed 's/^v//')
          echo "version=$VERSION" >> $GITHUB_OUTPUT
      
      - name: Build and push backend
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./backend/Dockerfile.k8s
          push: true
          tags: |
            ghcr.io/konchangakita/loghoi-backend:${{ steps.version.outputs.version }}
            ghcr.io/konchangakita/loghoi-backend:latest
      
      - name: Build and push frontend
        uses: docker/build-push-action@v5
        with:
          context: ./frontend/next-app/loghoi
          file: ./frontend/next-app/loghoi/Dockerfile.k8s
          push: true
          tags: |
            ghcr.io/konchangakita/loghoi-frontend:${{ steps.version.outputs.version }}
            ghcr.io/konchangakita/loghoi-frontend:latest
      
      - name: Build and push syslog
        uses: docker/build-push-action@v5
        with:
          context: ./syslog
          file: ./syslog/Dockerfile.k8s
          push: true
          tags: |
            ghcr.io/konchangakita/loghoi-syslog:${{ steps.version.outputs.version }}
            ghcr.io/konchangakita/loghoi-syslog:latest
      
      - name: Package and push Helm chart
        uses: helm/kind-action@v1.5.0
        with:
          helm-version: 'latest'
        env:
          HELM_EXPERIMENTAL_OCI: 1
        run: |
          helm package helm/loghoihoi
          helm push loghoihoi-*.tgz oci://ghcr.io/konchangakita
```

## 導入チェックリスト

### フェーズ1: 基礎設定

- [ ] `.github/workflows/` ディレクトリの作成
- [ ] CIワークフローの作成・テスト
- [ ] GitHub Secretsの設定 (`GHCR_TOKEN`)
- [ ] プルリクエストでのCI動作確認

### フェーズ2: ビルド・プッシュの自動化

- [ ] CDワークフローの作成
- [ ] コンテナイメージのビルド・プッシュテスト
- [ ] Helm Chartの自動パッケージ化・公開テスト
- [ ] バージョン管理の確認

### フェーズ3: テスト・品質向上

- [ ] テストカバレッジレポートの生成
- [ ] セキュリティスキャンの追加 (Trivy, Dependabot)
- [ ] Lint/フォーマットチェックの強化
- [ ] E2Eテストの最適化

### フェーズ4: リリース自動化

- [ ] リリースワークフローの作成
- [ ] バージョン更新スクリプトの作成
- [ ] GitHub Releaseの自動生成
- [ ] リリースノートの自動生成

### フェーズ5: 監視・通知

- [ ] デプロイ通知の設定 (Slack/Discord)
- [ ] ビルドステータスのバッジ追加
- [ ] ドキュメントの更新

## 注意事項

### セキュリティ

1. **Secrets管理**
   - 機密情報はGitHub Secretsで管理
   - ローカル環境でのテスト時も注意

2. **コンテナイメージのスキャン**
   - 定期的な脆弱性スキャンの実施
   - 依存関係の更新

3. **アクセス制御**
   - ワークフローの実行権限を適切に設定
   - 自動デプロイは慎重に検討

### パフォーマンス

1. **ビルド時間の最適化**
   - Dockerレイヤーキャッシュの活用
   - 並列実行の最大化

2. **コスト管理**
   - GitHub Actionsの実行時間に注意
   - 不要なワークフローの実行を避ける

### バージョン管理

1. **一貫性の維持**
   - すべてのバージョンファイルを同期
   - セマンティックバージョニングの遵守

2. **タグ管理**
   - リリースタグの命名規則を統一
   - タグの削除・変更は慎重に

## 参考リンク

- [GitHub Actions ドキュメント](https://docs.github.com/ja/actions)
- [GitHub Container Registry](https://docs.github.com/ja/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Helm OCI レジストリ](https://helm.sh/docs/topics/registries/)
- [Docker Buildx](https://docs.docker.com/buildx/)
- [Trivy](https://github.com/aquasecurity/trivy)

## 次のステップ

1. このガイドをレビューし、プロジェクトに適したCI/CD戦略を決定
2. フェーズ1から順に実装を開始
3. 各フェーズで動作確認を行い、問題があれば修正
4. ドキュメントを更新し、チーム内で共有

---

**作成日**: 2025-01-XX  
**最終更新**: 2025-01-XX


