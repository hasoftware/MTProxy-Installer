#!/bin/bash

# MTProxy Auto Installer Script
# Tự động cài đặt MTProxy cho VPS Linux

set -e

# Màu sắc cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Biến cấu hình
MT_PROXY_DIR="/opt/mtproxy"
MT_PROXY_BIN="$MT_PROXY_DIR/mtproto-proxy"
MT_PROXY_CONFIG="$MT_PROXY_DIR/config.conf"
MT_PROXY_SECRET="$MT_PROXY_DIR/secret"
SERVICE_FILE="/etc/systemd/system/mtproxy.service"
PROMO_CHANNEL=""
PROXY_PORT=443
WORKERS=""  # Để trống = không giới hạn workers

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

# Hàm phát hiện hệ điều hành
detect_os() {
    log_info "Đang phát hiện hệ điều hành..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        log_success "Phát hiện hệ điều hành: $OS $OS_VERSION"
    elif [ -f /etc/redhat-release ]; then
        OS="rhel"
        log_success "Phát hiện hệ điều hành: RHEL/CentOS"
    elif [ -f /etc/debian_version ]; then
        OS="debian"
        log_success "Phát hiện hệ điều hành: Debian"
    else
        log_error "Không thể phát hiện hệ điều hành!"
        exit 1
    fi
    
    # Xác định loại package manager
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
    else
        log_error "Không tìm thấy package manager phù hợp!"
        exit 1
    fi
    
    log_success "Package manager: $PKG_MANAGER"
}

# Hàm kiểm tra port đã được sử dụng
check_port() {
    if command -v netstat &> /dev/null; then
        if netstat -tuln | grep -q ":$PROXY_PORT "; then
            log_warning "Port $PROXY_PORT đã được sử dụng!"
            return 1
        fi
    elif command -v ss &> /dev/null; then
        if ss -tuln | grep -q ":$PROXY_PORT "; then
            log_warning "Port $PROXY_PORT đã được sử dụng!"
            return 1
        fi
    fi
    return 0
}

# Hàm cài đặt dependencies
install_dependencies() {
    log_info "Đang cài đặt dependencies..."
    
    if [ "$PKG_MANAGER" = "apt" ]; then
        apt-get update -qq
        apt-get install -y -qq git curl build-essential libssl-dev zlib1g-dev net-tools
    elif [ "$PKG_MANAGER" = "yum" ]; then
        yum install -y -q git curl gcc gcc-c++ make openssl-devel zlib-devel net-tools
    elif [ "$PKG_MANAGER" = "dnf" ]; then
        dnf install -y -q git curl gcc gcc-c++ make openssl-devel zlib-devel net-tools
    fi
    
    log_success "Đã cài đặt dependencies thành công"
}

# Hàm tải và compile MTProxy
install_mtproxy() {
    log_info "Đang tải và compile MTProxy..."
    
    # Tạo thư mục
    mkdir -p $MT_PROXY_DIR
    cd $MT_PROXY_DIR
    
    # Clone repository
    if [ ! -d "MTProxy" ]; then
        log_info "Đang clone MTProxy repository..."
        git clone https://github.com/TelegramMessenger/MTProxy.git
    else
        log_info "Repository đã tồn tại, đang cập nhật..."
        cd MTProxy
        git pull
        cd ..
    fi
    
    cd MTProxy
    
    # Compile
    log_info "Đang compile MTProxy (có thể mất vài phút)..."
    if ! make -j$(nproc); then
        log_error "Compile thất bại!"
        exit 1
    fi
    
    # Copy binary
    cp objs/bin/mtproto-proxy $MT_PROXY_BIN
    chmod +x $MT_PROXY_BIN
    
    log_success "Đã compile MTProxy thành công"
}

# Hàm tạo secret
generate_secret() {
    log_info "Đang tạo secret..."
    
    if [ ! -f "$MT_PROXY_SECRET" ]; then
        $MT_PROXY_BIN -g > $MT_PROXY_SECRET
        log_success "Đã tạo secret mới"
    else
        log_info "Sử dụng secret hiện có"
    fi
    
    SECRET=$(cat $MT_PROXY_SECRET | head -n 1)
    log_info "Secret: $SECRET"
}

