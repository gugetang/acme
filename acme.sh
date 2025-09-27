#!/bin/bash

# ==========================
# Cloudflare 自动 DNS 证书管理脚本
# ==========================

ACME_HOME="$HOME/.acme.sh"
CERT_BASE_DIR="/root/cert"

green_echo() { echo -e "\033[1;32m$1\033[0m"; }
red_echo()   { echo -e "\033[1;31m$1\033[0m"; }

# ==========================
# 安装 acme.sh
# ==========================
install_acme() {
    if [ ! -f "$ACME_HOME/acme.sh" ]; then
        green_echo "acme.sh 未安装，正在安装..."
        curl https://get.acme.sh | sh
        source ~/.bashrc
    fi
    export PATH="$ACME_HOME:$PATH"
    "$ACME_HOME/acme.sh" --set-default-ca --server letsencrypt
    "$ACME_HOME/acme.sh" --upgrade --auto-upgrade
}

# ==========================
# 获取已安装证书列表
# ==========================
get_cert_list() {
    local certs=()
    if [ -d "$CERT_BASE_DIR" ]; then
        while IFS= read -r -d '' dir; do
            domain=$(basename "$dir")
            if [ -f "$dir/$domain.crt" ] && [ -f "$dir/$domain.key" ]; then
                certs+=("$domain")
            fi
        done < <(find "$CERT_BASE_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    fi
    printf '%s\n' "${certs[@]}"
}

# ==========================
# 选择证书菜单
# ==========================
select_cert_menu() {
    local title="$1"
    local certs=($(get_cert_list))
    local choice
    
    while true; do
        clear
        green_echo "=============================="
        green_echo "         $title         "
        green_echo "=============================="
        
        if [ ${#certs[@]} -eq 0 ]; then
            red_echo "未找到任何证书"
            green_echo "0) 返回主菜单"
            read -p "请选择 [0]: " choice
            [[ "$choice" -eq 0 ]] && return 0
            red_echo "无效选项，请重新选择！"
            sleep 2
        else
            for i in "${!certs[@]}"; do
                green_echo "$(($i+1))) ${certs[$i]}"
            done
            green_echo "0) 返回主菜单"
            read -p "请选择证书 [1-${#certs[@]}] 或 [0返回]: " choice
            if [[ "$choice" -eq 0 ]]; then return 0; fi
            if [[ "$choice" -ge 1 && "$choice" -le ${#certs[@]} ]]; then
                SELECTED_DOMAIN="${certs[$(($choice-1))]}"
                return 0
            fi
            red_echo "无效选项，请重新选择！"
            sleep 2
        fi
    done
}

# ==========================
# 安装 CloudFlare 证书
# ==========================
install_CloudFlare_cert() {
    clear
    green_echo "=============================="
    green_echo "    安装 CloudFlare 证书      "
    green_echo "=============================="

    read -p "请输入 Cloudflare 邮箱: " CF_Email
    read -p "请输入 Cloudflare Global API Key: " CF_Key
    read -p "请输入域名 (例如 example.com): " DOMAIN

    CERT_DIR="$CERT_BASE_DIR/$DOMAIN"
    mkdir -p "$CERT_DIR"

    export CF_Email="$CF_Email"
    export CF_Key="$CF_Key"

    install_acme

    green_echo "正在申请 CloudFlare 证书（含泛域名）..."
    
    if "$ACME_HOME/acme.sh" --issue --dns dns_cf -d "$DOMAIN" -d "*.$DOMAIN"; then
        "$ACME_HOME/acme.sh" --install-cert -d "$DOMAIN" \
            --key-file       "$CERT_DIR/$DOMAIN.key" \
            --fullchain-file "$CERT_DIR/$DOMAIN.crt" \
            --reloadcmd      "echo '证书已更新: $CERT_DIR'"

        green_echo "=============================="
        green_echo "CloudFlare 证书安装完成!"
        green_echo "域名: $DOMAIN"
        green_echo "Key: $CERT_DIR/$DOMAIN.key"
        green_echo "FullChain: $CERT_DIR/$DOMAIN.crt"
        green_echo "=============================="
    else
        red_echo "CloudFlare 证书申请失败，请检查 API Key 和域名"
    fi
    read -p "按回车返回上一级..."
}

# ==========================
# 更新证书
# ==========================
update_cert() {
    if select_cert_menu "选择要更新/修改的证书"; then
        if [ -n "$SELECTED_DOMAIN" ]; then
            CERT_DIR="$CERT_BASE_DIR/$SELECTED_DOMAIN"
            install_acme
            "$ACME_HOME/acme.sh" --renew -d "$SELECTED_DOMAIN" --force && green_echo "证书更新完成!"
        fi
    fi
    read -p "按回车返回上一级..."
}

# ==========================
# 卸载证书
# ==========================
uninstall_cert() {
    if select_cert_menu "选择要卸载的证书"; then
        if [ -n "$SELECTED_DOMAIN" ]; then
            CERT_DIR="$CERT_BASE_DIR/$SELECTED_DOMAIN"
            read -p "确定删除 $CERT_DIR 吗? (y/N): " confirm
            [[ "$confirm" =~ ^[yY]$ ]] && rm -rf "$CERT_DIR" && green_echo "证书已卸载!"
        fi
    fi
    read -p "按回车返回上一级..."
}

# ==========================
# 查看证书路径
# ==========================
view_cert_paths() {
    clear
    green_echo "=====================_
