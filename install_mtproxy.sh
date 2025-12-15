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
MT_PROXY_DIR="/opt/MTProxy"
MT_PROXY_BIN="$MT_PROXY_DIR/mtproto-proxy"
MT_PROXY_CONFIG="$MT_PROXY_DIR/proxy-multi.conf"
MT_PROXY_SECRET_FILE="$MT_PROXY_DIR/secret"
MT_PROXY_AES_PWD="$MT_PROXY_DIR/proxy-secret"
SERVICE_FILE="/etc/systemd/system/MTProxy.service"
MT_PROXY_USER="mtproxy"
PROMO_CHANNEL=""
PROXY_PORT=8443  # Port mặc định theo hướng dẫn
STATS_PORT=8888  # Port cho HTTP stats
WORKERS="1"

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
    
    # Tạo thư mục làm việc tạm
    WORK_DIR="/tmp/mtproxy_build"
    mkdir -p $WORK_DIR
    cd $WORK_DIR
    
    # Clone repository từ TelegramMessenger (hỗ trợ JSON config)
    if [ ! -d "MTProxy" ]; then
        log_info "Đang clone MTProxy repository từ TelegramMessenger..."
        git clone https://github.com/TelegramMessenger/MTProxy.git
    else
        log_info "Repository đã tồn tại, đang cập nhật..."
        cd MTProxy
        git pull
        cd ..
    fi
    
    cd MTProxy
    
    # Sửa Makefile để thêm -fcommon flag (theo hướng dẫn)
    log_info "Đang sửa Makefile..."
    if ! grep -q "-fcommon" Makefile; then
        sed -i 's/COMMON_CFLAGS =/COMMON_CFLAGS = -fcommon/' Makefile
        sed -i 's/COMMON_LDFLAGS =/COMMON_LDFLAGS = -fcommon/' Makefile
        log_success "Đã thêm -fcommon flag vào Makefile"
    fi
    
    # Compile
    log_info "Đang compile MTProxy (có thể mất vài phút)..."
    if ! make -j$(nproc); then
        log_error "Compile thất bại!"
        exit 1
    fi
    
    # Tạo thư mục cài đặt
    mkdir -p $MT_PROXY_DIR
    
    # Copy binary
    cp objs/bin/mtproto-proxy $MT_PROXY_BIN
    chmod +x $MT_PROXY_BIN
    
    log_success "Đã compile MTProxy thành công"
}

# Hàm download proxy-secret và proxy-multi.conf từ Telegram
download_telegram_files() {
    log_info "Đang tải các file cấu hình từ Telegram..."
    
    # Download proxy-secret
    if [ ! -f "$MT_PROXY_AES_PWD" ]; then
        curl -s https://core.telegram.org/getProxySecret -o "$MT_PROXY_AES_PWD"
        if [ $? -eq 0 ] && [ -s "$MT_PROXY_AES_PWD" ]; then
            log_success "Đã tải proxy-secret từ Telegram"
        else
            log_error "Không thể tải proxy-secret!"
            exit 1
        fi
    else
        log_info "proxy-secret đã tồn tại"
    fi
    
    # Download proxy-multi.conf
    if [ ! -f "$MT_PROXY_CONFIG" ]; then
        curl -s https://core.telegram.org/getProxyConfig -o "$MT_PROXY_CONFIG"
        if [ $? -eq 0 ] && [ -s "$MT_PROXY_CONFIG" ]; then
            log_success "Đã tải proxy-multi.conf từ Telegram"
        else
            log_error "Không thể tải proxy-multi.conf!"
            exit 1
        fi
    else
        log_info "proxy-multi.conf đã tồn tại"
    fi
}

# Hàm tạo secret (hex format theo hướng dẫn)
generate_secret() {
    log_info "Đang tạo secret..."
    
    if [ ! -f "$MT_PROXY_SECRET_FILE" ]; then
        # Tạo secret: 16 bytes random, convert sang hex (theo hướng dẫn)
        # Format: head -c 16 /dev/urandom | xxd -ps
        if command -v xxd &> /dev/null; then
            SECRET_HEX=$(head -c 16 /dev/urandom | xxd -ps)
            echo "$SECRET_HEX" > $MT_PROXY_SECRET_FILE
            log_success "Đã tạo secret mới (hex format)"
        elif command -v openssl &> /dev/null; then
            SECRET_HEX=$(openssl rand -hex 16)
            echo "$SECRET_HEX" > $MT_PROXY_SECRET_FILE
            log_success "Đã tạo secret mới (hex format)"
        else
            log_error "Cần xxd hoặc openssl để tạo secret!"
            exit 1
        fi
    else
        log_info "Sử dụng secret hiện có"
    fi
    
    SECRET_HEX=$(cat $MT_PROXY_SECRET_FILE | head -n 1 | tr -d '\n\r ')
    log_info "Secret (hex): $SECRET_HEX"
}