# Hàm chuyển đổi secret từ base64 sang hex
convert_secret_to_hex() {
    local base64_secret=$1
    local decoded_bytes
    
    # Decode base64
    decoded_bytes=$(echo -n "$base64_secret" | base64 -d 2>/dev/null)
    
    if [ -z "$decoded_bytes" ]; then
        log_warning "Không thể decode secret sang hex"
        echo ""
        return
    fi
    
    # Convert sang hex - thử các phương pháp khác nhau
    if command -v xxd &> /dev/null; then
        echo -n "$decoded_bytes" | xxd -p -c 256 | tr -d '\n'
    elif command -v od &> /dev/null; then
        echo -n "$decoded_bytes" | od -A n -t x1 | tr -d ' \n'
    elif command -v hexdump &> /dev/null; then
        echo -n "$decoded_bytes" | hexdump -ve '1/1 "%.2x"'
    else
        # Fallback: sử dụng printf với từng byte
        local result=""
        local len=${#decoded_bytes}
        for ((i=0; i<len; i++)); do
            printf -v result "%s%02x" "$result" "'${decoded_bytes:i:1}"
        done
        echo -n "$result"
    fi
}

# Hàm lấy IP public
get_public_ip() {
    PUBLIC_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || curl -s icanhazip.com)
    if [ -z "$PUBLIC_IP" ]; then
        log_error "Không thể lấy IP public!"
        exit 1
    fi
    log_info "IP Public: $PUBLIC_IP"
}

# Hàm tạo cấu hình
create_config() {
    log_info "Đang tạo cấu hình..."
    
    SECRET=$(cat $MT_PROXY_SECRET | head -n 1)
    
    # Tạo config file
    cat > $MT_PROXY_CONFIG << EOF
# MTProxy Configuration
# Port: $PROXY_PORT
EOF

    # Thêm workers nếu được cấu hình (nếu để trống = không giới hạn)
    if [ ! -z "$WORKERS" ]; then
        echo "workers=$WORKERS" >> $MT_PROXY_CONFIG
        log_info "Workers được cấu hình: $WORKERS"
    else
        log_info "Workers: không giới hạn"
    fi
    
    # Thêm secret và port
    cat >> $MT_PROXY_CONFIG << EOF
secret=$SECRET
port=$PROXY_PORT
EOF

    # Thêm promo channel nếu có
    if [ ! -z "$PROMO_CHANNEL" ]; then
        echo "promo=$PROMO_CHANNEL" >> $MT_PROXY_CONFIG
        log_success "Đã thêm Channel Promo: $PROMO_CHANNEL"
    fi
    
    log_success "Đã tạo cấu hình"
}

# Hàm tạo systemd service
create_service() {
    log_info "Đang tạo systemd service..."
    
    cat > $SERVICE_FILE << EOF
[Unit]
Description=MTProxy
After=network.target

[Service]
Type=simple
WorkingDirectory=$MT_PROXY_DIR
ExecStart=$MT_PROXY_BIN -c $MT_PROXY_CONFIG
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable mtproxy
    log_success "Đã tạo systemd service"
}

# Hàm khởi động service
start_service() {
    log_info "Đang khởi động MTProxy service..."
    
    systemctl restart mtproxy
    
    # Kiểm tra trạng thái
    sleep 2
    if systemctl is-active --quiet mtproxy; then
        log_success "MTProxy đã khởi động thành công"
    else
        log_error "MTProxy khởi động thất bại!"
        systemctl status mtproxy
        exit 1
    fi
}

