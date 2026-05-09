# MTProxy Auto Installer

[![GitHub](https://img.shields.io/badge/GitHub-hasoftware-blue)](https://github.com/hasoftware/MTProxy-Installer)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

Script tự động cài đặt MTProxy trên VPS Linux với các tính năng sau:

- Tự động phát hiện hệ điều hành Linux (Ubuntu, Debian, CentOS, RHEL, Fedora)
- Tự động cài đặt MTProxy theo tài liệu chính thức
- Hỗ trợ tương tác đăng ký proxy tag với @MTProxybot
- Tự động cấu hình firewall
- Tạo secret ở định dạng hex để đăng ký với bot

## Yêu cầu hệ thống

- Hệ điều hành: Linux (Ubuntu, Debian, CentOS, RHEL, Fedora)
- Quyền: Root hoặc sudo
- Có kết nối Internet
- Đã cài Git (để clone repository)

## Hướng dẫn cài đặt nhanh

### Bước 1: Clone Repository

```bash
git clone https://github.com/hasoftware/MTProxy-Installer.git
cd MTProxy-Installer
```

### Bước 2: Cấu hình (Tùy chọn)

Chỉnh sửa phần cấu hình ở cuối file `install_mtproxy.sh` nếu bạn muốn đổi port hoặc thiết lập channel promo tham khảo:

```bash
nano install_mtproxy.sh
```

Tìm dòng `#=== CONFIG SECTION ===` ở cuối file và chỉnh sửa:

```bash
# Channel Promo (tùy chọn - chỉ để tham khảo, được quản lý qua bot)
# Channel promo được quản lý qua Telegram bot (@MTProxybot) thông qua proxy tag
PROMO_CHANNEL="@your_channel"

# Port cho MTProxy (mặc định: 8443)
PROXY_PORT=8443

# Số lượng workers (để trống nếu muốn không giới hạn)
WORKERS=""

# Proxy Tag từ @MTProxybot (tùy chọn - sẽ được hỏi trong quá trình cài đặt)
PROXY_TAG=""
```

### Bước 3: Chạy script cài đặt

```bash
# Cấp quyền thực thi cho script
chmod +x install_mtproxy.sh

# Chạy script với quyền root
sudo ./install_mtproxy.sh
```

### Bước 4: Đăng ký với @MTProxybot

Trong quá trình cài đặt, script sẽ:

1. Tạo secret key (định dạng hex)
2. Hiển thị hướng dẫn đăng ký với @MTProxybot
3. Chờ bạn đăng ký và lấy proxy tag
4. Yêu cầu bạn nhập proxy tag
5. Hoàn tất quá trình cài đặt

**Các bước đăng ký:**

1. Mở Telegram và tìm bot: **@MTProxybot**
2. Gửi lệnh: `/newproxy`
3. Khi bot hỏi Secret Key, gửi đoạn hex secret hiển thị bởi script
4. Khi bot hỏi IP và Port, gửi: `YOUR_IP:8443` (thay YOUR_IP bằng IP server của bạn)
5. Bot sẽ trả về một Proxy Tag (32 ký tự hex)
6. Quay lại script và nhập proxy tag khi được yêu cầu

**Lưu ý:** Channel promo được quản lý thông qua bot trong quá trình đăng ký, không phải trong file cấu hình.

## Thông tin Proxy

Sau khi cài đặt thành công, script sẽ tự động hiển thị:

- IP Public
- Port
- Secret (Hex) - dùng để đăng ký với bot
- Secret (Base64) - dùng cho proxy link
- Proxy Tag - từ @MTProxybot
- Link proxy Telegram

Thông tin cũng được lưu vào: `/opt/MTProxy/proxy_info.txt`

## Quản lý Service

```bash
# Kiểm tra trạng thái
sudo systemctl status MTProxy

# Khởi động lại service
sudo systemctl restart MTProxy

# Dừng service
sudo systemctl stop MTProxy

# Xem logs theo thời gian thực
sudo journalctl -u MTProxy -f

# Xem logs gần đây
sudo journalctl -u MTProxy -n 50
```

## Cấu trúc thư mục

```
MTProxy-Installer/
├── install_mtproxy.sh    # Script cài đặt chính (phần config nằm ở cuối file)
├── update_promo.sh       # Script cập nhật Channel Promo (deprecated - dùng bot thay thế)
├── uninstall.sh          # Script gỡ cài đặt hoàn toàn
├── README.md             # Tài liệu hướng dẫn
└── .gitignore            # File git ignore
```

Sau khi cài đặt:

```
/opt/MTProxy/
├── mtproto-proxy         # File binary thực thi
├── proxy-multi.conf      # File cấu hình (tải từ Telegram)
├── proxy-secret          # File mật khẩu AES (tải từ Telegram)
├── secret                # File secret key (định dạng hex)
└── proxy_info.txt        # Thông tin proxy
```

## Gỡ cài đặt

### Sử dụng script tự động (Khuyến nghị)

```bash
# Cấp quyền thực thi cho script
chmod +x uninstall.sh

# Chạy script gỡ cài đặt
sudo ./uninstall.sh
```

Script sẽ:

- Dừng và xóa service MTProxy
- Xóa thư mục cài đặt `/opt/MTProxy`
- Xóa logs
- Hỏi bạn có muốn xóa rule firewall không
- Kiểm tra và báo cáo các file còn sót lại

### Gỡ cài đặt thủ công

Nếu bạn muốn gỡ cài đặt thủ công:

```bash
# Dừng và xóa service
sudo systemctl stop MTProxy
sudo systemctl disable MTProxy
sudo rm /etc/systemd/system/MTProxy.service
sudo systemctl daemon-reload

# Xóa thư mục cài đặt
sudo rm -rf /opt/MTProxy

# Xóa user mtproxy (tùy chọn)
sudo userdel mtproxy
```

## Lưu ý quan trọng

- Port mặc định là **8443** (đảm bảo port này chưa được sử dụng)
- Script tự động tạo secret mới nếu chưa có
- Nếu đã cài đặt rồi, script sẽ sử dụng secret hiện có
- Script tự động cấu hình firewall (UFW, firewalld, hoặc iptables)
- File cấu hình (`proxy-multi.conf`) được tải từ Telegram, không tự tạo thủ công
- Secret được truyền qua flag `-S` trong câu lệnh, không nằm trong file cấu hình
- Channel promo được quản lý qua @MTProxybot, không nằm trong file cấu hình
- Cần có proxy tag để sử dụng tính năng channel promo

## Khắc phục sự cố

Nếu gặp vấn đề, hãy kiểm tra logs:

```bash
# Xem logs của service
sudo journalctl -u MTProxy -n 50

# Xem logs theo thời gian thực
sudo journalctl -u MTProxy -f

# Kiểm tra trạng thái service
sudo systemctl status MTProxy

# Kiểm tra port có đang được sử dụng không
sudo netstat -tulnp | grep 8443
# hoặc
sudo ss -tulnp | grep 8443
```

### Các lỗi thường gặp

**Port đã được sử dụng:**

```bash
# Tìm process đang sử dụng port
sudo lsof -i :8443
# hoặc
sudo netstat -tulnp | grep 8443

# Kill process đó hoặc đổi port trong phần config
```

**Service không khởi động được:**

- Kiểm tra logs: `sudo journalctl -u MTProxy -n 50`
- Kiểm tra file config có tồn tại không: `ls -la /opt/MTProxy/proxy-multi.conf`
- Kiểm tra file secret có tồn tại không: `ls -la /opt/MTProxy/secret`
- Kiểm tra quyền truy cập file: `ls -la /opt/MTProxy/`

## Sử dụng Proxy trong Telegram

Sau khi cài đặt thành công, bạn có thể sử dụng proxy theo các cách sau:

**Cách 1: Sử dụng Link tự động**

- Sao chép link `tg://proxy?server=...` từ output của script
- Mở Telegram và dán link vào bất kỳ cuộc trò chuyện nào
- Nhấn vào link để kết nối

**Cách 2: Cấu hình thủ công**

- Vào Settings → Data and Storage → Connection Type → Use Proxy
- Chọn "Add Proxy" → "MTProto Proxy"
- Nhập thông tin:
  - Server: IP server của bạn
  - Port: 8443 (hoặc port bạn đã cấu hình)
  - Secret: Secret ở định dạng Base64 (hiển thị bởi script)

## Cách hoạt động

Script cài đặt này tuân theo tài liệu MTProxy chính thức từ [TelegramMessenger/MTProxy](https://github.com/TelegramMessenger/MTProxy):

1. Tải `proxy-secret` và `proxy-multi.conf` từ Telegram
2. Tạo secret key (định dạng hex)
3. Yêu cầu người dùng đăng ký với @MTProxybot và lấy proxy tag
4. Tạo systemd service với câu lệnh đúng định dạng:
   ```
   mtproto-proxy -u mtproxy -p 8888 -H 8443 -S <secret> --aes-pwd proxy-secret proxy-multi.conf -M 1 -P <proxy-tag>
   ```
5. Tự động cấu hình firewall

## Đóng góp

Mọi đóng góp đều được hoan nghênh! Vui lòng:

1. Fork repository
2. Tạo branch mới (`git checkout -b feature/AmazingFeature`)
3. Commit các thay đổi (`git commit -m 'Add some AmazingFeature'`)
4. Push lên branch (`git push origin feature/AmazingFeature`)
5. Mở một Pull Request

## Giấy phép

Dự án này được phân phối theo giấy phép MIT. Xem file `LICENSE` để biết thêm chi tiết.

## Liên kết

- Repository: [https://github.com/hasoftware/MTProxy-Installer](https://github.com/hasoftware/MTProxy-Installer)
- MTProxy Official: [https://github.com/TelegramMessenger/MTProxy](https://github.com/TelegramMessenger/MTProxy)
- MTProxy Bot: [@MTProxybot](https://t.me/MTProxybot)

## Star

Nếu dự án này hữu ích với bạn, hãy cho một sao trên GitHub!

---

**Made with ❤️ by hasoftware**