# Hàm tạo user mtproxy
create_mtproxy_user() {
    log_info "Đang tạo user mtproxy..."
    
    if ! id "$MT_PROXY_USER" &>/dev/null; then
        useradd -m -s /bin/false $MT_PROXY_USER
        log_success "Đã tạo user $MT_PROXY_USER"
    else
        log_info "User $MT_PROXY_USER đã tồn tại"
    fi
    
    # Cấp quyền sở hữu thư mục cho user mtproxy
    chown -R $MT_PROXY_USER:$MT_PROXY_USER $MT_PROXY_DIR
    log_success "Đã cấp quyền sở hữu cho user $MT_PROXY_USER"
}

# Hàm chuyển đổi secret từ hex sang base64 (để dùng trong proxy link)
convert_hex_to_base64() {
    local hex_secret=$1
    
    # Convert hex sang base64
    if command -v xxd &> /dev/null; then
        echo -n "$hex_secret" | xxd -r -p | base64 -w 0 2>/dev/null || \
        echo -n "$hex_secret" | xxd -r -p | base64 | tr -d '\n'
    elif command -v od &> /dev/null; then
        # Convert hex string sang bytes rồi base64
        echo -n "$hex_secret" | sed 's/\(..\)/\\x\1/g' | xargs -0 printf | base64 -w 0 2>/dev/null || \
        echo -n "$hex_secret" | sed 's/\(..\)/\\x\1/g' | xargs -0 printf | base64 | tr -d '\n'
    else
        log_warning "Không thể convert hex sang base64"
        echo ""
    fi
}

# Hàm lấy IP public và private
get_ips() {
    PUBLIC_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || curl -s icanhazip.com)
    if [ -z "$PUBLIC_IP" ]; then
        log_error "Không thể lấy IP public!"
        exit 1
    fi
    
    # Lấy private IP (thử nhiều cách)
    PRIVATE_IP=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}' || \
                 hostname -I | awk '{print $1}' || \
                 ip addr show | grep -E 'inet.*eth0|inet.*ens' | awk '{print $2}' | cut -d/ -f1 | head -1)
    
    if [ -z "$PRIVATE_IP" ]; then
        log_warning "Không thể lấy private IP, sẽ sử dụng public IP cho cả hai"
        PRIVATE_IP="$PUBLIC_IP"
    fi
    
    log_info "IP Public: $PUBLIC_IP"
    log_info "IP Private: $PRIVATE_IP"
}

# Hàm tạo cấu hình (JSON format như script của bạn)
create_config() {
    log_info "Đang tạo cấu hình..."
    
    SECRET_HEX=$(cat $MT_PROXY_SECRET_FILE | head -n 1 | tr -d '\n\r ')
    
    # Kiểm tra secret có hợp lệ không
    if [ -z "$SECRET_HEX" ]; then
        log_error "Secret không hợp lệ!"
        exit 1
    fi
    
    # Xóa config file cũ nếu có
    if [ -f "$MT_PROXY_CONFIG" ]; then
        rm -f "$MT_PROXY_CONFIG"
    fi
    
    # Tạo JSON config file (giống script của bạn)
    cat > "$MT_PROXY_CONFIG" << EOF
{
    "tag": "proxy1",
    "port": $PROXY_PORT,
    "secret": "$SECRET_HEX"$(if [ ! -z "$PROMO_CHANNEL" ]; then echo ",
    \"sponsored_channel\": {
        \"channel_username\": \"$PROMO_CHANNEL\"
    }"; fi)
}
EOF
    
    log_success "Đã tạo cấu hình JSON"
    log_info "Nội dung config (đã ẩn secret):"
    sed 's/"secret": "[^"]*"/"secret": "***"/' "$MT_PROXY_CONFIG" | while IFS= read -r line; do
        log_info "  $line"
    done
}

