# MTProxy Auto Installer

[![GitHub](https://img.shields.io/badge/GitHub-hasoftware-blue)](https://github.com/hasoftware/MTProxy-Installer)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

Script tự động cài đặt MTProxy cho VPS Linux với các tính năng:

- ✅ Tự động phát hiện hệ điều hành Linux (Ubuntu, Debian, CentOS, RHEL, Fedora)
- ✅ Tự động cài đặt MTProxy và xuất thông tin proxy
- ✅ Hỗ trợ cấu hình Channel Promo từ file config
- ✅ Tự động chuyển đổi secret sang hex format để đăng ký với @MTProxybot
- ✅ Tự động cấu hình firewall

## 📋 Yêu cầu

- Hệ điều hành: Linux (Ubuntu, Debian, CentOS, RHEL, Fedora)
- Quyền: Root hoặc sudo
- Kết nối Internet
- Git (để clone repository)

## 🚀 Cài đặt nhanh

### Bước 1: Clone repository

```bash
git clone https://github.com/hasoftware/MTProxy-Installer.git
cd MTProxy-Installer
```

### Bước 2: Cấu hình (Tùy chọn)

Chỉnh sửa phần cấu hình ở cuối file `install_mtproxy.sh` nếu bạn muốn cấu hình Channel Promo hoặc thay đổi port:

```bash
nano install_mtproxy.sh
```

Tìm đến dòng `#=== CONFIG SECTION ===` ở cuối file và chỉnh sửa:

```bash
# Channel Promo (ví dụ: @your_channel)
PROMO_CHANNEL="@your_channel"

# Port cho MTProxy (mặc định: 443)
PROXY_PORT=443

# Số lượng workers (để trống = không giới hạn)
WORKERS=""
```

### Bước 3: Chạy script cài đặt

```bash
# Cấp quyền thực thi
chmod +x install_mtproxy.sh

# Chạy script với quyền root
sudo ./install_mtproxy.sh
```

### Bước 4: Lấy thông tin Proxy

Sau khi cài đặt thành công, script sẽ tự động hiển thị:

- ✅ IP Public
- ✅ Port
- ✅ Secret (Base64) - để sử dụng trong proxy link
- ✅ Secret (Hex) - để đăng ký với @MTProxybot
- ✅ Link proxy để sử dụng trong Telegram

Thông tin cũng được lưu trong file: `/opt/mtproxy/proxy_info.txt`

## 📱 Đăng ký Channel Promo với @MTProxybot

Nếu bạn đã cấu hình `PROMO_CHANNEL` trong script, sau khi cài đặt thành công, làm theo các bước sau:

1. **Mở Telegram** và tìm bot: **@MTProxybot**
2. **Gửi lệnh**: `/newproxy`
3. Bot sẽ hỏi IP và Port, gửi: `YOUR_IP:443` (thay YOUR_IP bằng IP của bạn)
4. Khi bot hỏi: **"Now please specify its secret in hex format"**, gửi secret ở định dạng hex (script đã tự động hiển thị sau khi cài đặt)
5. Bot sẽ hỏi channel để quảng cáo, gửi: `@your_channel`

> 💡 **Lưu ý**: Secret ở định dạng hex được hiển thị tự động sau khi cài đặt và cũng được lưu trong file `/opt/mtproxy/proxy_info.txt`

## 🔧 Quản lý Service

```bash
# Kiểm tra trạng thái
sudo systemctl status mtproxy

# Khởi động lại
sudo systemctl restart mtproxy

# Dừng service
sudo systemctl stop mtproxy

# Xem logs
sudo journalctl -u mtproxy -f
```

## 📝 Cập nhật Channel Promo sau khi cài đặt

Sử dụng script `update_promo.sh`:

```bash
# Cấp quyền thực thi
chmod +x update_promo.sh

# Cập nhật Channel Promo
sudo ./update_promo.sh "@your_channel"

# Hoặc chạy và nhập khi được hỏi
sudo ./update_promo.sh
```

Để xóa Channel Promo:

```bash
sudo ./update_promo.sh ""
```

## 📂 Cấu trúc File

```
MTProxy-Installer/
├── install_mtproxy.sh    # Script chính để cài đặt (có phần cấu hình ở cuối file)
├── update_promo.sh      # Script cập nhật Channel Promo
├── README.md            # Tài liệu hướng dẫn
└── .gitignore           # Git ignore file

Sau khi cài đặt:
/opt/mtproxy/
├── mtproto-proxy        # Binary file
├── config.conf          # File cấu hình MTProxy
├── secret               # File chứa secret key
└── proxy_info.txt       # Thông tin proxy đã tạo
```

## 🗑️ Gỡ cài đặt

```bash
# Dừng và xóa service
sudo systemctl stop mtproxy
sudo systemctl disable mtproxy
sudo rm /etc/systemd/system/mtproxy.service
sudo systemctl daemon-reload

# Xóa thư mục cài đặt
sudo rm -rf /opt/mtproxy
```

## ⚠️ Lưu ý

- Port mặc định là **443** (HTTPS), đảm bảo port này chưa được sử dụng
- Script sẽ tự động tạo secret mới nếu chưa có
- Nếu đã cài đặt trước đó, script sẽ sử dụng secret cũ
- Script tự động cấu hình firewall (UFW, firewalld, hoặc iptables)
- Đảm bảo firewall cho phép kết nối đến port đã cấu hình

## 🐛 Xử lý lỗi

Nếu gặp vấn đề, kiểm tra logs:

```bash
# Xem logs của service
sudo journalctl -u mtproxy -n 50

# Xem logs real-time
sudo journalctl -u mtproxy -f

# Kiểm tra trạng thái service
sudo systemctl status mtproxy
```

## 📚 Hướng dẫn chi tiết

### Cấu hình Channel Promo trước khi cài đặt

1. Tạo một channel trên Telegram
2. Thêm bot **@MTProxybot** vào channel làm admin
3. Lấy username channel (ví dụ: `@your_channel`)
4. Mở file `install_mtproxy.sh` và chỉnh sửa phần `#=== CONFIG SECTION ===` ở cuối file:
   ```bash
   PROMO_CHANNEL="@your_channel"
   ```
5. Chạy script cài đặt
6. Đăng ký với @MTProxybot như hướng dẫn ở trên

### Sử dụng Proxy trong Telegram

Sau khi cài đặt thành công, bạn có thể sử dụng proxy theo các cách sau:

**Cách 1: Sử dụng link tự động**
- Copy link `tg://proxy?server=...` từ output của script
- Mở Telegram và paste link vào chat bất kỳ
- Nhấn vào link để kết nối

**Cách 2: Cấu hình thủ công**
- Vào Settings → Data and Storage → Connection Type → Use Proxy
- Chọn "Add Proxy" → "MTProto Proxy"
- Nhập thông tin:
  - Server: IP của bạn
  - Port: 443 (hoặc port bạn đã cấu hình)
  - Secret: Secret ở định dạng Base64

## 🤝 Đóng góp

Mọi đóng góp đều được chào đón! Vui lòng:

1. Fork repository
2. Tạo branch mới (`git checkout -b feature/AmazingFeature`)
3. Commit thay đổi (`git commit -m 'Add some AmazingFeature'`)
4. Push lên branch (`git push origin feature/AmazingFeature`)
5. Mở Pull Request

## 📄 License

Dự án này được phân phối dưới giấy phép MIT. Xem file `LICENSE` để biết thêm chi tiết.

## 🔗 Liên kết

- Repository: [https://github.com/hasoftware/MTProxy-Installer](https://github.com/hasoftware/MTProxy-Installer)
- MTProxy Official: [https://github.com/TelegramMessenger/MTProxy](https://github.com/TelegramMessenger/MTProxy)
- MTProxy Bot: [@MTProxybot](https://t.me/MTProxybot)

## ⭐ Star

Nếu dự án này hữu ích với bạn, hãy cho một ⭐ trên GitHub!

---

**Made with ❤️ by hasoftware**
