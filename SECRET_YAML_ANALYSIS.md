# `k8s/secret.yaml`の使用状況分析

## 使用箇所の確認結果

### 1. `k8s/deploy.sh`（メインのデプロイスクリプト）
- **使用状況**: ❌ 使用していない
- **詳細**: 
  - 173-177行目でSSH鍵から直接`kubectl create secret`でSecretを作成
  - `secret.yaml`ファイルは参照していない
  - より安全な方法（SSH鍵から直接作成）を使用

### 2. `scripts/deploy-k8s.sh`（別のデプロイスクリプト）
- **使用状況**: ❌ 使用されていない（古いスクリプト）
- **詳細**: 
  - 94行目で`kubectl apply -f k8s/secret.yaml`を実行
  - ただし、README.mdやDEPLOYMENT_GUIDE.mdでは`k8s/deploy.sh`を使用する手順が記載
  - 最終更新日: 10月6日（`k8s/deploy.sh`は11月4日更新）
  - 現在は使用されていない可能性が高い

### 3. `k8s/kustomization.yaml`（Kustomize設定）
- **使用状況**: ⚠️ 参照している
- **詳細**: 
  - 11行目で`secret.yaml`をリソースとして参照
  - ただし、71-79行目で`secretGenerator`も定義されている（別の方法）
  - Kustomizeを使用する場合は影響あり

## 実装への影響

### 影響がある場合
1. **Kustomizeを使用している場合**
   - `kustomization.yaml`の11行目でエラーが発生する可能性
   - `kustomization.yaml`の修正が必要

### 影響がない場合
1. **`k8s/deploy.sh`を使用している場合（現在のメインスクリプト）**
   - 影響なし（SSH鍵から直接Secretを作成）
   - README.mdとDEPLOYMENT_GUIDE.mdで推奨されている方法

2. **`scripts/deploy-k8s.sh`を使用している場合**
   - 現在は使用されていない（古いスクリプト）
   - 将来的に使用する場合は修正が必要

## 推奨対応方法

### 方法1: `secret.yaml`を除外し、スクリプトを修正（推奨）

**メリット**:
- 機密情報を完全に除外できる
- より安全

**デメリット**:
- スクリプトの修正が必要

**対応手順**:
1. `k8s/secret.yaml`を`.gitignore`に追加
2. `k8s/kustomization.yaml`を修正
   - `secret.yaml`の参照を削除
   - または、`secret-template.yaml`に変更（ただし、テンプレートはそのまま適用できない）
3. （オプション）`scripts/deploy-k8s.sh`を修正
   - 現在は使用されていないが、将来的に使用する場合は修正が必要
   - `kubectl apply -f k8s/secret.yaml`を削除
   - または、`secret-template.yaml`をコピーして使用する処理に変更

### 方法2: `secret.yaml`のサンプル値を削除

**メリット**:
- スクリプトの修正が不要
- 実装への影響が最小限

**デメリット**:
- 空の値でも機密情報の形式が公開される
- 将来的に誤って機密情報をコミットするリスク

**対応手順**:
1. `k8s/secret.yaml`から開発環境用のサンプル値を削除
2. すべての値を空文字列にする
3. コメントで説明を追加

### 方法3: `secret.yaml`を除外し、READMEに手順を追加

**メリット**:
- 機密情報を完全に除外できる
- スクリプトの修正が最小限

**デメリット**:
- ユーザーが手動でSecretを作成する必要がある

**対応手順**:
1. `k8s/secret.yaml`を`.gitignore`に追加
2. `scripts/deploy-k8s.sh`から`kubectl apply -f k8s/secret.yaml`を削除
3. `k8s/kustomization.yaml`から`secret.yaml`の参照を削除
4. READMEにSecret作成手順を追加

## 推奨: 方法1（スクリプト修正）

最も安全で、将来的なリスクも最小限です。

### 具体的な修正内容

#### 1. `.gitignore`に追加
```gitignore
# Kubernetes secrets (exclude actual secrets, but include template)
k8s/secret.yaml
```

#### 2. （オプション）`scripts/deploy-k8s.sh`の修正
**注意**: 現在は使用されていないスクリプトですが、将来的に使用する場合は修正が必要です。

```bash
# 修正前
kubectl apply -f k8s/secret.yaml

# 修正後（オプション1: Secret作成をスキップ）
# Secretは手動で作成するか、k8s/deploy.shを使用する

# 修正後（オプション2: secret-template.yamlから作成）
if [ ! -f "k8s/secret.yaml" ]; then
    echo "Creating secret.yaml from template..."
    cp k8s/secret-template.yaml k8s/secret.yaml
    echo "⚠️  Please edit k8s/secret.yaml with your actual secrets"
    exit 1
fi
kubectl apply -f k8s/secret.yaml
```

#### 3. `k8s/kustomization.yaml`の修正
```yaml
# 修正前
resources:
  - secret.yaml

# 修正後
resources:
  # secret.yaml is excluded from git, create it manually or use secretGenerator
  # - secret.yaml
```

## 結論

**実装への影響**: 最小限
- `k8s/deploy.sh`を使用している場合（現在のメインスクリプト）: **影響なし**
- Kustomizeを使用している場合: 修正が必要（`kustomization.yaml`から`secret.yaml`の参照を削除）
- `scripts/deploy-k8s.sh`を使用している場合: 現在は使用されていないが、将来的に使用する場合は修正が必要

**推奨**: 方法1を採用し、スクリプトを修正することを推奨します。

