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

# 选择证书菜单
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
            green_echo "=============================="
            read -p "请选择 [0]: " choice
            if [ "$choice" -eq 0 ] 2>/dev/null; then
                return 0
            else
                red_echo "无效选项，请重新选择！"
                sleep 2
            fi
        else
            for i in "${!certs[@]}"; do
                green_echo "$(($i+1))) ${certs[$i]}"
            done
            green_echo "0) 返回主菜单"
            green_echo "=============================="
            read -p "请选择证书 [1-${#certs[@]}] 或 [0返回]: " choice
            
            if [ "$choice" -eq 0 ] 2>/dev/null; then
                return 0
            elif [ "$choice" -ge 1 ] && [ "$choice" -le ${#certs[@]} ] 2>/dev/null; then
                SELECTED_DOMAIN="${certs[$(($choice-1))]}"
                return 0
            else
                red_echo "无效选项，请重新选择！"
                sleep 2
            fi
        fi
    done
}

# 安装 GetSSL 证书（修复版）
install_getssl_cert() {
    clear
    green_echo "=============================="
    green_echo "       安装 GetSSL 证书       "
    green_echo "=============================="
    
    read -p "请输入邮箱: " EMAIL
    read -p "请输入域名 (例如 example.com): " DOMAIN

    CERT_DIR="$CERT_BASE_DIR/$DOMAIN"
    mkdir -p "$CERT_DIR"

    green_echo "正在安装 GetSSL 证书..."
    
    # 检查是否已安装 getssl
    if ! command -v getssl &> /dev/null; then
        green_echo "正在安装 getssl..."
        curl --silent https://raw.githubusercontent.com/srvrco/getssl/latest/getssl > /usr/local/bin/getssl
        chmod 700 /usr/local/bin/getssl
    fi

    # 创建 getssl 配置
    getssl -c "$DOMAIN"
    
    # 配置 getssl
    local getssl_dir="$HOME/.getssl"
    local config_file="$getssl_dir/$DOMAIN/getssl.cfg"
    
    if [ -f "$config_file" ]; then
        # 更新配置文件 - 修复 ACL 和验证方式
        sed -i "s/^ACCOUNT_EMAIL=.*/ACCOUNT_EMAIL=\"$EMAIL\"/" "$config_file"
        sed -i "s|^CA=.*|CA=\"https://acme-v02.api.letsencrypt.org\"|" "$config_file"
        
        # 使用 DNS 验证方式（更可靠）
        echo "VALIDATE_VIA_DNS=\"true\"" >> "$config_file"
        echo "DNS_ADD_COMMAND=\"/root/.getssl/dns_add.sh\"" >> "$config_file"
        echo "DNS_DEL_COMMAND=\"/root/.getssl/dns_del.sh\"" >> "$config_file"
        
        # 创建 DNS 验证脚本（需要手动配置）
        cat > "/root/.getssl/dns_add.sh" << 'EOF'
#!/bin/bash
# 这里需要您配置 DNS API
# 示例使用 Cloudflare API
echo "请手动在 DNS 中添加 TXT 记录:"
echo "名称: _acme-challenge.$1"
echo "值: $2"
echo "按回车继续..."
read
EOF
        
        chmod +x "/root/.getssl/dns_add.sh"
        
        cat > "/root/.getssl/dns_del.sh" << 'EOF'
#!/bin/bash
echo "DNS 记录清理脚本"
EOF
        chmod +x "/root/.getssl/dns_del.sh"
        
        green_echo "GetSSL 配置完成，但需要手动 DNS 验证"
        green_echo "请按以下步骤操作："
        green_echo "1. 在 DNS 提供商处添加 TXT 记录"
        green_echo "2. 名称: _acme-challenge.$DOMAIN"
        green_echo "3. 值: (将在下一步显示)"
        green_echo ""
        read -p "按回车继续获取验证值..."
        
        # 尝试获取证书（会显示需要添加的 DNS 记录）
        if getssl "$DOMAIN"; then
            # 复制证书到指定目录
            cp "$getssl_dir/$DOMAIN/$DOMAIN.crt" "$CERT_DIR/$DOMAIN.crt"
            cp "$getssl_dir/$DOMAIN/$DOMAIN.key" "$CERT_DIR/$DOMAIN.key"
            
            green_echo "=============================="
            green_echo "GetSSL 证书安装完成!"
            green_echo "域名: $DOMAIN"
            green_echo "Key: $CERT_DIR/$DOMAIN.key"
            green_echo "FullChain: $CERT_DIR/$DOMAIN.crt"
            green_echo "=============================="
        else
            red_echo "GetSSL 证书申请失败，请检查 DNS 配置"
            green_echo "建议使用 CloudFlare 证书方式（选项2）"
        fi
    else
        red_echo "GetSSL 配置创建失败"
    fi
    
    read -p "按回车返回上一级..."
}

# 安装 CloudFlare 证书（推荐方式）
install_CloudFlare_cert() {
    clear
    green_echo "=============================="
    green_echo "    安装 CloudFlare 证书      "
    green_echo "=============================="
    
    green_echo "推荐使用此方式，自动完成 DNS 验证"
    echo ""
    
    read -p "请输入 Cloudflare 邮箱: " CF_Email
    read -p "请输入 Cloudflare Global API Key: " CF_Key
    read -p "请输入域名 (例如 example.com): " DOMAIN

    CERT_DIR="$CERT_BASE_DIR/$DOMAIN"
    mkdir -p "$CERT_DIR"

    export CF_Email="$CF_Email"
    export CF_Key="$CF_Key"

    install_acme

    green_echo "正在申请 CloudFlare 证书..."
    green_echo "这将自动完成 DNS 验证..."
    
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
        red_echo "CloudFlare 证书申请失败，请检查："
        red_echo "1. API Key 是否正确"
        red_echo "2. 域名是否在 Cloudflare 管理中"
        red_echo "3. DNS 解析是否正常"
    fi
    
    read -p "按回车返回上一级..."
}

# 安装证书类型选择菜单
install_cert_menu() {
    while true; do
        clear
        green_echo "=============================="
        green_echo "        安装证书类型选择       "
        green_echo "=============================="
        green_echo "1) 安装 GetSSL 证书 (需要手动DNS验证)"
        green_echo "2) 安装 CloudFlare 证书 (推荐，自动DNS验证)"
        green_echo "0) 返回主菜单"
        green_echo "=============================="
        read -p "请选择证书类型 [1-2] 或 [0返回]: " choice
        case $choice in
            1) 
                install_getssl_cert 
                ;;
            2) 
                install_CloudFlare_cert 
                ;;
            0) 
                return 0 
                ;;
            *) 
                red_echo "无效选项，请重新选择！"
                sleep 2 
                ;;
        esac
    done
}

# 更新/修改证书
update_cert() {
    if select_cert_menu "选择要更新/修改的证书"; then
        if [ -n "$SELECTED_DOMAIN" ]; then
            CERT_DIR="$CERT_BASE_DIR/$SELECTED_DOMAIN"
            
            if [ ! -d "$CERT_DIR" ]; then
                red_echo "错误: 证书目录不存在: $CERT_DIR"
                read -p "按回车返回上一级..."
                return 1
            fi
            
            green_echo "正在更新证书: $SELECTED_DOMAIN"
            install_acme
            
            if "$ACME_HOME/acme.sh" --renew -d "$SELECTED_DOMAIN" --force; then
                green_echo "证书更新完成!"
            else
                red_echo "证书更新失败!"
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
        green_echo "2) 更新/修改证书"
        green_echo "3) 卸载证书"
        green_echo "4) 查看证书路径"
        green_echo "0) 退出脚本"
        green_echo "=============================="
        read -p "请选择操作 [1-4] 或 [0退出]: " choice
        case $choice in
            1) 
                install_cert_menu
                ;;
            2) 
                update_cert 
                ;;
            3) 
                uninstall_cert 
                ;;
            4) 
                view_cert_paths 
                ;;
            0) 
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
