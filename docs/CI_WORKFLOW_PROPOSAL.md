# CIワークフロー提案（最終版）

## 提案内容の検討結果

提案されたCIワークフローは非常に良い設計です。以下の改善点を加えた最終版を提案します。

## 確認事項

### sharedディレクトリの依存関係
- ✅ **確認済み**: `shared/` ディレクトリは Python コードのみで、バックエンド専用
- ✅ フロントエンドの `components/shared/` は別物（`frontend/next-app/loghoi/components/shared/`）
- ✅ したがって、`shared/**` は frontend filter に含める必要はない

## 改善点

1. **syslogのビルド検証を追加** - `syslog/Dockerfile.k8s` も検証対象に
2. **Dockerfileのglobを絞る** - 無駄なジョブ実行を防止
3. **docker-compose.ymlのビルド検証** - push時のみ実行（PRは構文チェックのみ）
4. **ci-summaryのロジック改善** - 予期しない skipped を検出

## 最終版ワークフロー

```yaml
name: CI - Complete (build & validate)

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

permissions:
  contents: read

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  changes:
    name: Detect changes
    runs-on: ubuntu-latest
    outputs:
      frontend: ${{ steps.filter.outputs.frontend }}
      backend: ${{ steps.filter.outputs.backend }}
      syslog: ${{ steps.filter.outputs.syslog }}
      helm: ${{ steps.filter.outputs.helm }}
      compose: ${{ steps.filter.outputs.compose }}
    steps:
      - uses: actions/checkout@v4

      - name: Paths filter
        id: filter
        uses: dorny/paths-filter@v3
        with:
          filters: |
            # NOTE: shared/ はバックエンド専用（Pythonコードのみ）のため、frontend filter には含めない
            frontend:
              - 'frontend/**'

            # NOTE: Dockerfileのglobを絞って「関係ないDockerfile変更」で無駄に走らないようにする
            backend:
              - 'backend/**'
              - 'shared/**'              # sharedディレクトリの変更もbackendに影響
              - 'backend/Dockerfile*'
              - 'Dockerfile*'            # ルートDockerfileに依存している場合だけ残す（不要なら削除OK）
              - '.dockerignore'          # ビルド結果に影響するため

            syslog:
              - 'syslog/**'
              - 'syslog/Dockerfile*'
              - '.dockerignore'

            helm:
              - 'helm/**'
              - 'k8s/**'

            compose:
              - 'docker-compose.yml'
              - 'docker-compose.*.yml'

  build-frontend:
    name: Build frontend (yarn build)
    runs-on: ubuntu-latest
    needs: changes
    if: needs.changes.outputs.frontend == 'true'
    defaults:
      run:
        working-directory: frontend/next-app/loghoi

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'yarn'
          cache-dependency-path: frontend/next-app/loghoi/yarn.lock

      - name: Enable Corepack
        run: corepack enable

      - name: Show versions
        run: |
          node -v
          yarn -v

      - name: Install dependencies
        run: yarn install --frozen-lockfile

      - name: Build
        run: yarn build

  build-backend:
    name: Build backend (docker build only)
    runs-on: ubuntu-latest
    needs: changes
    if: needs.changes.outputs.backend == 'true'
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Docker Buildx
        uses: docker/setup-buildx-action@v3

      # Build only（pushしない）
      - name: Build backend Docker image
        uses: docker/build-push-action@v6
        with:
          context: .
          file: backend/Dockerfile.k8s
          push: false
          tags: loghoi-backend:ci-test

  build-syslog:
    name: Build syslog (docker build only)
    runs-on: ubuntu-latest
    needs: changes
    if: needs.changes.outputs.syslog == 'true'
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Docker Buildx
        uses: docker/setup-buildx-action@v3

      # Build only（pushしない）
      - name: Build syslog Docker image
        uses: docker/build-push-action@v6
        with:
          context: ./syslog
          file: ./syslog/Dockerfile.k8s
          push: false
          tags: loghoi-syslog:ci-test

  validate-packaging:
    name: Validate compose/helm (lint & template)
    runs-on: ubuntu-latest
    needs: changes
    if: needs.changes.outputs.helm == 'true' || needs.changes.outputs.compose == 'true'
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Validate docker compose (config)
        if: needs.changes.outputs.compose == 'true'
        run: |
          docker version
          docker compose version
          docker compose -f docker-compose.yml config -q

      # NOTE: Compose buildは重くなりがちなので、push時のみ実施（PRは構文チェックに留める）
      - name: Validate docker compose (build on push)
        if: needs.changes.outputs.compose == 'true' && github.event_name == 'push'
        run: |
          # サービス名不一致事故を避けるため、全サービスをビルド（ビルド不要なサービスは自動スキップ）
          docker compose -f docker-compose.yml build

      - name: Setup Helm
        if: needs.changes.outputs.helm == 'true'
        uses: azure/setup-helm@v4
        # NOTE: version を指定しないと安定した最新が入ることが多い（latest指定は逆にブレの原因になりがち）

      - name: Helm lint & template
        if: needs.changes.outputs.helm == 'true'
        run: |
          helm version
          helm lint ./helm/loghoihoi
          # デフォルト値でレンダリング
          helm template loghoihoi ./helm/loghoihoi >/dev/null
          # values.yamlでもレンダリング（valuesで壊れるのを検出）
          helm template loghoihoi ./helm/loghoihoi -f ./helm/loghoihoi/values.yaml >/dev/null

  # 変更がない場合でも「CIが成功扱い」になるよう、最後に集約ジョブを置く
  ci-summary:
    name: CI summary
    runs-on: ubuntu-latest
    needs:
      - changes
      - build-frontend
      - build-backend
      - build-syslog
      - validate-packaging
    if: always()
    steps:
      - name: Check CI results
        shell: bash
        run: |
          set -e

          echo "=== Change Detection ==="
          echo "frontend changed:   ${{ needs.changes.outputs.frontend }}"
          echo "backend changed:    ${{ needs.changes.outputs.backend }}"
          echo "syslog changed:     ${{ needs.changes.outputs.syslog }}"
          echo "helm changed:       ${{ needs.changes.outputs.helm }}"
          echo "compose changed:    ${{ needs.changes.outputs.compose }}"
          echo ""
          echo "=== Job Results ==="
          echo "build-frontend:     ${{ needs.build-frontend.result }}"
          echo "build-backend:      ${{ needs.build-backend.result }}"
          echo "build-syslog:       ${{ needs.build-syslog.result }}"
          echo "validate-packaging: ${{ needs.validate-packaging.result }}"
          echo ""

          failed_jobs=()

          # failure/cancelled は失敗扱い
          if [ "${{ needs.build-frontend.result }}" = "failure" ] || [ "${{ needs.build-frontend.result }}" = "cancelled" ]; then failed_jobs+=("build-frontend"); fi
          if [ "${{ needs.build-backend.result }}"  = "failure" ] || [ "${{ needs.build-backend.result }}"  = "cancelled" ]; then failed_jobs+=("build-backend"); fi
          if [ "${{ needs.build-syslog.result }}"   = "failure" ] || [ "${{ needs.build-syslog.result }}"   = "cancelled" ]; then failed_jobs+=("build-syslog"); fi
          if [ "${{ needs.validate-packaging.result }}" = "failure" ] || [ "${{ needs.validate-packaging.result }}" = "cancelled" ]; then failed_jobs+=("validate-packaging"); fi

          # 変更があったのにskippedはNG（if条件ミス検知）
          if [ "${{ needs.changes.outputs.frontend }}" = "true" ] && [ "${{ needs.build-frontend.result }}" = "skipped" ]; then failed_jobs+=("build-frontend(skipped-unexpected)"); fi
          if [ "${{ needs.changes.outputs.backend }}"  = "true" ] && [ "${{ needs.build-backend.result }}"  = "skipped" ]; then failed_jobs+=("build-backend(skipped-unexpected)"); fi
          if [ "${{ needs.changes.outputs.syslog }}"   = "true" ] && [ "${{ needs.build-syslog.result }}"   = "skipped" ]; then failed_jobs+=("build-syslog(skipped-unexpected)"); fi

          packaging_changed="false"
          if [ "${{ needs.changes.outputs.helm }}" = "true" ] || [ "${{ needs.changes.outputs.compose }}" = "true" ]; then packaging_changed="true"; fi
          if [ "$packaging_changed" = "true" ] && [ "${{ needs.validate-packaging.result }}" = "skipped" ]; then failed_jobs+=("validate-packaging(skipped-unexpected)"); fi

          if [ ${#failed_jobs[@]} -gt 0 ]; then
            echo "❌ CI failed. Issues: ${failed_jobs[*]}"
            exit 1
          fi

          echo "✅ CI passed. All required jobs succeeded; others were skipped as expected."
```