# Hàm xuất thông tin proxy
export_proxy_info() {
    log_info "Đang tạo thông tin proxy..."
    
    SECRET=$(cat $MT_PROXY_SECRET | head -n 1)
    get_public_ip
    
    # Chuyển đổi secret sang hex format để gửi cho bot
    SECRET_HEX=$(convert_secret_to_hex "$SECRET")
    
    # Tạo proxy link
    PROXY_LINK="tg://proxy?server=$PUBLIC_IP&port=$PROXY_PORT&secret=$SECRET"
    
    echo ""
    echo "=========================================="
    echo "  MTProxy đã được cài đặt thành công!"
    echo "=========================================="
    echo ""
    echo "Thông tin Proxy:"
    echo "  IP: $PUBLIC_IP"
    echo "  Port: $PROXY_PORT"
    echo "  Secret (Base64): $SECRET"
    echo ""
    echo "Link Proxy (Telegram):"
    echo "  $PROXY_LINK"
    echo ""
    echo "Hoặc sử dụng format này trong Telegram:"
    echo "  Server: $PUBLIC_IP"
    echo "  Port: $PROXY_PORT"
    echo "  Secret: $SECRET"
    echo ""
    
    # Hiển thị hướng dẫn đăng ký với MTProxy Bot nếu có Channel Promo
    if [ ! -z "$PROMO_CHANNEL" ]; then
        echo "=========================================="
        echo "  ĐĂNG KÝ CHANNEL PROMO VỚI BOT"
        echo "=========================================="
        echo ""
        echo "Để kích hoạt Channel Promo, làm theo các bước sau:"
        echo ""
        echo "1. Mở Telegram và tìm bot: @MTProxybot"
        echo "2. Gửi lệnh: /newproxy"
        echo "3. Bot sẽ hỏi IP và Port, gửi: $PUBLIC_IP:$PROXY_PORT"
        echo "4. Khi bot hỏi secret ở định dạng hex, gửi đoạn này:"
        echo ""
        echo -e "${GREEN}$SECRET_HEX${NC}"
        echo ""
        echo "5. Bot sẽ hỏi channel để quảng cáo, gửi: $PROMO_CHANNEL"
        echo ""
        echo "Lưu ý: Secret ở định dạng hex đã được tạo tự động ở trên."
        echo ""
    else
        echo "=========================================="
        echo "  LƯU Ý: SECRET Ở ĐỊNH DẠNG HEX"
        echo "=========================================="
        echo ""
        echo "Nếu bạn muốn đăng ký Channel Promo với @MTProxybot sau này,"
        echo "bạn sẽ cần secret ở định dạng hex:"
        echo ""
        echo -e "${GREEN}$SECRET_HEX${NC}"
        echo ""
    fi
    
    # Lưu vào file
    cat > $MT_PROXY_DIR/proxy_info.txt << EOF
MTProxy Information
===================
IP: $PUBLIC_IP
Port: $PROXY_PORT
Secret (Base64): $SECRET
Secret (Hex): $SECRET_HEX
Proxy Link: $PROXY_LINK

Generated at: $(date)
EOF

    if [ ! -z "$PROMO_CHANNEL" ]; then
        cat >> $MT_PROXY_DIR/proxy_info.txt << EOF

Channel Promo: $PROMO_CHANNEL
Để đăng ký với @MTProxybot:
1. Gửi /newproxy
2. Gửi IP:Port = $PUBLIC_IP:$PROXY_PORT
3. Gửi secret (hex): $SECRET_HEX
4. Gửi channel: $PROMO_CHANNEL
EOF
    fi

    log_success "Thông tin đã được lưu vào: $MT_PROXY_DIR/proxy_info.txt"
}

# Hàm cấu hình firewall
configure_firewall() {
    log_info "Đang cấu hình firewall..."
    
    # Kiểm tra và cấu hình ufw (Ubuntu/Debian)
    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            log_info "Đang mở port $PROXY_PORT trong UFW..."
            ufw allow $PROXY_PORT/tcp
            log_success "Đã mở port $PROXY_PORT trong UFW"
        fi
    # Kiểm tra và cấu hình firewalld (CentOS/RHEL/Fedora)
    elif command -v firewall-cmd &> /dev/null; then
        if systemctl is-active --quiet firewalld; then
            log_info "Đang mở port $PROXY_PORT trong firewalld..."
            firewall-cmd --permanent --add-port=$PROXY_PORT/tcp
            firewall-cmd --reload
            log_success "Đã mở port $PROXY_PORT trong firewalld"
        fi
    # Kiểm tra iptables
    elif command -v iptables &> /dev/null; then
        log_info "Đang mở port $PROXY_PORT trong iptables..."
        iptables -I INPUT -p tcp --dport $PROXY_PORT -j ACCEPT
        # Lưu rules (tùy thuộc vào distro)
        if command -v iptables-save &> /dev/null; then
            if [ -d /etc/iptables ]; then
                iptables-save > /etc/iptables/rules.v4
            elif [ -f /etc/sysconfig/iptables ]; then
                iptables-save > /etc/sysconfig/iptables
            fi
        fi
        log_success "Đã mở port $PROXY_PORT trong iptables"
    else
        log_warning "Không tìm thấy firewall manager, vui lòng mở port $PROXY_PORT thủ công"
    fi
}

