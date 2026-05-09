#!/bin/bash

# Script cập nhật Channel Promo cho MTProxy
# LƯU Ý: Channel promo hiện được quản lý qua @MTProxybot thông qua proxy tag
# Script này đã không còn được sử dụng, chỉ giữ lại để tham khảo

set -e

# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then
    log_error "Vui lòng chạy script với quyền root (sudo)"
    exit 1
fi

echo ""
log_warning "=========================================="
log_warning "  THÔNG BÁO QUAN TRỌNG"
log_warning "=========================================="
echo ""
log_info "Channel promo hiện được quản lý qua @MTProxybot thông qua proxy tag."
log_info "Script này đã không còn hoạt động."
echo ""
log_info "Để quản lý channel promo:"
log_info "1. Mở Telegram và tìm bot: @MTProxybot"
log_info "2. Sử dụng lệnh /editproxy với proxy tag của bạn"
log_info "3. Làm theo hướng dẫn của bot để cập nhật channel promo"
echo ""
log_warning "Script sẽ thoát ngay bây giờ."
echo ""
exit 0
