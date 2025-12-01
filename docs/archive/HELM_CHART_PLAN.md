# Helm Chart 開発計画

## 現在の状況

### ✅ 完了済み
- [x] Helm Chartの基本構造作成（Chart.yaml, values.yaml）
- [x] 全13個のテンプレートファイル作成
  - Phase 1: configmap, services, ingress
  - Phase 2: backend-deployment, backend-output-pvc
  - Phase 3: frontend-deployment, nginx-config
  - Phase 4: elasticsearch-deployment, elasticsearch-pvc, kibana-deployment
  - Phase 5: syslog-deployment, hpa
- [x] バックエンドのHPA削除（RWO制約のため）
- [x] PVCコメントの更新（Helmでの扱いを明記）

## 次のステップ

### Phase 6: 動作確認とテスト

#### 6.1 Helmテンプレートのレンダリングテスト
```bash
# テンプレートが正しくレンダリングされるか確認
helm template loghoihoi ./helm/loghoihoi

# 特定のリソースだけ確認
helm template loghoihoi ./helm/loghoihoi | grep -A 20 "kind: Deployment"

# values.yamlを上書きしてテスト
helm template loghoihoi ./helm/loghoihoi -f values-custom.yaml
```

**確認ポイント**:
- すべてのテンプレートが正しくレンダリングされるか
- 変数が正しく置換されているか
- 既存のk8s/*.yamlと同等の出力になるか

#### 6.2 実際のデプロイテスト（オプション）
```bash
# テスト環境でデプロイ
KUBECONFIG=/path/to/kubeconfig.conf \
  helm install loghoihoi-test ./helm/loghoihoi \
  --namespace loghoihoi-test \
  --create-namespace \
  --dry-run --debug

# 実際にデプロイ（テスト環境）
KUBECONFIG=/path/to/kubeconfig.conf \
  helm install loghoihoi-test ./helm/loghoihoi \
  --namespace loghoihoi-test \
  --create-namespace

# 状態確認
helm status loghoihoi-test -n loghoihoi-test
kubectl get pods,pvc,svc,ingress -n loghoihoi-test

# アンインストール
helm uninstall loghoihoi-test -n loghoihoi-test
```

### Phase 7: ドキュメント整備

#### 7.1 Helm Chart用README作成
- `helm/loghoihoi/README.md` を作成
- インストール手順
- values.yamlの説明
- カスタマイズ方法
- トラブルシューティング

#### 7.2 既存ドキュメントの更新
- `k8s/DEPLOYMENT_GUIDE.md` にHelm Chartのセクションを追加
- `k8s/README.md` にHelm Chartの説明を追加

### Phase 8: 改善と最適化

#### 8.1 values.yamlの拡張（必要に応じて）
- リソース制限の設定可能化
- レプリカ数の設定可能化
- 機能フラグ（elasticsearch.enabled, kibana.enabled など）

#### 8.2 テンプレートの最適化
- 共通部分のヘルパーテンプレート化
- 条件分岐の整理
- エラーハンドリングの追加

### Phase 9: developへのマージ準備

#### 9.1 最終確認
- [ ] すべてのテンプレートが正しく動作する
- [ ] ドキュメントが整備されている
- [ ] 既存のdeploy.shと互換性がある
- [ ] テストが完了している

#### 9.2 developへのマージ
```bash
git checkout develop
git merge feature/helm-chart
git push origin develop
```

#### 9.3 必要に応じてmainへのマージ
- developで十分に検証後、mainにマージ
- リリースタグを付与

## 注意事項

### deploy.shとの関係
- 当面は `deploy.sh` と Helm Chart の両方をサポート
- 将来的に Helm Chart をメインにするかは後で判断

### 既存のk8s/*.yamlとの関係
- `k8s/*.yaml` は引き続き参照用として保持
- Helm Chartは `helm/loghoihoi/` に配置
- 両方のデプロイ方法をサポート

### テスト環境
- 可能であれば、テスト環境で実際にデプロイして動作確認
- 本番環境への適用は慎重に

## 参考リンク

- [Helm公式ドキュメント](https://helm.sh/docs/)
- [Helm Chart Best Practices](https://helm.sh/docs/chart_best_practices/)

