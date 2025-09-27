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
    read -p "请输入 Acme 邮箱: " CF_Email
    export CF_Email
    read -p "请输入 Cloudflare Global API Key: " CF_Key
    export CF_Key
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

# 安装 CloudFlare 证书
install_CloudFlare_cert() {
    read -p "请输入 Cloudflare 邮箱: " CF_Email
    export CF_Email
    read -p "请输入 Cloudflare API Token: " CF_Token
    export CF_Token
    read -p "请输入域名 (例如 optimized.kadi.eu.org): " DOMAIN

    CERT_DIR="$CERT_BASE_DIR/$DOMAIN"
    mkdir -p "$CERT_DIR"

    echo "请手动从 Cloudflare 控制台下载证书文件，然后放置到以下位置:"
    echo "私钥文件: $CERT_DIR/$DOMAIN.key"
    echo "证书文件: $CERT_DIR/$DOMAIN.crt"
    echo ""
    echo "完成后按回车继续..."
    read

    if [ ! -f "$CERT_DIR/$DOMAIN.key" ] || [ ! -f "$CERT_DIR/$DOMAIN.crt" ]; then
        echo "错误: 证书文件未找到，请检查文件路径!"
        read -p "按回车返回菜单..."
        return 1
    fi

    echo "=============================="
    echo "CloudFlare 证书安装完成!"
    echo "域名: $DOMAIN"
    echo "Key: $CERT_DIR/$DOMAIN.key"
    echo "FullChain: $CERT_DIR/$DOMAIN.crt"
    echo "=============================="
    read -p "按回车返回菜单..."
}

# 更新/续签证书
renew_cert() {
    install_acme
    
    echo "可续签的证书:"
    find "$CERT_BASE_DIR" -name "*.crt" -type f | while read cert; do
        domain=$(basename "$cert" .crt)
        echo "- $domain"
    done
    
    read -p "请输入要续签的域名: " DOMAIN
    CERT_DIR="$CERT_BASE_DIR/$DOMAIN"
    
    if [ ! -d "$CERT_DIR" ]; then
        echo "错误: 证书目录不存在: $CERT_DIR"
        read -p "按回车返回菜单..."
        return 1
    fi
    
    echo "正在续签证书..."
    "$ACME_HOME/acme.sh" --renew -d "$DOMAIN" --force
    echo "证书续签完成!"
    read -p "按回车返回菜单..."
}

# 卸载证书
uninstall_cert() {
    echo "已安装的证书:"
    find "$CERT_BASE_DIR" -mindepth 1 -maxdepth 1 -type d | while read dir; do
        domain=$(basename "$dir")
        echo "- $domain"
    done
    
    read -p "请输入要卸载的域名: " DOMAIN
    CERT_DIR="$CERT_BASE_DIR/$DOMAIN"
    
    if [ ! -d "$CERT_DIR" ]; then
        echo "错误: 证书目录不存在: $CERT_DIR"
        read -p "按回车返回菜单..."
        return 1
    fi
    
    read -p "确定要删除证书目录 $CERT_DIR 吗? (y/N): " confirm
    if [[ $confirm == [yY] ]]; then
        rm -rf "$CERT_DIR"
        echo "证书已卸载!"
    else
        echo "操作已取消!"
    fi
    read -p "按回车返回菜单..."
}

# 查看证书路径
view_cert_paths() {
    echo "证书存储路径: $CERT_BASE_DIR"
    echo ""
    echo "已安装的证书:"
    find "$CERT_BASE_DIR" -name "*.crt" -type f | while read cert; do
        domain=$(basename "$cert" .crt)
        dir=$(dirname "$cert")
        echo "域名: $domain"
        echo "路径: $dir"
        echo "证书文件: $cert"
        echo "私钥文件: $dir/$domain.key"
        
        # 检查证书有效期
        if command -v openssl >/dev/null 2>&1; then
            expiry=$(openssl x509 -in "$cert" -noout -enddate 2>/dev/null | cut -d= -f2)
            if [ -n "$expiry" ]; then
                echo "过期时间: $expiry"
            fi
        fi
        echo "------------------------"
    done
    
    if [ -z "$(find "$CERT_BASE_DIR" -name "*.crt" -type f)" ]; then
        echo "未找到任何证书"
    fi
    
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
                echo "1) 安装 Acme.sh 证书 (自动申请)"
                echo "2) 安装 CloudFlare 证书 (手动上传)"
                read -p "请选择 [1-2]: " sub_choice
                case $sub_choice in
                    1) install_acme_cert ;;
                    2) install_CloudFlare_cert ;;
                    *) echo "无效选项"; sleep 2 ;;
                esac
                ;;
            2) renew_cert ;;
            3) uninstall_cert ;;
            4) view_cert_paths ;;
            0) 
                echo "再见!"
                exit 0 
                ;;
            *) 
                echo "无效选项，请重新选择！"
                sleep 2 
                ;;
        esac
    done
}

# 检查是否以root运行
if [ "$EUID" -ne 0 ]; then
    echo "警告: 建议以root用户运行此脚本以获得最佳权限"
    read -p "是否继续? (y/N): " continue_as_user
    if [[ $continue_as_user != [yY] ]]; then
        exit 1
    fi
fi

show_menu
