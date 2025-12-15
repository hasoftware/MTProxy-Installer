# MTProxy Auto Installer

Script tự động cài đặt MTProxy cho VPS Linux với các tính năng:

1. ✅ Tự động phát hiện hệ điều hành Linux (Ubuntu, Debian, CentOS, RHEL, Fedora)
2. ✅ Tự động cài đặt MTProxy và xuất thông tin proxy
3. ✅ Hỗ trợ cấu hình Channel Promo từ file config

## Yêu cầu

- Hệ điều hành: Linux (Ubuntu, Debian, CentOS, RHEL, Fedora)
- Quyền: Root hoặc sudo
- Kết nối Internet

## Cách sử dụng

### 1. Cấu hình (Tùy chọn)

Chỉnh sửa phần cấu hình ở cuối file `install_mtproxy.sh` nếu bạn muốn cấu hình Channel Promo hoặc thay đổi port:

```bash
# Mở script và chỉnh sửa phần CONFIG SECTION ở cuối file
nano install_mtproxy.sh

# Tìm đến dòng #=== CONFIG SECTION === và chỉnh sửa:
# PROMO_CHANNEL="@your_channel"  # Thêm Channel Promo
# PROXY_PORT=8080                 # Thay đổi port
# WORKERS=""                      # Để trống = không giới hạn (mặc định)
```

### 2. Chạy script cài đặt

```bash
# Cấp quyền thực thi
chmod +x install_mtproxy.sh

# Chạy script với quyền root
sudo ./install_mtproxy.sh
```

### 3. Lấy thông tin Proxy

Sau khi cài đặt thành công, script sẽ hiển thị:

- IP Public
- Port
- Secret
- Link proxy để sử dụng trong Telegram

Thông tin cũng được lưu trong file: `/opt/mtproxy/proxy_info.txt`

## Quản lý Service

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

## Cấu trúc File

- `install_mtproxy.sh` - Script chính để cài đặt (có phần cấu hình ở cuối file)
- `update_promo.sh` - Script cập nhật Channel Promo
- `/opt/mtproxy/` - Thư mục cài đặt MTProxy
  - `mtproto-proxy` - Binary file
  - `config.conf` - File cấu hình MTProxy
  - `secret` - File chứa secret key
  - `proxy_info.txt` - Thông tin proxy đã tạo

## Channel Promo

### Cấu hình trước khi cài đặt

1. Tạo một channel trên Telegram
2. Thêm bot @MTProxybot vào channel làm admin
3. Lấy username channel (ví dụ: `@your_channel`)
4. Mở file `install_mtproxy.sh` và chỉnh sửa phần `#=== CONFIG SECTION ===` ở cuối file:
   ```bash
   PROMO_CHANNEL="@your_channel"
   ```
5. Chạy script cài đặt
6. **QUAN TRỌNG**: Sau khi cài đặt, bạn cần đăng ký proxy với @MTProxybot để kích hoạt Channel Promo:

   - Mở Telegram và tìm bot: **@MTProxybot**
   - Gửi lệnh: `/newproxy`
   - Bot sẽ hỏi IP và Port, gửi: `YOUR_IP:443` (thay YOUR_IP bằng IP của bạn)
   - Khi bot hỏi: "Now please specify its secret in hex format", gửi secret ở định dạng hex (script đã tự động hiển thị sau khi cài đặt)
   - Bot sẽ hỏi channel để quảng cáo, gửi: `@your_channel`

   Script sẽ tự động hiển thị secret ở định dạng hex sau khi cài đặt thành công. Bạn có thể tìm thấy trong file `/opt/mtproxy/proxy_info.txt`

### Cập nhật Channel Promo sau khi cài đặt

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

## Gỡ cài đặt

```bash
# Dừng và xóa service
sudo systemctl stop mtproxy
sudo systemctl disable mtproxy
sudo rm $SERVICE_FILE
sudo systemctl daemon-reload

# Xóa thư mục cài đặt
sudo rm -rf /opt/mtproxy
```

## Lưu ý

- Port mặc định là 443 (HTTPS), đảm bảo port này chưa được sử dụng
- Script sẽ tự động tạo secret mới nếu chưa có
- Nếu đã cài đặt trước đó, script sẽ sử dụng secret cũ
- Đảm bảo firewall cho phép kết nối đến port đã cấu hình

## Hỗ trợ

Nếu gặp vấn đề, kiểm tra logs:

```bash
sudo journalctl -u mtproxy -n 50
```
