#!/bin/bash

# Cài đặt các dependencies
apt update
apt install -y git curl build-essential libssl-dev zlib1g-dev

# Clone repository MTProxy
git clone https://github.com/TelegramMessenger/MTProxy
cd MTProxy

# Biên dịch
make

# Tạo thư mục cho MTProxy
mkdir -p /opt/mtproxy
cp objs/bin/mtproto-proxy /opt/mtproxy/

# Tạo file cấu hình
cat > /opt/mtproxy/config << EOL
# Cấu hình cơ bản
port=443
workers=4
mtproto-proxy -H 443 --aes-pwd proxy-secret proxy-multi.conf -M 1
EOL

# Tạo file proxy-multi.conf
cat > /opt/mtproxy/proxy-multi.conf << EOL
# Cấu hình proxy
# Thay YOUR_CHANNEL_USERNAME bằng username kênh của bạn
# Thay YOUR_CHANNEL_ID bằng ID kênh của bạn
# Thay YOUR_SPONSORED_CHANNEL_ID bằng ID kênh được tài trợ
# Thay YOUR_SPONSORED_CHANNEL_USERNAME bằng username kênh được tài trợ

{
    "tag": "proxy1",
    "port": 443,
    "secret": "YOUR_SECRET_KEY",
    "sponsored_channel": {
        "channel_id": "YOUR_SPONSORED_CHANNEL_ID",
        "channel_username": "YOUR_SPONSORED_CHANNEL_USERNAME"
    }
}
EOL

# Tạo service file
cat > /etc/systemd/system/mtproxy.service << EOL
[Unit]
Description=MTProxy Service
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/mtproxy
ExecStart=/opt/mtproxy/mtproto-proxy -H 443 --aes-pwd proxy-secret proxy-multi.conf -M 1
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOL

# Cấp quyền thực thi
chmod +x /opt/mtproxy/mtproto-proxy
chmod +x /opt/mtproxy/config

# Khởi động service
systemctl daemon-reload
systemctl enable mtproxy
systemctl start mtproxy

echo "MTProxy đã được cài đặt thành công!"
echo "Vui lòng chỉnh sửa file /opt/mtproxy/proxy-multi.conf với thông tin kênh của bạn" 