# Hàm cập nhật proxy-multi.conf với secret và channel promo (native mtproto-proxy format)
update_proxy_config() {
    log_info "Đang cập nhật proxy-multi.conf với secret và channel promo..."
    
    SECRET_HEX=$(cat $MT_PROXY_SECRET_FILE | head -n 1 | tr -d '\n\r ')
    
    # Kiểm tra secret có hợp lệ không
    if [ -z "$SECRET_HEX" ]; then
        log_error "Secret không hợp lệ!"
        exit 1
    fi
    
    # Tạo file config mới với format native mtproto-proxy (không phải JSON)
    # Format: proxy 0.0.0.0:<PORT> { secret = "hex:<SECRET>"; advertise_channel = "<CHANNEL>"; }
    if [ ! -z "$PROMO_CHANNEL" ]; then
        # Có channel promo - loại bỏ @ nếu có và đảm bảo format <channel>
        CHANNEL_NAME=$(echo "$PROMO_CHANNEL" | sed 's/^@//')
        cat > "$MT_PROXY_CONFIG" << EOF
proxy 0.0.0.0:$PROXY_PORT {
    secret = "hex:$SECRET_HEX";
    advertise_channel = "<$CHANNEL_NAME>";
}
EOF
    else
        # Không có channel promo
        cat > "$MT_PROXY_CONFIG" << EOF
proxy 0.0.0.0:$PROXY_PORT {
    secret = "hex:$SECRET_HEX";
}
EOF
    fi
    
    # Đảm bảo quyền sở hữu và permissions đúng
    chown $MT_PROXY_USER:$MT_PROXY_USER "$MT_PROXY_CONFIG"
    chmod 600 "$MT_PROXY_CONFIG"
    
    log_success "Đã cập nhật proxy-multi.conf"
    log_info "Nội dung config (đã ẩn secret):"
    sed 's/secret = "hex:[^"]*"/secret = "hex:***"/' "$MT_PROXY_CONFIG" | while IFS= read -r line; do
        log_info "  $line"
    done
    
    # Validate config file
    log_info "Đang kiểm tra tính hợp lệ của config file..."
    if $MT_PROXY_BIN -c "$MT_PROXY_CONFIG" > /dev/null 2>&1; then
        log_success "Config file hợp lệ"
    else
        log_error "Config file không hợp lệ! Kiểm tra lại cú pháp."
        log_info "Chi tiết lỗi:"
        $MT_PROXY_BIN -c "$MT_PROXY_CONFIG" 2>&1 || true
        exit 1
    fi
}

# Hàm tạo systemd service
create_service() {
    log_info "Đang tạo systemd service..."
    
    # Dừng service cũ nếu có
    if systemctl is-active --quiet mtproxy 2>/dev/null; then
        systemctl stop mtproxy
    fi
    
    # Xóa service file cũ nếu có
    if [ -f "$SERVICE_FILE" ]; then
        rm -f "$SERVICE_FILE"
        systemctl daemon-reload
    fi
    
    # Lấy IPs cho nat-info
    get_ips
    
    # Lấy secret
    SECRET_HEX=$(cat $MT_PROXY_SECRET_FILE | head -n 1 | tr -d '\n\r ')
    
    # Xây dựng command theo script của bạn (TelegramMessenger/MTProxy với JSON config)
    # Format: mtproto-proxy -H <proxy-port> --aes-pwd <password-file> <config-file> -M <workers>
    # Note: Secret được đặt trong JSON config, không dùng -S flag
    # TelegramMessenger/MTProxy đơn giản hơn, không cần -u, -p, --http-stats, --nat-info
    if [ ! -z "$WORKERS" ]; then
        EXEC_START="$MT_PROXY_BIN -H $PROXY_PORT --aes-pwd $MT_PROXY_AES_PWD $MT_PROXY_CONFIG -M $WORKERS"
    else
        EXEC_START="$MT_PROXY_BIN -H $PROXY_PORT --aes-pwd $MT_PROXY_AES_PWD $MT_PROXY_CONFIG -M 1"
    fi
    
    cat > $SERVICE_FILE << EOF
[Unit]
Description=MTProxy
After=network.target

[Service]
Type=simple
WorkingDirectory=$MT_PROXY_DIR
ExecStart=$EXEC_START
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable MTProxy
    log_success "Đã tạo systemd service"
    log_info "Command: $EXEC_START"
}

