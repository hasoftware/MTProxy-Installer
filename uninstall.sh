#!/bin/bash

# MTProxy Uninstaller Script
# Xóa hoàn toàn MTProxy và tất cả các file liên quan

set -e

# Màu sắc cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Biến cấu hình
MT_PROXY_DIR="/opt/mtproxy"
SERVICE_FILE="/etc/systemd/system/mtproxy.service"

# Hàm log
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Hàm xác nhận
confirm_uninstall() {
    echo ""
    log_warning "Bạn có chắc chắn muốn xóa hoàn toàn MTProxy?"
    log_warning "Tất cả dữ liệu và cấu hình sẽ bị mất!"
    echo ""
    read -p "Nhập 'yes' để tiếp tục: " confirm
    
    # Loại bỏ khoảng trắng và chuyển sang lowercase
    confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]' | xargs)
    
    if [ "$confirm" != "yes" ]; then
        log_info "Đã hủy gỡ cài đặt."
        exit 0
    fi
    
    log_info "Đã xác nhận, bắt đầu gỡ cài đặt..."
}

# Hàm dừng và xóa service
remove_service() {
    log_info "Đang dừng và xóa MTProxy service..."
    
    if systemctl is-active --quiet mtproxy 2>/dev/null; then
        systemctl stop mtproxy
        log_success "Đã dừng MTProxy service"
    else
        log_info "MTProxy service không chạy"
    fi
    
    if systemctl is-enabled --quiet mtproxy 2>/dev/null; then
        systemctl disable mtproxy
        log_success "Đã vô hiệu hóa MTProxy service"
    fi
    
    if [ -f "$SERVICE_FILE" ]; then
        rm -f "$SERVICE_FILE"
        log_success "Đã xóa service file: $SERVICE_FILE"
    else
        log_info "Service file không tồn tại"
    fi
    
    systemctl daemon-reload
    log_success "Đã reload systemd"
}

# Hàm xóa thư mục cài đặt
remove_installation_directory() {
    log_info "Đang xóa thư mục cài đặt..."
    
    if [ -d "$MT_PROXY_DIR" ]; then
        rm -rf "$MT_PROXY_DIR"
        log_success "Đã xóa thư mục: $MT_PROXY_DIR"
    else
        log_info "Thư mục cài đặt không tồn tại"
    fi
}

# Hàm xóa các file log
remove_logs() {
    log_info "Đang xóa logs..."
    
    # Xóa journal logs
    if journalctl -u mtproxy --no-pager > /dev/null 2>&1; then
        journalctl --vacuum-time=1s --unit=mtproxy > /dev/null 2>&1 || true
        log_success "Đã xóa journal logs"
    fi
}

# Hàm xóa firewall rules (tùy chọn)
remove_firewall_rules() {
    log_info "Đang kiểm tra firewall rules..."
    
    # Kiểm tra UFW
    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "443/tcp"; then
            log_warning "Phát hiện firewall rule cho port 443"
            log_info "Bạn có muốn xóa firewall rule cho port 443? (y/n)"
            read -p "Lựa chọn: " remove_fw
            if [ "$remove_fw" = "y" ] || [ "$remove_fw" = "Y" ]; then
                ufw delete allow 443/tcp 2>/dev/null || true
                log_success "Đã xóa firewall rule cho port 443"
            fi
        fi
    fi
    
    # Kiểm tra firewalld
    if command -v firewall-cmd &> /dev/null; then
        if firewall-cmd --list-ports 2>/dev/null | grep -q "443/tcp"; then
            log_warning "Phát hiện firewall rule cho port 443 trong firewalld"
            log_info "Bạn có muốn xóa firewall rule cho port 443? (y/n)"
            read -p "Lựa chọn: " remove_fw
            if [ "$remove_fw" = "y" ] || [ "$remove_fw" = "Y" ]; then
                firewall-cmd --permanent --remove-port=443/tcp 2>/dev/null || true
                firewall-cmd --reload 2>/dev/null || true
                log_success "Đã xóa firewall rule cho port 443"
            fi
        fi
    fi
}

# Hàm kiểm tra và xóa các file còn sót lại
check_remaining_files() {
    log_info "Đang kiểm tra các file còn sót lại..."
    
    local found=0
    
    # Kiểm tra các vị trí có thể có file
    if [ -d "/opt/mtproxy" ]; then
        log_warning "Vẫn còn thư mục /opt/mtproxy"
        found=1
    fi
    
    if [ -f "/etc/systemd/system/mtproxy.service" ]; then
        log_warning "Vẫn còn file service /etc/systemd/system/mtproxy.service"
        found=1
    fi
    
    if systemctl list-unit-files | grep -q mtproxy; then
        log_warning "Vẫn còn service trong systemd"
        found=1
    fi
    
    if [ $found -eq 0 ]; then
        log_success "Không còn file nào liên quan đến MTProxy"
    fi
}

# Hàm main
main() {
    echo ""
    log_info "Bắt đầu gỡ cài đặt MTProxy..."
    echo ""
    
    # Kiểm tra quyền root
    if [ "$EUID" -ne 0 ]; then
        log_error "Vui lòng chạy script với quyền root (sudo)"
        exit 1
    fi
    
    # Xác nhận
    confirm_uninstall
    
    # Thực hiện các bước gỡ cài đặt
    remove_service
    remove_installation_directory
    remove_logs
    
    echo ""
    log_info "Bạn có muốn xóa firewall rules? (có thể ảnh hưởng đến các service khác)"
    read -p "Xóa firewall rules? (y/n, mặc định: n): " remove_firewall
    if [ "$remove_firewall" = "y" ] || [ "$remove_firewall" = "Y" ]; then
        remove_firewall_rules
    else
        log_info "Bỏ qua việc xóa firewall rules"
    fi
    
    # Kiểm tra lại
    check_remaining_files
    
    echo ""
    log_success "Đã gỡ cài đặt MTProxy hoàn toàn!"
    echo ""
    log_info "Tất cả các file và service đã được xóa."
    log_info "Bạn có thể chạy lại install_mtproxy.sh để cài đặt lại nếu cần."
    echo ""
}

# Chạy main function
main

