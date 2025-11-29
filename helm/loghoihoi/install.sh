#!/bin/bash
# Helm Chartインストールラッパースクリプト
# SSH鍵の自動チェック・生成を行い、Helm Chartをインストールします

set -e

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 設定
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHART_DIR="${SCRIPT_DIR}"
SSH_KEY_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)/config/.ssh"
SSH_PRIVATE_KEY="${SSH_KEY_DIR}/loghoi-key"
SSH_PUBLIC_KEY="${SSH_KEY_DIR}/loghoi-key.pub"
NAMESPACE="${NAMESPACE:-loghoihoi}"
KUBECONFIG_PATH="${KUBECONFIG:-}"

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}   LogHoihoi Helm Chart Installer${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "Chart directory: ${YELLOW}${CHART_DIR}${NC}"
echo -e "Namespace: ${YELLOW}${NAMESPACE}${NC}"
echo ""

# kubectlコマンドの構築
K="kubectl"
if [ -n "${KUBECONFIG_PATH}" ]; then
    K="kubectl --kubeconfig=${KUBECONFIG_PATH}"
    export KUBECONFIG="${KUBECONFIG_PATH}"
fi

# SSH鍵ディレクトリの作成
if [ ! -d "${SSH_KEY_DIR}" ]; then
    echo -e "${YELLOW}Creating SSH key directory...${NC}"
    mkdir -p "${SSH_KEY_DIR}"
    chmod 700 "${SSH_KEY_DIR}"
    echo -e "${GREEN}✓ Directory created: ${SSH_KEY_DIR}${NC}"
else
    chmod 700 "${SSH_KEY_DIR}"
fi

# SSH鍵の生成または確認
if [ -f "${SSH_PRIVATE_KEY}" ] && [ -f "${SSH_PUBLIC_KEY}" ]; then
    echo -e "${GREEN}✓ Existing SSH key pair found${NC}"
    echo -e "  Private key: ${BLUE}${SSH_PRIVATE_KEY}${NC}"
    echo -e "  Public key: ${BLUE}${SSH_PUBLIC_KEY}${NC}"
    KEYS_GENERATED=false
else
    echo -e "${YELLOW}Generating new SSH key pair...${NC}"
    ssh-keygen -t rsa -b 4096 \
        -f "${SSH_PRIVATE_KEY}" \
        -N "" \
        -C "loghoi@kubernetes" \
        >/dev/null 2>&1
    
    chmod 600 "${SSH_PRIVATE_KEY}"
    chmod 644 "${SSH_PUBLIC_KEY}"
    echo -e "${GREEN}✓ SSH key pair generated successfully${NC}"
    KEYS_GENERATED=true
fi

if [ "$KEYS_GENERATED" = true ]; then
    echo ""
    echo -e "${RED}🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨${NC}"
    echo -e "${RED}🚨                                        🚨${NC}"
    echo -e "${RED}🚨  新しいSSH公開鍵が生成されました！    🚨${NC}"
    echo -e "${RED}🚨                                        🚨${NC}"
    echo -e "${RED}🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨${NC}"
    echo ""
    echo -e "${RED}⚠️⚠️⚠️  必須作業: Nutanix Prismへの公開鍵登録  ⚠️⚠️⚠️${NC}"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}📋 SSH公開鍵${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    cat "${SSH_PUBLIC_KEY}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}1️⃣ Prism Element > Settings > Cluster Lockdown${NC}"
    echo -e "${YELLOW}2️⃣ 「Add Public Key」をクリック${NC}"
    echo -e "${YELLOW}3️⃣ 上記の公開鍵を貼り付けて保存${NC}"
    echo ""
    echo -e "${GREEN}💡 ヒント:${NC}"
    echo -e "   - アプリUI起動後、右上の「${BLUE}Open SSH KEY${NC}」ボタンからも確認可能"
    echo -e "   - クリックでクリップボードにコピーされます"
    echo ""
    read -p "公開鍵の登録は完了しましたか？ (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}インストールを中断します。公開鍵を登録してから再実行してください。${NC}"
        exit 1
    fi
else
    echo -e "${BLUE}ℹ️  既存のSSH鍵を使用します${NC}"
fi

# SSH鍵ファイルの読み取り権限チェック
echo ""
echo -e "${BLUE}Checking SSH key permissions...${NC}"
CURRENT_USER=$(whoami)

if ! cat "${SSH_PRIVATE_KEY}" >/dev/null 2>&1; then
    echo -e "${RED}⚠️  警告: SSH秘密鍵を読み取れません${NC}"
    echo -e "${YELLOW}対処方法:${NC}"
    echo -e "  sudo chown ${CURRENT_USER}:${CURRENT_USER} ${SSH_PRIVATE_KEY} ${SSH_PUBLIC_KEY}"
    exit 1
fi

if ! cat "${SSH_PUBLIC_KEY}" >/dev/null 2>&1; then
    echo -e "${RED}⚠️  警告: SSH公開鍵を読み取れません${NC}"
    echo -e "${YELLOW}対処方法:${NC}"
    echo -e "  sudo chown ${CURRENT_USER}:${CURRENT_USER} ${SSH_PRIVATE_KEY} ${SSH_PUBLIC_KEY}"
    exit 1
fi

echo -e "${GREEN}✓ SSH keys are readable${NC}"
echo ""

# Namespaceの確認
echo -e "${BLUE}Checking namespace...${NC}"
if ! ${K} get namespace ${NAMESPACE} &>/dev/null; then
    echo -e "${YELLOW}Creating namespace '${NAMESPACE}'...${NC}"
    ${K} create namespace ${NAMESPACE}
    echo -e "${GREEN}✓ Namespace created${NC}"
else
    echo -e "${GREEN}✓ Namespace '${NAMESPACE}' exists${NC}"
fi
echo ""

# Secretの作成または確認
echo -e "${BLUE}Creating or checking Secret...${NC}"
if ${K} get secret loghoi-secrets -n ${NAMESPACE} &>/dev/null; then
    echo -e "${GREEN}✓ Secret 'loghoi-secrets' already exists${NC}"
    read -p "既存のSecretを上書きしますか？ (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ${K} delete secret loghoi-secrets -n ${NAMESPACE}
        echo -e "${GREEN}✓ Existing Secret deleted${NC}"
    else
        echo -e "${BLUE}ℹ️  既存のSecretを使用します${NC}"
        SKIP_SECRET=true
    fi
fi

if [ "${SKIP_SECRET:-false}" != "true" ]; then
    ${K} create secret generic loghoi-secrets \
        --namespace=${NAMESPACE} \
        --from-file=SSH_PRIVATE_KEY="${SSH_PRIVATE_KEY}" \
        --from-file=SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY}"
    echo -e "${GREEN}✓ Secret 'loghoi-secrets' created${NC}"
fi
echo ""

# Helm Chartのインストール
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}   Installing Helm Chart${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# 残りの引数をHelmに渡す
helm install loghoihoi "${CHART_DIR}" \
    --namespace=${NAMESPACE} \
    "$@"

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}   Installation Complete${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "${BLUE}次のステップ:${NC}"
echo -e "  kubectl get pods -n ${NAMESPACE}"
echo -e "  kubectl get svc,ingress -n ${NAMESPACE}"
echo ""