# Hàm khởi động service
start_service() {
    log_info "Đang khởi động MTProxy service..."
    
    # Kiểm tra config file trước khi khởi động
    if [ ! -f "$MT_PROXY_CONFIG" ]; then
        log_error "File config không tồn tại: $MT_PROXY_CONFIG"
        exit 1
    fi
    
    # Kiểm tra binary có tồn tại không
    if [ ! -f "$MT_PROXY_BIN" ]; then
        log_error "Binary không tồn tại: $MT_PROXY_BIN"
        exit 1
    fi
    
    # Kiểm tra config file có hợp lệ không (đọc được và không rỗng)
    if [ ! -s "$MT_PROXY_CONFIG" ]; then
        log_error "Config file rỗng hoặc không hợp lệ!"
        exit 1
    fi
    
    # Kiểm tra các file cần thiết
    if [ ! -f "$MT_PROXY_CONFIG" ]; then
        log_error "File proxy-multi.conf không tồn tại!"
        exit 1
    fi
    
    if [ ! -f "$MT_PROXY_AES_PWD" ]; then
        log_error "File proxy-secret không tồn tại!"
        exit 1
    fi
    
    if [ ! -f "$MT_PROXY_SECRET_FILE" ]; then
        log_error "File secret không tồn tại!"
        exit 1
    fi
    
    log_info "Tất cả các file cần thiết đã sẵn sàng"
    
    # Kiểm tra quyền truy cập của user mtproxy
    if ! sudo -u $MT_PROXY_USER test -r "$MT_PROXY_CONFIG"; then
        log_error "User $MT_PROXY_USER không có quyền đọc file config!"
        exit 1
    fi
    
    if ! sudo -u $MT_PROXY_USER test -r "$MT_PROXY_AES_PWD"; then
        log_error "User $MT_PROXY_USER không có quyền đọc file proxy-secret!"
        exit 1
    fi
    
    # Thử chạy trực tiếp để xem lỗi cụ thể
    log_info "Đang kiểm tra command..."
    if ! sudo -u $MT_PROXY_USER $MT_PROXY_BIN -u $MT_PROXY_USER -p $STATS_PORT -H $PROXY_PORT -S $(cat $MT_PROXY_SECRET_FILE | head -n 1 | tr -d '\n\r ') --aes-pwd $MT_PROXY_AES_PWD $MT_PROXY_CONFIG -M ${WORKERS:-1} --http-stats --nat-info $(ip route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}' || hostname -I | awk '{print $1}'):$(curl -s ifconfig.me || curl -s ipinfo.io/ip) 2>&1 | head -20; then
        log_warning "Command test có lỗi, nhưng sẽ tiếp tục..."
    fi
    
    systemctl restart MTProxy
    
    # Kiểm tra trạng thái
    sleep 3
    if systemctl is-active --quiet MTProxy; then
        log_success "MTProxy đã khởi động thành công"
    else
        log_error "MTProxy khởi động thất bại!"
        echo ""
        log_info "Chi tiết lỗi:"
        systemctl status MTProxy --no-pager -l
        echo ""
        log_info "Logs gần đây:"
        journalctl -u MTProxy -n 30 --no-pager
        echo ""
        log_info "Kiểm tra các file:"
        ls -la $MT_PROXY_DIR/
        echo ""
        log_info "Kiểm tra quyền truy cập:"
        sudo -u $MT_PROXY_USER ls -la $MT_PROXY_DIR/ 2>&1 || true
        echo ""
        exit 1
    fi
}

# Hàm xuất thông tin proxy
export_proxy_info() {
    log_info "Đang tạo thông tin proxy..."
    
    SECRET_HEX=$(cat $MT_PROXY_SECRET_FILE | head -n 1 | tr -d '\n\r ')
    get_ips
    
    # Chuyển đổi secret từ hex sang base64 để dùng trong proxy link
    SECRET_BASE64=$(convert_hex_to_base64 "$SECRET_HEX")
    
    # Tạo proxy link (sử dụng base64 secret)
    PROXY_LINK="tg://proxy?server=$PUBLIC_IP&port=$PROXY_PORT&secret=$SECRET_BASE64"
    
    echo ""
    echo "=========================================="
    echo "  MTProxy đã được cài đặt thành công!"
    echo "=========================================="
    echo ""
    echo "Thông tin Proxy:"
    echo "  IP: $PUBLIC_IP"
    echo "  Port: $PROXY_PORT"
    echo "  Secret (Hex): $SECRET_HEX"
    if [ ! -z "$SECRET_BASE64" ]; then
        echo "  Secret (Base64): $SECRET_BASE64"
    fi
    echo ""
    echo "Link Proxy (Telegram):"
    if [ ! -z "$SECRET_BASE64" ]; then
        echo "  $PROXY_LINK"
    else
        echo "  tg://proxy?server=$PUBLIC_IP&port=$PROXY_PORT&secret=$SECRET_HEX"
    fi
    echo ""
    echo "Hoặc sử dụng format này trong Telegram:"
    echo "  Server: $PUBLIC_IP"
    echo "  Port: $PROXY_PORT"
    echo "  Secret: $SECRET_HEX (hex) hoặc $SECRET_BASE64 (base64)"
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
Secret (Hex): $SECRET_HEX
Secret (Base64): $SECRET_BASE64
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
    create_mtproxy_user
    download_telegram_files
    generate_secret
    update_proxy_config
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

# Port cho MTProxy (mặc định: 8443 theo hướng dẫn)
# Đảm bảo port này chưa được sử dụng bởi service khác
PROXY_PORT=8443

# Số lượng workers (mặc định: không giới hạn)
# Để trống = không giới hạn workers (khuyến nghị)
# Hoặc đặt số cụ thể, ví dụ: WORKERS=4
WORKERS=""