# Hàm đọc cấu hình từ chính script
load_config() {
    log_info "Đang đọc cấu hình từ script..."
    
    # Đọc phần config từ cuối script (sau dòng #=== CONFIG SECTION ===)
    SCRIPT_PATH="${BASH_SOURCE[0]}"
    
    # Nếu script được gọi bằng đường dẫn tương đối, chuyển thành đường dẫn tuyệt đối
    if [[ ! "$SCRIPT_PATH" =~ ^/ ]]; then
        SCRIPT_PATH="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)/$(basename "$SCRIPT_PATH")"
    fi
    
    # Tìm và đọc phần config
    if grep -q "#=== CONFIG SECTION ===" "$SCRIPT_PATH"; then
        # Tạo file temp để source - chỉ lấy các dòng biến (bắt đầu bằng chữ cái và có dấu =)
        TEMP_CONFIG=$(mktemp)
        
        # Lấy phần sau #=== CONFIG SECTION === và chỉ lấy các dòng biến hợp lệ
        awk '/#=== CONFIG SECTION ===/{flag=1; next} flag' "$SCRIPT_PATH" | \
        grep -E '^[A-Z_]+=' > "$TEMP_CONFIG"
        
        # Source config nếu file không rỗng
        if [ -s "$TEMP_CONFIG" ]; then
            source "$TEMP_CONFIG"
        fi
        rm -f "$TEMP_CONFIG"
        
        if [ ! -z "$PROMO_CHANNEL" ]; then
            log_success "Đã tải Channel Promo: $PROMO_CHANNEL"
        fi
        if [ ! -z "$PROXY_PORT" ]; then
            log_info "Port được cấu hình: $PROXY_PORT"
        fi
        if [ ! -z "$WORKERS" ]; then
            log_info "Workers được cấu hình: $WORKERS"
        else
            log_info "Workers: không giới hạn (mặc định)"
        fi
    else
        log_info "Sử dụng cấu hình mặc định"
    fi
}

# Hàm main
main() {
    echo ""
    log_info "Bắt đầu cài đặt MTProxy..."
    echo ""
    
    # Kiểm tra quyền root
    if [ "$EUID" -ne 0 ]; then
        log_error "Vui lòng chạy script với quyền root (sudo)"
        exit 1
    fi
    
    # Đọc cấu hình
    load_config
    
    # Kiểm tra port
    if ! check_port; then
        log_error "Vui lòng chọn port khác hoặc dừng service đang sử dụng port $PROXY_PORT"
        exit 1
    fi
    
    # Thực hiện các bước cài đặt
    detect_os
    install_dependencies
    install_mtproxy
    generate_secret
    create_config
    configure_firewall
    create_service
    start_service
    export_proxy_info
    
    echo ""
    log_success "Hoàn tất cài đặt!"
    echo ""
}

# Chạy main function
main

#=== CONFIG SECTION ===
# Phần cấu hình này nằm ở cuối script để dễ chỉnh sửa
# 
# HƯỚNG DẪN:
# 1. Để sử dụng Channel Promo, thay đổi PROMO_CHANNEL thành username channel của bạn
# 2. Ví dụ: PROMO_CHANNEL="@your_channel" hoặc PROMO_CHANNEL="https://t.me/your_channel"
# 3. Để trống nếu không muốn sử dụng Channel Promo

# Channel Promo
# Ví dụ: "@my_channel" hoặc "https://t.me/my_channel"
# Để trống nếu không muốn sử dụng Channel Promo
PROMO_CHANNEL="@hasoftware"

# Port cho MTProxy (mặc định: 443)
# Đảm bảo port này chưa được sử dụng bởi service khác
PROXY_PORT=443

# Số lượng workers (mặc định: không giới hạn)
# Để trống = không giới hạn workers (khuyến nghị)
# Hoặc đặt số cụ thể, ví dụ: WORKERS=4
WORKERS=""

