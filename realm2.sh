#!/bin/bash

# realm2 安装脚本
# 作者: seal0207
# 功能: 自动安装和配置realm2服务

set -e  # 遇到错误立即退出

# 颜色定义用于输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查系统是否为Debian 11
check_os() {
    if [ ! -f /etc/os-release ]; then
        log_error "无法检测操作系统类型"
        exit 1
    fi
    
    source /etc/os-release
    if [ "$ID" != "debian" ] || [ "$VERSION_ID" != "11" ]; then
        log_warn "检测到系统: $NAME $VERSION"
        log_warn "此脚本专为Debian 11设计，在其他系统上可能无法正常工作"
        read -p "是否继续? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "安装已取消"
            exit 0
        fi
    else
        log_info "检测到系统: Debian 11"
    fi
}

# 检查是否以root权限运行
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用root权限运行此脚本"
        exit 1
    fi
}

# 检查realm2是否已安装
check_existing_installation() {
    if [ -d "/etc/realm2" ]; then
        log_warn "检测到realm2目录已存在: /etc/realm2"
        read -p "是否重新安装? (将覆盖现有配置) (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "安装已取消"
            exit 0
        else
            # 停止现有服务
            if systemctl is-active --quiet realm2 2>/dev/null; then
                log_info "停止正在运行的realm2服务..."
                systemctl stop realm2
            fi
            
            # 禁用服务
            if systemctl is-enabled --quiet realm2 2>/dev/null; then
                log_info "禁用realm2服务..."
                systemctl disable realm2
            fi
            
            # 清理进程
            if pgrep -f '/etc/realm2/realm2' > /dev/null; then
                log_info "清理现有realm2进程..."
                pkill -f '/etc/realm2/realm2'
                sleep 2
            fi
        fi
    fi
}

# 安装依赖
install_dependencies() {
    log_info "安装必要的依赖包..."
    apt update
    apt install -y wget curl systemd
}

# 创建目录结构
create_directories() {
    log_info "创建目录结构..."
    mkdir -p /etc/realm2
    mkdir -p /etc/realm2/rules
    mkdir -p /var/log/realm2
}

# 下载realm2程序
download_realm2() {
    log_info "下载realm2主程序..."
    cd /etc/realm2
    
    if wget -q --timeout=30 --tries=3 -O realm2 "https://raw.githubusercontent.com/seal0207/realm2/refs/heads/main/realm2"; then
        chmod +x realm2
        log_info "realm2主程序下载成功"
    else
        log_error "realm2主程序下载失败"
        exit 1
    fi
}

# 创建启动脚本
create_start_script() {
    log_info "创建启动脚本..."
    cat > /etc/realm2/start-realm2.sh << 'EOF'
#!/bin/bash
pkill -f '/etc/realm2/realm2'

for rule_file in /etc/realm2/rules/*; do
 /etc/realm2/realm2 -c "$rule_file" &
done
wait
EOF

    chmod +x /etc/realm2/start-realm2.sh
}

# 创建systemd服务文件
create_systemd_service() {
    log_info "创建systemd服务文件..."
    cat > /etc/systemd/system/realm2.service << 'EOF'
[Unit]
Description=realm2
After=network.target
Wants=network.target

[Service]
Type=simple
StandardError=none
User=root
LimitAS=infinity
LimitCORE=infinity
LimitNOFILE=102400
LimitNPROC=102400
ExecStart=/etc/realm2/start-realm2.sh
ExecReload=/bin/kill -HUP $MAINPID
ExecStop=/bin/kill $MAINPID
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
}

# 配置系统服务
setup_service() {
    log_info "配置系统服务..."
    systemctl daemon-reload
    systemctl enable realm2
    log_info "realm2服务已设置为开机自启"
}

# 创建示例规则文件
create_example_rule() {
    log_info "创建示例规则文件..."
    cat > /etc/realm2/rules/example-rule.conf << 'EOF'
# realm2 示例规则配置
# 请根据实际需求修改此文件

# 基本配置示例
[general]
log_level = info
log_file = /var/log/realm2/realm2.log

# 规则示例
#[rule1]
#type = tcp
#listen = :8080
#target = backend-server:8080
EOF

    log_info "示例规则文件已创建: /etc/realm2/rules/example-rule.conf"
}

# 显示安装完成信息
show_completion() {
    echo
    log_info "========== 安装完成 =========="
    log_info "realm2 已成功安装到 /etc/realm2/"
    log_info "服务名称: realm2"
    echo
    log_info "下一步操作:"
    log_info "1. 编辑规则文件: /etc/realm2/rules/ 目录下的配置文件"
    log_info "2. 启动服务: systemctl start realm2"
    log_info "3. 检查服务状态: systemctl status realm2"
    log_info "4. 查看日志: journalctl -u realm2 -f"
    echo
    log_info "管理命令:"
    log_info "启动服务: systemctl start realm2"
    log_info "停止服务: systemctl stop realm2"
    log_info "重启服务: systemctl restart realm2"
    log_info "查看状态: systemctl status realm2"
    log_info "查看日志: journalctl -u realm2 -f"
    echo
}

# 主函数
main() {
    log_info "开始安装 realm2..."
    
    # 执行安装步骤
    check_os
    check_root
    check_existing_installation
    install_dependencies
    create_directories
    download_realm2
    create_start_script
    create_systemd_service
    setup_service
    create_example_rule
    show_completion
    
    log_info "安装完成!"
}

# 执行主函数
main "$@"