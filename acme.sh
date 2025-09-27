#!/bin/bash

ACME_HOME="$HOME/.acme.sh"
CERT_BASE_DIR="/root/cert"

# 绿色字体函数
green_echo() {
    echo -e "\033[1;32m$1\033[0m"
}

# 红色字体函数（用于错误提示）
red_echo() {
    echo -e "\033[1;31m$1\033[0m"
}

# 安装 acme.sh
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

# 获取已安装证书列表
get_cert_list() {
    find "$CERT_BASE_DIR" -mindepth 1 -maxdepth 1 -type d | while read dir; do
        domain=$(basename "$dir")
        echo "$domain"
    done
}

# 选择证书菜单
select_cert_menu() {
    local title="$1"
    local certs=($(get_cert_list))
    
    if [ ${#certs[@]} -eq 0 ]; then
        red_echo "未找到任何证书"
        return 1
    fi
    
    while true; do
        clear
        green_echo "=============================="
        green_echo "         $title         "
        green_echo "=============================="
        for i in "${!certs[@]}"; do
            green_echo "$(($i+1))) ${certs[$i]}"
        done
        green_echo "$((${#certs[@]}+1))) 返回主菜单"
        green_echo "=============================="
        read -p "请选择证书 [1-$((${#certs[@]}+1))]: " choice
        
        if [ "$choice" -eq $((${#certs[@]}+1)) ] 2>/dev/null; then
            return 0
        elif [ "$choice" -ge 1 ] && [ "$choice" -le ${#certs[@]} ] 2>/dev/null; then
            SELECTED_DOMAIN="${certs[$(($choice-1))]}"
            return 0
        else
            red_echo "无效选项，请重新选择！"
            sleep 2
        fi
    done
}

# 安装 Acme.sh 证书
install_acme_cert() {
    clear
    green_echo "=============================="
    green_echo "      安装 Acme.sh 证书       "
    green_echo "=============================="
    
    read -p "请输入 Acme 邮箱: " CF_Email
    export CF_Email
    read -p "请输入 Cloudflare Global API Key: " CF_Key
    export CF_Key
    read -p "请输入域名 (例如 optimized.kadi.eu.org): " DOMAIN

    CERT_DIR="$CERT_BASE_DIR/$DOMAIN"
    mkdir -p "$CERT_DIR"

    install_acme

    green_echo "正在申请 acme.sh 证书..."
    if "$ACME_HOME/acme.sh" --issue --dns dns_cf -d "$DOMAIN" -d "*.$DOMAIN"; then
        "$ACME_HOME/acme.sh" --install-cert -d "$DOMAIN" \
            --key-file       "$CERT_DIR/$DOMAIN.key" \
            --fullchain-file "$CERT_DIR/$DOMAIN.crt" \
            --reloadcmd      "echo '证书已更新: $CERT_DIR'"

        green_echo "=============================="
        green_echo "acme.sh 证书安装完成!"
        green_echo "域名: $DOMAIN"
        green_echo "Key: $CERT_DIR/$DOMAIN.key"
        green_echo "FullChain: $CERT_DIR/$DOMAIN.crt"
        green_echo "=============================="
    else
        red_echo "证书申请失败，请检查域名和API配置"
    fi
    
    read -p "按回车返回上一级..."
}

# 安装 CloudFlare 证书
install_CloudFlare_cert() {
    clear
    green_echo "=============================="
    green_echo "    安装 CloudFlare 证书      "
    green_echo "=============================="
    
    read -p "请输入 Cloudflare 邮箱: " CF_Email
    export CF_Email
    read -p "请输入 Cloudflare API Token: " CF_Token
    export CF_Token
    read -p "请输入域名 (例如 optimized.kadi.eu.org): " DOMAIN

    CERT_DIR="$CERT_BASE_DIR/$DOMAIN"
    mkdir -p "$CERT_DIR"

    green_echo "请手动从 Cloudflare 控制台下载证书文件，然后放置到以下位置:"
    green_echo "私钥文件: $CERT_DIR/$DOMAIN.key"
    green_echo "证书文件: $CERT_DIR/$DOMAIN.crt"
    green_echo ""
    green_echo "完成后按回车继续..."
    read

    if [ ! -f "$CERT_DIR/$DOMAIN.key" ] || [ ! -f "$CERT_DIR/$DOMAIN.crt" ]; then
        red_echo "错误: 证书文件未找到，请检查文件路径!"
    else
        green_echo "=============================="
        green_echo "CloudFlare 证书安装完成!"
        green_echo "域名: $DOMAIN"
        green_echo "Key: $CERT_DIR/$DOMAIN.key"
        green_echo "FullChain: $CERT_DIR/$DOMAIN.crt"
        green_echo "=============================="
    fi
    
    read -p "按回车返回上一级..."
}

# 安装证书类型选择菜单
install_cert_type_menu() {
    while true; do
        clear
        green_echo "=============================="
        green_echo "        安装证书类型选择       "
        green_echo "=============================="
        green_echo "1) 安装 Acme.sh 证书"
        green_echo "2) 安装 CloudFlare 证书"
        green_echo "3) 返回主菜单"
        green_echo "=============================="
        read -p "请选择证书类型 [1-3]: " choice
        case $choice in
            1) 
                install_acme_cert 
                ;;
            2) 
                install_CloudFlare_cert 
                ;;
            3) 
                return 0 
                ;;
            *) 
                red_echo "无效选项，请重新选择！"
                sleep 2 
                ;;
        esac
    done
}

# 更新/续签证书
renew_cert() {
    if select_cert_menu "选择要续签的证书"; then
        if [ -n "$SELECTED_DOMAIN" ]; then
            CERT_DIR="$CERT_BASE_DIR/$SELECTED_DOMAIN"
            
            if [ ! -d "$CERT_DIR" ]; then
                red_echo "错误: 证书目录不存在: $CERT_DIR"
                read -p "按回车返回上一级..."
                return 1
            fi
            
            install_acme
            green_echo "正在续签证书: $SELECTED_DOMAIN"
            if "$ACME_HOME/acme.sh" --renew -d "$SELECTED_DOMAIN" --force; then
                green_echo "证书续签完成!"
            else
                red_echo "证书续签失败!"
            fi
        fi
    fi
    read -p "按回车返回上一级..."
}

# 卸载证书
uninstall_cert() {
    if select_cert_menu "选择要卸载的证书"; then
        if [ -n "$SELECTED_DOMAIN" ]; then
            CERT_DIR="$CERT_BASE_DIR/$SELECTED_DOMAIN"
            
            if [ ! -d "$CERT_DIR" ]; then
                red_echo "错误: 证书目录不存在: $CERT_DIR"
                read -p "按回车返回上一级..."
                return 1
            fi
            
            read -p "确定要删除证书目录 $CERT_DIR 吗? (y/N): " confirm
            if [[ $confirm == [yY] ]]; then
                rm -rf "$CERT_DIR"
                green_echo "证书已卸载!"
            else
                green_echo "操作已取消!"
            fi
        fi
    fi
    read -p "按回车返回上一级..."
}

# 查看证书路径
view_cert_paths() {
    clear
    green_echo "=============================="
    green_echo "        证书存储路径          "
    green_echo "=============================="
    green_echo "证书存储路径: $CERT_BASE_DIR"
    green_echo ""
    
    local certs=($(get_cert_list))
    if [ ${#certs[@]} -eq 0 ]; then
        red_echo "未找到任何证书"
    else
        green_echo "已安装的证书:"
        for domain in "${certs[@]}"; do
            cert_file="$CERT_BASE_DIR/$domain/$domain.crt"
            green_echo "------------------------"
            green_echo "域名: $domain"
            green_echo "路径: $CERT_BASE_DIR/$domain"
            green_echo "证书文件: $cert_file"
            green_echo "私钥文件: $CERT_BASE_DIR/$domain/$domain.key"
            
            # 检查证书有效期
            if command -v openssl >/dev/null 2>&1 && [ -f "$cert_file" ]; then
                expiry=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2)
                if [ -n "$expiry" ]; then
                    green_echo "过期时间: $expiry"
                fi
            fi
        done
    fi
    
    read -p "按回车返回主菜单..."
}

# 主菜单
show_menu() {
    while true; do
        clear
        green_echo "=============================="
        green_echo "       证书安装管理菜单        "
        green_echo "=============================="
        green_echo "1) 安装证书"
        green_echo "2) 更新/续签证书"
        green_echo "3) 卸载证书"
        green_echo "4) 查看证书路径"
        green_echo "5) 退出脚本"
        green_echo "=============================="
        read -p "请选择操作 [1-5]: " choice
        case $choice in
            1) 
                install_cert_type_menu
                ;;
            2) 
                renew_cert 
                ;;
            3) 
                uninstall_cert 
                ;;
            4) 
                view_cert_paths 
                ;;
            5) 
                green_echo "再见!"
                exit 0 
                ;;
            *) 
                red_echo "无效选项，请重新选择！"
                sleep 2 
                ;;
        esac
    done
}

# 检查是否以root运行
if [ "$EUID" -ne 0 ]; then
    red_echo "警告: 建议以root用户运行此脚本以获得最佳权限"
    read -p "是否继续? (y/N): " continue_as_user
    if [[ $continue_as_user != [yY] ]]; then
        exit 1
    fi
fi

show_menu
