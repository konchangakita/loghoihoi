# GitHubアップロード前チェックリスト

## 🔒 セキュリティ・機密情報

### ✅ 確認済み
- [x] `.env`ファイルは`.gitignore`で除外されている
- [x] SSH秘密鍵（`config/.ssh/loghoi-key`）は除外されている
- [x] `config/.ssh/README.md`は含まれる設定になっている

### ⚠️ 要確認・対応
- [ ] **`k8s/secret.yaml`の確認**
  - 現在、開発環境用のサンプル値（`dev-password`、`dev-api-key`等）が含まれている
  - **対応案1**: サンプル値を削除し、空の値のみにする
  - **対応案2**: `k8s/secret.yaml`を`.gitignore`に追加し、`k8s/secret-template.yaml`のみをコミット
  - **推奨**: 対応案2（`secret.yaml`は除外、`secret-template.yaml`のみ含める）

- [ ] **`.env`ファイルの内容確認**
  - 実際の機密情報が含まれていないか確認
  - サンプル値のみの場合は、`.env.example`としてコミットを検討

- [ ] **ハードコードされた認証情報の確認**
  - コード内にAPIキー、パスワード、トークンがハードコードされていないか確認
  - `grep -r "password\|api_key\|secret" --include="*.py" --include="*.ts" --include="*.tsx"`

## 📄 ライセンス

### ⚠️ 要対応
- [ ] **LICENSEファイルの追加**
  - README.mdには「個人のブログ記事用のサンプルコード」と記載
  - 適切なライセンス（MIT、Apache 2.0、GPL等）を選択してLICENSEファイルを作成
  - README.mdにもライセンス情報を明記

## 📝 ドキュメント

### ✅ 確認済み
- [x] README.mdが存在し、内容が充実している
- [x] ドキュメント（`docs/`）が整理されている

### ⚠️ 要確認
- [ ] **README.mdの確認**
  - クイックスタート手順が正しいか
  - 必要な環境変数の説明があるか
  - セットアップ手順が明確か

- [ ] **CONTRIBUTING.mdの検討**
  - コントリビューションガイドラインの追加を検討

## 🔧 リポジトリ設定

### ⚠️ 要対応
- [ ] **Gitリポジトリの初期化**
  ```bash
  git init
  git add .
  git commit -m "Initial commit"
  ```

- [ ] **`.gitignore`の最終確認**
  - すべての機密情報が除外されているか
  - ビルド成果物（`node_modules/`、`.next/`、`__pycache__/`等）が除外されているか
  - 一時ファイルが除外されているか

- [ ] **大容量ファイルの確認**
  - 現在のサイズ: 約4.5MB（問題なし）
  - 100MBを超えるファイルがないか確認
  - 必要に応じてGit LFSの使用を検討

## 🏷️ リポジトリ情報

### ⚠️ 要確認
- [ ] **リポジトリ名の決定**
  - 現在のディレクトリ名: `loghoihoi`
  - GitHubでのリポジトリ名を決定

- [ ] **公開範囲の決定**
  - Public（公開）: 誰でも閲覧可能
  - Private（非公開）: 指定したユーザーのみ閲覧可能

- [ ] **説明文の準備**
  - GitHubリポジトリの説明文を準備
  - 例: "Nutanix環境のログ収集・分析ツール。CVMのリアルタイムログ、Syslog、ログファイル収集機能を提供。"

- [ ] **トピック（タグ）の準備**
  - `nutanix`
  - `log-collection`
  - `fastapi`
  - `nextjs`
  - `kubernetes`
  - `docker`
  - `elasticsearch`

## 🔍 コード品質

### ⚠️ 要確認
- [ ] **コメントの確認**
  - 機密情報を含むコメントがないか確認
  - 日本語コメントが適切か

- [ ] **TODO/FIXMEコメントの確認**
  - 公開前に削除またはIssue化を検討

- [ ] **デバッグコードの削除**
  - `console.log`、`print`文のデバッグコードがないか確認

## 📦 依存関係

### ✅ 確認済み
- [x] `requirements.txt`が存在
- [x] `package.json`が存在
- [x] `yarn.lock`が存在

### ⚠️ 要確認
- [ ] **依存関係のバージョン固定**
  - セキュリティ脆弱性がないか確認
  - `npm audit`、`pip-audit`等で確認

## 🚀 デプロイメント

### ⚠️ 要確認
- [ ] **デプロイスクリプトの確認**
  - `k8s/deploy.sh`が正しく動作するか
  - 環境変数の設定方法が明確か

- [ ] **CI/CDの検討**
  - GitHub Actionsの設定を検討
  - 自動テスト、ビルド、デプロイの設定

## 📋 その他

### ⚠️ 要確認
- [ ] **コミット履歴の整理**
  - 初回コミット前に不要なファイルを削除
  - コミットメッセージの規約を統一

- [ ] **ブランチ戦略の決定**
  - `main`ブランチをデフォルトに
  - 必要に応じて`develop`ブランチを作成

- [ ] **Issueテンプレートの検討**
  - Bug report
  - Feature request
  - Question

- [ ] **Pull Requestテンプレートの検討**
  - 変更内容の説明
  - テスト方法
  - チェックリスト

## 🎯 優先度の高い対応項目

1. **`k8s/secret.yaml`の対応**（セキュリティ）
2. **LICENSEファイルの追加**（ライセンス）
3. **Gitリポジトリの初期化**（必須）
4. **`.gitignore`の最終確認**（セキュリティ）
5. **README.mdの確認**（ドキュメント）

## 📚 参考リンク

- [GitHub Security Best Practices](https://docs.github.com/en/code-security)
- [GitHub Community Guidelines](https://docs.github.com/en/site-policy/github-terms/github-community-guidelines)
- [Choosing a License](https://choosealicense.com/)

