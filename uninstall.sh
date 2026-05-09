#!/bin/bash

# Script gỡ cài đặt MTProxy
# Xóa hoàn toàn MTProxy và tất cả các file liên quan

set -e

# Màu sắc cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Biến cấu hình
MT_PROXY_DIR="/opt/MTProxy"
SERVICE_FILE="/etc/systemd/system/MTProxy.service"
MT_PROXY_USER="mtproxy"

# Logging functions
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

# Hàm xác nhận trước khi gỡ cài đặt
confirm_uninstall() {
    echo ""
    log_warning "Bạn có chắc chắn muốn gỡ bỏ hoàn toàn MTProxy?"
    log_warning "Toàn bộ dữ liệu và cấu hình sẽ bị mất!"
    echo ""
    read -p "Gõ 'yes' để tiếp tục: " confirm

    confirm=$(echo "$confirm" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')

    case "$confirm" in
        yes|y|YES|Y)
            log_info "Đã xác nhận, bắt đầu gỡ cài đặt..."
            ;;
        *)
            log_info "Đã hủy gỡ cài đặt."
            exit 0
            ;;
    esac
}

# Dừng và xóa service
remove_service() {
    log_info "Đang dừng và xóa service MTProxy..."

    if systemctl is-active --quiet MTProxy 2>/dev/null; then
        systemctl stop MTProxy
        log_success "Đã dừng service MTProxy"
    elif systemctl is-active --quiet mtproxy 2>/dev/null; then
        systemctl stop mtproxy
        log_success "Đã dừng service mtproxy (legacy)"
    else
        log_info "Service MTProxy không chạy"
    fi

    if systemctl is-enabled --quiet MTProxy 2>/dev/null; then
        systemctl disable MTProxy
        log_success "Đã tắt service MTProxy"
    elif systemctl is-enabled --quiet mtproxy 2>/dev/null; then
        systemctl disable mtproxy
        log_success "Đã tắt service mtproxy (legacy)"
    fi

    if [ -f "$SERVICE_FILE" ]; then
        rm -f "$SERVICE_FILE"
        log_success "Đã xóa file service: $SERVICE_FILE"
    fi

    if [ -f "/etc/systemd/system/mtproxy.service" ]; then
        rm -f "/etc/systemd/system/mtproxy.service"
        log_success "Đã xóa file service cũ"
    fi

    systemctl daemon-reload
    log_success "Đã reload systemd"
}

# Xóa thư mục cài đặt
remove_installation_directory() {
    log_info "Đang xóa thư mục cài đặt..."

    if [ -d "$MT_PROXY_DIR" ]; then
        rm -rf "$MT_PROXY_DIR"
        log_success "Đã xóa thư mục: $MT_PROXY_DIR"
    else
        log_info "Thư mục cài đặt không tồn tại"
    fi

    if [ -d "/opt/mtproxy" ]; then
        rm -rf "/opt/mtproxy"
        log_success "Đã xóa thư mục cũ: /opt/mtproxy"
    fi
}

# Xóa user mtproxy
remove_user() {
    log_info "Đang xóa user mtproxy..."

    if id "$MT_PROXY_USER" &>/dev/null; then
        userdel -r "$MT_PROXY_USER" 2>/dev/null || userdel "$MT_PROXY_USER" 2>/dev/null || true
        log_success "Đã xóa user: $MT_PROXY_USER"
    else
        log_info "User $MT_PROXY_USER không tồn tại"
    fi
}

# Xóa các file log
remove_logs() {
    log_info "Đang xóa logs..."

    if journalctl -u MTProxy --no-pager > /dev/null 2>&1; then
        journalctl --vacuum-time=1s --unit=MTProxy > /dev/null 2>&1 || true
        log_success "Đã xóa journal logs"
    fi

    if journalctl -u mtproxy --no-pager > /dev/null 2>&1; then
        journalctl --vacuum-time=1s --unit=mtproxy > /dev/null 2>&1 || true
        log_success "Đã xóa journal logs cũ"
    fi
}

# Xóa các rule firewall (tùy chọn)
remove_firewall_rules() {
    log_info "Đang kiểm tra các rule firewall..."

    local ports="8443 8888 443"

    for port in $ports; do
        if command -v ufw &> /dev/null; then
            if ufw status | grep -q "${port}/tcp"; then
                log_warning "Tìm thấy rule firewall cho port ${port}"
                log_info "Bạn có muốn xóa rule firewall cho port ${port}? (y/n)"
                read -p "Lựa chọn: " remove_fw
                if [ "$remove_fw" = "y" ] || [ "$remove_fw" = "Y" ]; then
                    ufw delete allow ${port}/tcp 2>/dev/null || true
                    log_success "Đã xóa rule firewall cho port ${port}"
                fi
            fi
        fi

        if command -v firewall-cmd &> /dev/null; then
            if firewall-cmd --list-ports 2>/dev/null | grep -q "${port}/tcp"; then
                log_warning "Tìm thấy rule firewall cho port ${port} trong firewalld"
                log_info "Bạn có muốn xóa rule firewall cho port ${port}? (y/n)"
                read -p "Lựa chọn: " remove_fw
                if [ "$remove_fw" = "y" ] || [ "$remove_fw" = "Y" ]; then
                    firewall-cmd --permanent --remove-port=${port}/tcp 2>/dev/null || true
                    firewall-cmd --reload 2>/dev/null || true
                    log_success "Đã xóa rule firewall cho port ${port}"
                fi
            fi
        fi
    done
}

# Kiểm tra và xóa các file còn sót
check_remaining_files() {
    log_info "Đang kiểm tra các file còn sót..."

    local found=0

    if [ -d "/opt/MTProxy" ]; then
        log_warning "Vẫn còn thư mục /opt/MTProxy"
        found=1
    fi

    if [ -d "/opt/mtproxy" ]; then
        log_warning "Vẫn còn thư mục cũ /opt/mtproxy"
        found=1
    fi

    if [ -f "/etc/systemd/system/MTProxy.service" ]; then
        log_warning "Vẫn còn file service /etc/systemd/system/MTProxy.service"
        found=1
    fi

    if [ -f "/etc/systemd/system/mtproxy.service" ]; then
        log_warning "Vẫn còn file service cũ /etc/systemd/system/mtproxy.service"
        found=1
    fi

    if systemctl list-unit-files | grep -qiE "MTProxy|mtproxy"; then
        log_warning "Vẫn còn service trong systemd"
        found=1
    fi

    if id "$MT_PROXY_USER" &>/dev/null; then
        log_warning "Vẫn còn user: $MT_PROXY_USER"
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

    if [ "$EUID" -ne 0 ]; then
        log_error "Vui lòng chạy script với quyền root (sudo)"
        exit 1
    fi

    confirm_uninstall

    remove_service
    remove_installation_directory
    remove_user
    remove_logs

    echo ""
    log_info "Bạn có muốn xóa các rule firewall? (có thể ảnh hưởng đến service khác)"
    read -p "Xóa rule firewall? (y/n, mặc định: n): " remove_firewall
    if [ "$remove_firewall" = "y" ] || [ "$remove_firewall" = "Y" ]; then
        remove_firewall_rules
    else
        log_info "Bỏ qua việc xóa rule firewall"
    fi

    check_remaining_files

    echo ""
    log_success "MTProxy đã được gỡ bỏ hoàn toàn!"
    echo ""
    log_info "Tất cả các file và service đã được xóa."
    log_info "Bạn có thể chạy lại install_mtproxy.sh để cài đặt lại nếu cần."
    echo ""
}

# Chạy main function
main