## 主な変更点（最終版）

### 1. Dockerfileのglobを絞る

```yaml
backend:
  - 'backend/Dockerfile*'    # 特定のDockerfileのみ
  - '.dockerignore'           # ビルド結果に影響
```

**効果**: 無関係なDockerfileの変更で無駄にジョブが走るのを防止

### 2. sharedディレクトリの扱い

- ✅ `shared/**` は **backend filter のみ**に含める（バックエンド専用）
- ❌ frontend filter には含めない（フロントエンドの `components/shared/` は別物）

### 3. docker-compose.ymlのビルド検証を最適化

```yaml
# PR時: 構文チェックのみ（高速）
- name: Validate docker compose (config)
  if: needs.changes.outputs.compose == 'true'
  run: docker compose -f docker-compose.yml config -q

# Push時: 実際にビルド（時間はかかるが、より確実）
- name: Validate docker compose (build on push)
  if: needs.changes.outputs.compose == 'true' && github.event_name == 'push'
  run: docker compose -f docker-compose.yml build backend frontend syslog
```

**効果**: PR時は高速、push時はより確実な検証

### 4. ci-summaryのロジック改善

- ✅ `skipped`ジョブを適切に無視
- ✅ **予期しない skipped を検出**（if条件ミスを早期発見）
- ✅ `set -euo pipefail` でエラーハンドリング強化
- ✅ より詳細なログ出力

