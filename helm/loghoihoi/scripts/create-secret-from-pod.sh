#!/bin/bash
# Pod内のSSH鍵からSecretを作成するスクリプト
# Web UIで生成した鍵をSecretに反映する際に使用

set -e

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 設定
KUBECONFIG_PATH="${KUBECONFIG:-}"
NAMESPACE="${NAMESPACE:-loghoihoi}"
SECRET_NAME="${SECRET_NAME:-loghoi-secrets}"

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}   Create Secret from Pod SSH Keys${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "Namespace: ${YELLOW}${NAMESPACE}${NC}"
echo -e "Secret name: ${YELLOW}${SECRET_NAME}${NC}"
echo ""

# kubectlコマンドの構築
K="kubectl"
if [ -n "${KUBECONFIG_PATH}" ]; then
    K="kubectl --kubeconfig=${KUBECONFIG_PATH}"
    export KUBECONFIG="${KUBECONFIG_PATH}"
fi

# バックエンドPodの取得
echo -e "${BLUE}バックエンドPodを検索中...${NC}"
POD_NAME=$(${K} get pod -n ${NAMESPACE} -l app=loghoi,component=backend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "${POD_NAME}" ]; then
    echo -e "${RED}❌ バックエンドPodが見つかりません${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Pod名: ${POD_NAME}${NC}"
echo ""

# Pod内の鍵ファイルの確認
echo -e "${BLUE}Pod内のSSH鍵を確認中...${NC}"
PRIVATE_KEY_PATH="/app/config/.ssh/ntnx-lockdown"
PUBLIC_KEY_PATH="/app/config/.ssh/ntnx-lockdown.pub"

# 環境変数で指定されたパスを確認
SSH_KEY_PATH=$(${K} exec -n ${NAMESPACE} ${POD_NAME} -- env | grep SSH_KEY_PATH | cut -d'=' -f2 || echo "")

if [ -n "${SSH_KEY_PATH}" ]; then
    PRIVATE_KEY_PATH="${SSH_KEY_PATH}"
    PUBLIC_KEY_PATH="${SSH_KEY_PATH}.pub"
    echo -e "${GREEN}✓ 環境変数 SSH_KEY_PATH から取得: ${SSH_KEY_PATH}${NC}"
fi

# 鍵ファイルの存在確認
if ! ${K} exec -n ${NAMESPACE} ${POD_NAME} -- test -f "${PRIVATE_KEY_PATH}" 2>/dev/null; then
    echo -e "${RED}❌ 秘密鍵が見つかりません: ${PRIVATE_KEY_PATH}${NC}"
    echo -e "${YELLOW}ヒント: Web UIから先にSSH鍵を生成してください${NC}"
    exit 1
fi

if ! ${K} exec -n ${NAMESPACE} ${POD_NAME} -- test -f "${PUBLIC_KEY_PATH}" 2>/dev/null; then
    echo -e "${RED}❌ 公開鍵が見つかりません: ${PUBLIC_KEY_PATH}${NC}"
    exit 1
fi

echo -e "${GREEN}✓ SSH鍵が見つかりました${NC}"
echo ""

# 鍵ファイルを一時ファイルにコピー
TMP_DIR=$(mktemp -d)
trap "rm -rf ${TMP_DIR}" EXIT

echo -e "${BLUE}鍵ファイルを取得中...${NC}"
${K} exec -n ${NAMESPACE} ${POD_NAME} -- cat "${PRIVATE_KEY_PATH}" > "${TMP_DIR}/private_key"
${K} exec -n ${NAMESPACE} ${POD_NAME} -- cat "${PUBLIC_KEY_PATH}" > "${TMP_DIR}/public_key"

# 権限設定
chmod 600 "${TMP_DIR}/private_key"
chmod 644 "${TMP_DIR}/public_key"

echo -e "${GREEN}✓ 鍵ファイルを取得しました${NC}"
echo ""

# 公開鍵の表示
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}📋 SSH公開鍵${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
cat "${TMP_DIR}/public_key"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Namespaceの確認
echo -e "${BLUE}Namespaceを確認中...${NC}"
if ! ${K} get namespace ${NAMESPACE} &>/dev/null; then
    echo -e "${YELLOW}Namespace '${NAMESPACE}' が存在しません。作成します...${NC}"
    ${K} create namespace ${NAMESPACE}
    echo -e "${GREEN}✓ Namespace作成完了${NC}"
else
    echo -e "${GREEN}✓ Namespace '${NAMESPACE}' が存在します${NC}"
fi
echo ""

# Secretの作成または更新
echo -e "${BLUE}Secretを作成/更新中...${NC}"
if ${K} get secret ${SECRET_NAME} -n ${NAMESPACE} &>/dev/null; then
    echo -e "${YELLOW}既存のSecret '${SECRET_NAME}' が見つかりました。更新します...${NC}"
    ${K} delete secret ${SECRET_NAME} -n ${NAMESPACE}
fi

${K} create secret generic ${SECRET_NAME} \
    --namespace=${NAMESPACE} \
    --from-file=SSH_PRIVATE_KEY="${TMP_DIR}/private_key" \
    --from-file=SSH_PUBLIC_KEY="${TMP_DIR}/public_key"

echo -e "${GREEN}✓ Secret '${SECRET_NAME}' を作成しました${NC}"
echo ""

# 確認
echo -e "${BLUE}Secretの確認:${NC}"
${K} get secret ${SECRET_NAME} -n ${NAMESPACE}
echo ""

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}   Secret作成完了${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "${BLUE}次のステップ:${NC}"
echo -e "  1. Podを再起動してSecretから鍵をマウント:"
echo -e "     ${YELLOW}kubectl rollout restart deployment/loghoi-backend -n ${NAMESPACE}${NC}"
echo ""
echo -e "${YELLOW}⚠️  注意:${NC}"
echo -e "  - このSecretを使用するには、Helm Chartのvalues.yamlで以下を設定:"
echo -e "    ${YELLOW}sshKeys.existingSecret: ${SECRET_NAME}${NC}"
echo -e "  - または、Helm upgradeを実行:"
echo -e "    ${YELLOW}helm upgrade loghoihoi ./helm/loghoihoi -n ${NAMESPACE} --set sshKeys.existingSecret=${SECRET_NAME}${NC}"
echo ""


