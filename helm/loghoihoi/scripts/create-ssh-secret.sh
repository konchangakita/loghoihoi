#!/bin/bash
# SSH鍵のSecret作成スクリプト
# 既存のSSH鍵を使用してKubernetes Secretを作成します

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
SSH_KEY_DIR="${SSH_KEY_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)/config/.ssh}"
SSH_PRIVATE_KEY="${SSH_PRIVATE_KEY:-${SSH_KEY_DIR}/loghoi-key}"
SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY:-${SSH_KEY_DIR}/loghoi-key.pub}"

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}   SSH Key Secret Creation${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "Namespace: ${YELLOW}${NAMESPACE}${NC}"
echo -e "Private key: ${YELLOW}${SSH_PRIVATE_KEY}${NC}"
echo -e "Public key: ${YELLOW}${SSH_PUBLIC_KEY}${NC}"
echo ""

# kubectlコマンドの構築
K="kubectl"
if [ -n "${KUBECONFIG_PATH}" ]; then
    K="kubectl --kubeconfig=${KUBECONFIG_PATH}"
fi

# SSH鍵の確認
if [ ! -f "${SSH_PRIVATE_KEY}" ] || [ ! -f "${SSH_PUBLIC_KEY}" ]; then
    echo -e "${YELLOW}SSH鍵が見つかりません。新規生成しますか？${NC}"
    echo -e "${BLUE}SSH鍵を生成します...${NC}"
    
    # SSH鍵ディレクトリの作成
    mkdir -p "$(dirname "${SSH_PRIVATE_KEY}")"
    chmod 700 "$(dirname "${SSH_PRIVATE_KEY}")"
    
    # SSH鍵の生成
    ssh-keygen -t rsa -b 4096 \
        -f "${SSH_PRIVATE_KEY}" \
        -N "" \
        -C "loghoi@kubernetes" \
        >/dev/null 2>&1
    
    chmod 600 "${SSH_PRIVATE_KEY}"
    chmod 644 "${SSH_PUBLIC_KEY}"
    echo -e "${GREEN}✓ SSH鍵を生成しました${NC}"
    echo ""
    echo -e "${RED}⚠️⚠️⚠️  必須作業: Nutanix Prismへの公開鍵登録  ⚠️⚠️⚠️${NC}"
    echo ""
    echo -e "${YELLOW}公開鍵:${NC}"
    cat "${SSH_PUBLIC_KEY}"
    echo ""
    echo -e "${YELLOW}1️⃣ Prism Element > Settings > Cluster Lockdown${NC}"
    echo -e "${YELLOW}2️⃣ 「Add Public Key」をクリック${NC}"
    echo -e "${YELLOW}3️⃣ 上記の公開鍵を貼り付けて保存${NC}"
    echo ""
    read -p "公開鍵の登録は完了しましたか？ (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Secretの作成を中断します。公開鍵を登録してから再実行してください。${NC}"
        exit 1
    fi
fi

# SSH鍵ファイルの読み取り権限チェック
echo -e "${BLUE}SSH鍵の読み取り権限を確認中...${NC}"
if ! cat "${SSH_PRIVATE_KEY}" >/dev/null 2>&1; then
    echo -e "${RED}⚠️  警告: SSH秘密鍵を読み取れません${NC}"
    echo -e "${YELLOW}対処方法:${NC}"
    echo -e "  sudo chown $(whoami):$(whoami) ${SSH_PRIVATE_KEY} ${SSH_PUBLIC_KEY}"
    exit 1
fi

if ! cat "${SSH_PUBLIC_KEY}" >/dev/null 2>&1; then
    echo -e "${RED}⚠️  警告: SSH公開鍵を読み取れません${NC}"
    echo -e "${YELLOW}対処方法:${NC}"
    echo -e "  sudo chown $(whoami):$(whoami) ${SSH_PRIVATE_KEY} ${SSH_PUBLIC_KEY}"
    exit 1
fi

echo -e "${GREEN}✓ SSH鍵の読み取り権限OK${NC}"
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
echo -e "${BLUE}Secretを作成中...${NC}"
if ${K} get secret loghoi-secrets -n ${NAMESPACE} &>/dev/null; then
    echo -e "${YELLOW}Secret 'loghoi-secrets' が既に存在します${NC}"
    read -p "上書きしますか？ (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ${K} delete secret loghoi-secrets -n ${NAMESPACE}
        echo -e "${GREEN}✓ 既存のSecretを削除しました${NC}"
    else
        echo -e "${YELLOW}Secretの作成をスキップします${NC}"
        exit 0
    fi
fi

${K} create secret generic loghoi-secrets \
    --namespace=${NAMESPACE} \
    --from-file=SSH_PRIVATE_KEY="${SSH_PRIVATE_KEY}" \
    --from-file=SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY}"

echo -e "${GREEN}✓ Secret 'loghoi-secrets' を作成しました${NC}"
echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}   Secret作成完了${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "${BLUE}次のステップ:${NC}"
echo -e "  helm install loghoihoi ./helm/loghoihoi --namespace ${NAMESPACE}"
echo ""

