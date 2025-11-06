# `k8s/deploy.sh`でのファイル使用状況分析

## `k8s/deploy.sh`で使用されているファイル

### 必須ファイル
- `configmap.yaml` (190行目)
- `nginx-config.yaml` (196行目)
- `elasticsearch-deployment.yaml` (509行目)
- `services.yaml` (515行目)
- `backend-deployment.yaml` (521行目)
- `frontend-deployment.yaml` (522行目)
- `ingress.yaml` (528行目)

### オプションファイル
- `traefik-values.yaml` (280行目、354行目) - Traefikインストール時に使用
- `kibana-deployment.yaml` (534行目) - ファイルが存在する場合のみ適用
- `syslog-deployment.yaml` (544行目) - ファイルが存在する場合のみ適用

## 削除候補ファイルの分析

### 1. `secret.yaml`
- **`k8s/deploy.sh`での使用**: ❌ 使用されていない
- **理由**: SSH鍵から直接`kubectl create secret`で作成（173-177行目）
- **他の参照**: 
  - `kustomization.yaml`で参照（Kustomize使用時のみ）
  - `scripts/deploy-k8s.sh`で参照（使用されていないスクリプト）
- **削除可否**: ✅ 削除可能（`.gitignore`に追加済み推奨）

### 2. `kustomization.yaml`
- **`k8s/deploy.sh`での使用**: ❌ 使用されていない
- **理由**: Kustomizeを使用していない（直接`kubectl apply`を使用）
- **他の参照**: なし
- **削除可否**: ✅ 削除可能（Kustomizeを使用しない場合）

### 3. `namespace.yaml`
- **`k8s/deploy.sh`での使用**: ❌ 使用されていない
- **理由**: スクリプト内で直接`kubectl create namespace`で作成（49行目）
- **他の参照**: 
  - `kustomization.yaml`で参照（Kustomize使用時のみ）
  - `scripts/deploy-k8s.sh`で参照（使用されていないスクリプト）
- **削除可否**: ✅ 削除可能

### 4. `manual-storageclass.yaml`
- **`k8s/deploy.sh`での使用**: ❌ 使用されていない
- **理由**: スクリプト内で直接PVを生成（419-449行目）
- **他の参照**: なし
- **削除可否**: ✅ 削除可能

### 5. `load-images-to-nodes.sh`
- **`k8s/deploy.sh`での使用**: ❌ 使用されていない
- **理由**: スクリプト内で呼び出されていない
- **他の参照**: 
  - `DEPLOYMENT_STATUS.md`で言及（「作成済み、未実行」）
- **削除可否**: ⚠️ 要確認（別途使用する可能性がある場合は残す）

### 6. `TODO_DOCKERFILE_FIX.md`
- **`k8s/deploy.sh`での使用**: ❌ 使用されていない
- **理由**: ドキュメントファイル
- **他の参照**: ファイル内で自己参照
- **削除可否**: ✅ 削除可能（TODOが完了している場合）

### 7. `backend-output-pvc.yaml`
- **`k8s/deploy.sh`での使用**: ❌ 使用されていない
- **理由**: スクリプト内で直接PVCを生成（471-503行目）
- **他の参照**: 
  - `README.md`で「参照用」として記載
  - `DEPLOYMENT_STATUS.md`で言及
- **削除可否**: ✅ 削除可能（スクリプト内で動的生成）

### 8. `elasticsearch-pvc.yaml`
- **`k8s/deploy.sh`での使用**: ❌ 使用されていない
- **理由**: スクリプト内で直接PVCを生成（471-503行目）
- **他の参照**: 
  - `README.md`で「参照用」として記載
  - `DEPLOYMENT_STATUS.md`で言及
  - `KUBERNETES_SPEC.md`で手動適用の例として記載
- **削除可否**: ✅ 削除可能（スクリプト内で動的生成）

### 9. `hpa.yaml`
- **`k8s/deploy.sh`での使用**: ❌ 使用されていない
- **理由**: スクリプト内で適用されていない
- **他の参照**: 
  - `kustomization.yaml`で参照（Kustomize使用時のみ）
  - `DEPLOYMENT_GUIDE.md`で手動適用の例として記載（378行目、676行目）
  - `KUBERNETES_SPEC.md`で手動適用の例として記載（507行目）
  - `README.md`で「オプション」として記載
- **削除可否**: ⚠️ 要確認（手動で適用する場合は残す）

## 推奨対応

### 削除可能（問題なし）
1. ✅ `secret.yaml` - `.gitignore`に追加して除外
2. ✅ `kustomization.yaml` - Kustomizeを使用しない場合
3. ✅ `namespace.yaml` - スクリプト内で動的生成
4. ✅ `manual-storageclass.yaml` - スクリプト内で動的生成
5. ✅ `TODO_DOCKERFILE_FIX.md` - TODOが完了している場合
6. ✅ `backend-output-pvc.yaml` - スクリプト内で動的生成
7. ✅ `elasticsearch-pvc.yaml` - スクリプト内で動的生成

### 要確認（削除前に確認）
1. ⚠️ `load-images-to-nodes.sh` - 別途使用する可能性があるか確認
2. ⚠️ `hpa.yaml` - 手動で適用する場合は残す

## 注意事項

- `hpa.yaml`は手動で適用する場合があるため、削除する場合は`DEPLOYMENT_GUIDE.md`の該当箇所も更新が必要
- `backend-output-pvc.yaml`と`elasticsearch-pvc.yaml`は「参照用」としてドキュメントに記載されているため、削除する場合は`README.md`も更新が必要