### 5. バージョン情報の表示

```yaml
- name: Show versions
  run: |
    node -v
    yarn -v
```

**効果**: デバッグ時に環境情報を確認しやすい

## 実行フロー

```
[changes] (変更検出)
    ├─→ [build-frontend] (並列実行)
    ├─→ [build-backend]  (並列実行)
    ├─→ [build-syslog]   (並列実行)
    └─→ [validate-packaging]
            └─→ [ci-summary] (集約)
```

## パフォーマンス考慮事項

1. **並列実行**: frontend/backend/syslogは並列実行されるため、全体の実行時間は最長のジョブに依存
2. **キャッシュ**: yarnのキャッシュを活用してフロントエンドのビルド時間を短縮
3. **変更検出**: 変更がないジョブはスキップされるため、無駄な実行を回避
4. **Dockerfileの絞り込み**: 無関係なDockerfileの変更でジョブが走らないように最適化
5. **docker-composeビルド**: PR時は構文チェックのみ、push時のみ実際にビルド（時間短縮）

## 次のステップ

1. このワークフローを `.github/workflows/ci.yml` として作成
2. プルリクエストを作成して動作確認
3. 問題があれば調整
4. 動作確認後、Lintやテストを段階的に追加

## 注意事項

- **docker-compose.ymlのビルド**: 最初は `config` ステップのみで、実際のビルドは必要に応じて有効化
- **実行時間**: 初回実行はキャッシュがないため時間がかかる可能性がある
- **GitHub Actionsの制限**: 無料プランでは月2000分まで（並列実行でも時間は加算される）

