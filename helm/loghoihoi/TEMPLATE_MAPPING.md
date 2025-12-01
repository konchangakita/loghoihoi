# Helm Chart テンプレートマッピング

既存の `k8s/*.yaml` ファイルを Helm Chart の `templates/` に移行する際のマッピング表です。

## マッピング表

| 既存ファイル | Helm テンプレート | 説明 |
|------------|-----------------|------|
| `backend-deployment.yaml` | `templates/backend-deployment.yaml` | バックエンドDeployment |
| `frontend-deployment.yaml` | `templates/frontend-deployment.yaml` | フロントエンドDeployment |
| `elasticsearch-deployment.yaml` | `templates/elasticsearch-deployment.yaml` | Elasticsearch Deployment |
| `kibana-deployment.yaml` | `templates/kibana-deployment.yaml` | Kibana Deployment |
| `syslog-deployment.yaml` | `templates/syslog-deployment.yaml` | Syslog Deployment |
| `services.yaml` | `templates/services.yaml` | 全Service定義（1ファイルのまま） |
| `ingress.yaml` | `templates/ingress.yaml` | Ingress設定 |
| `backend-output-pvc.yaml` | `templates/backend-output-pvc.yaml` | Backend用PVC（参照用） |
| `elasticsearch-pvc.yaml` | `templates/elasticsearch-pvc.yaml` | Elasticsearch用PVC（参照用） |
| `hpa.yaml` | `templates/hpa.yaml` | Horizontal Pod Autoscaler |
| `configmap.yaml` | `templates/configmap.yaml` | ConfigMap |
| `nginx-config.yaml` | `templates/nginx-config.yaml` | Nginx設定（ConfigMap） |

## 移行しないファイル

以下のファイルは Helm Chart には含めません：

- `deploy.sh` - 既存のデプロイスクリプト（Helmと並行運用）
- `build-and-push.sh` - イメージビルドスクリプト
- `*.md` - ドキュメントファイル
- `traefik-values.yaml` - Traefik設定（別途管理）

## 実装順序（推奨）

1. **Phase 1: 基本リソース**
   - `configmap.yaml`
   - `services.yaml`
   - `ingress.yaml`

2. **Phase 2: バックエンド**
   - `backend-deployment.yaml`
   - `backend-output-pvc.yaml`

3. **Phase 3: フロントエンド**
   - `frontend-deployment.yaml`
   - `nginx-config.yaml`

4. **Phase 4: データストア**
   - `elasticsearch-deployment.yaml`
   - `elasticsearch-pvc.yaml`
   - `kibana-deployment.yaml`

5. **Phase 5: その他**
   - `syslog-deployment.yaml`
   - `hpa.yaml`

## 注意事項

- Secret（`loghoi-secrets`）は既存のものを使用する前提（Chartでは作成しない）
- Namespaceは `loghoihoi` 固定
- PVCは `deploy.sh` で動的生成されるため、テンプレートは参照用

