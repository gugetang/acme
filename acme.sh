#!/bin/bash

ACME_HOME="$HOME/.acme.sh"
CERT_BASE_DIR="/root/cert"

# 安装 acme.sh
install_acme() {
    if [ ! -f "$ACME_HOME/acme.sh" ]; then
        echo "acme.sh 未安装，正在安装..."
        curl https://get.acme.sh | sh
        source ~/.bashrc
    fi
    export PATH="$ACME_HOME:$PATH"
    "$ACME_HOME/acme.sh" --set-default-ca --server letsencrypt
    "$ACME_HOME/acme.sh" --upgrade --auto-upgrade
}

# 安装 acme.sh 证书
install_acme_cert() {
    read -p "请输入 Cloudflare 邮箱: " CF_Email
    export CF_Email
    read -p "请输入 Cloudflare API Token: " CF_Token
    export CF_Token
    read -p "请输入域名 (例如 optimized.kadi.eu.org): " DOMAIN

    CERT_DIR="$CERT_BASE_DIR/$DOMAIN"
    mkdir -p "$CERT_DIR"

    install_acme

    echo "正在申请 acme.sh 证书..."
    "$ACME_HOME/acme.sh" --issue --dns dns_cf -d "$DOMAIN" -d "*.$DOMAIN"
    "$ACME_HOME/acme.sh" --install-cert -d "$DOMAIN" \
        --key-file       "$CERT_DIR/$DOMAIN.key" \
        --fullchain-file "$CERT_DIR/$DOMAIN.crt" \
        --reloadcmd      "echo '证书已更新: $CERT_DIR'"

    echo "=============================="
    echo "acme.sh 证书安装完成!"
    echo "域名: $DOMAIN"
    echo "Key: $CERT_DIR/$DOMAIN.key"
    echo "FullChain: $CERT_DIR/$DOMAIN.crt"
    echo "=============================="
    read -p "按回车返回菜单..."
}

# 安装 SF 证书（示例逻辑，可根据实际修改）
install_sf_cert() {
    read -p "请输入域名 (例如 sf.example.com): " DOMAIN
    CERT_DIR="$CERT_BASE_DIR/$DOMAIN"
    mkdir -p "$CERT_DIR"

    # 示例：这里你可以放 SF 证书安装逻辑
    echo "模拟安装 SF 证书..."
    echo "SF_KEY_CONTENT" > "$CERT_DIR/$DOMAIN.key"
    echo "SF_CERT_CONTENT" > "$CERT_DIR/$DOMAIN.crt"

    echo "=============================="
    echo "SF 证书安装完成!"
    echo "域名: $DOMAIN"
    echo "Key: $CERT_DIR/$DOMAIN.key"
    echo "FullChain: $CERT_DIR/$DOMAIN.crt"
    echo "=============================="
    read -p "按回车返回菜单..."
}

# 主菜单
show_menu() {
    while true; do
        clear
        echo "=============================="
        echo "       证书安装管理菜单         "
        echo "=============================="
        echo "1) 安装证书"
        echo "2) 更新/续签证书"
        echo "3) 卸载证书"
        echo "4) 查看证书路径"
        echo "0) 退出"
        echo "=============================="
        read -p "请选择操作 [0-4]: " choice
        case $choice in
            1) 
                # 安装证书子菜单
                clear
                echo "1) 安装 acme.sh 证书"
                echo "2) 安装 SF 证书"
                read -p "请选择 [1-2]: " sub_choice
                case $sub_choice in
                    1) install_acme_cert ;;
                    2) install_sf_cert ;;
                    *) echo "无效选项"; sleep 2 ;;
                esac
                ;;
            2) echo "续签功能待实现"; read -p "按回车返回菜单..." ;;
            3) echo "卸载功能待实现"; read -p "按回车返回菜单..." ;;
            4) echo "查看证书路径功能待实现"; read -p "按回车返回菜单..." ;;
            0) exit 0 ;;
            *) echo "无效选项，请重新选择！"; sleep 2 ;;
        esac
    done
}

show_menu
