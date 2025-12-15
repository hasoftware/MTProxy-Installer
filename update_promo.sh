#!/bin/bash

# Script cập nhật Channel Promo cho MTProxy đã cài đặt

set -e

# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MT_PROXY_DIR="/opt/mtproxy"
MT_PROXY_CONFIG="$MT_PROXY_DIR/config.conf"
SERVICE_FILE="/etc/systemd/system/mtproxy.service"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then
    log_error "Vui lòng chạy script với quyền root (sudo)"
    exit 1
fi

# Kiểm tra MTProxy đã được cài đặt
if [ ! -f "$MT_PROXY_CONFIG" ]; then
    log_error "MTProxy chưa được cài đặt!"
    log_info "Vui lòng chạy install_mtproxy.sh trước"
    exit 1
fi

# Nhận Channel Promo từ tham số hoặc hỏi người dùng
if [ -z "$1" ]; then
    echo ""
    log_info "Nhập Channel Promo (ví dụ: @your_channel hoặc https://t.me/your_channel)"
    log_info "Để trống nếu muốn xóa Channel Promo hiện tại"
    read -p "Channel Promo: " PROMO_CHANNEL
else
    PROMO_CHANNEL="$1"
fi

# Đọc config hiện tại
log_info "Đang cập nhật cấu hình..."

# Tạo config mới
TEMP_CONFIG=$(mktemp)
while IFS= read -r line; do
    if [[ $line =~ ^promo= ]]; then
        # Bỏ qua dòng promo cũ
        continue
    fi
    echo "$line" >> "$TEMP_CONFIG"
done < "$MT_PROXY_CONFIG"

# Thêm promo mới nếu có
if [ ! -z "$PROMO_CHANNEL" ]; then
    echo "promo=$PROMO_CHANNEL" >> "$TEMP_CONFIG"
    log_success "Đã thêm Channel Promo: $PROMO_CHANNEL"
else
    log_info "Đã xóa Channel Promo"
fi

# Thay thế config cũ
mv "$TEMP_CONFIG" "$MT_PROXY_CONFIG"

# Khởi động lại service
log_info "Đang khởi động lại MTProxy..."
systemctl restart mtproxy

sleep 2
if systemctl is-active --quiet mtproxy; then
    log_success "MTProxy đã được cập nhật và khởi động lại thành công!"
else
    log_error "MTProxy khởi động thất bại!"
    systemctl status mtproxy
    exit 1
fi

echo ""
log_success "Hoàn tất!"

