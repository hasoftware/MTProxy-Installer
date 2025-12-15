# MTProxy Auto Installer

[![GitHub](https://img.shields.io/badge/GitHub-hasoftware-blue)](https://github.com/hasoftware/MTProxy-Installer)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

Automated installation script for MTProxy on Linux VPS with the following features:

- Automatic Linux OS detection (Ubuntu, Debian, CentOS, RHEL, Fedora)
- Automatic MTProxy installation following official documentation
- Interactive proxy tag registration with @MTProxybot
- Automatic firewall configuration
- Secret generation in hex format for bot registration

## Requirements

- Operating System: Linux (Ubuntu, Debian, CentOS, RHEL, Fedora)
- Privileges: Root or sudo access
- Internet connection
- Git (to clone repository)

## Quick Installation

### Step 1: Clone Repository

```bash
git clone https://github.com/hasoftware/MTProxy-Installer.git
cd MTProxy-Installer
```

### Step 2: Configure (Optional)

Edit the configuration section at the end of `install_mtproxy.sh` if you want to change the port or set channel promo reference:

```bash
nano install_mtproxy.sh
```

Find the `#=== CONFIG SECTION ===` at the end of the file and edit:

```bash
# Channel Promo (optional - for reference only, managed via bot)
# Channel promo is managed through Telegram bot (@MTProxybot) via proxy tag
PROMO_CHANNEL="@your_channel"

# Port for MTProxy (default: 8443)
PROXY_PORT=8443

# Number of workers (leave empty for unlimited)
WORKERS=""

# Proxy Tag from @MTProxybot (optional - will be prompted during installation)
PROXY_TAG=""
```

### Step 3: Run Installation Script

```bash
# Make script executable
chmod +x install_mtproxy.sh

# Run script with root privileges
sudo ./install_mtproxy.sh
```

### Step 4: Register with @MTProxybot

During installation, the script will:

1. Generate a secret key (hex format)
2. Display instructions to register with @MTProxybot
3. Wait for you to register and get the proxy tag
4. Prompt you to enter the proxy tag
5. Complete the installation

**Registration Steps:**

1. Open Telegram and find bot: **@MTProxybot**
2. Send command: `/newproxy`
3. When bot asks for Secret Key, send the hex secret displayed by the script
4. When bot asks for IP and Port, send: `YOUR_IP:8443` (replace YOUR_IP with your server IP)
5. Bot will return a Proxy Tag (32 hex characters)
6. Return to the script and enter the proxy tag when prompted

**Note:** Channel promo is managed through the bot during registration, not in the config file.

## Proxy Information

After successful installation, the script will automatically display:

- Public IP
- Port
- Secret (Hex) - for bot registration
- Secret (Base64) - for proxy link
- Proxy Tag - from @MTProxybot
- Telegram proxy link

Information is also saved to: `/opt/MTProxy/proxy_info.txt`

## Service Management

```bash
# Check status
sudo systemctl status MTProxy

# Restart service
sudo systemctl restart MTProxy

# Stop service
sudo systemctl stop MTProxy

# View logs
sudo journalctl -u MTProxy -f

# View recent logs
sudo journalctl -u MTProxy -n 50
```

## File Structure

```
MTProxy-Installer/
├── install_mtproxy.sh    # Main installation script (config section at end)
├── update_promo.sh       # Script to update Channel Promo (deprecated - use bot)
├── uninstall.sh          # Complete uninstallation script
├── README.md             # Documentation
└── .gitignore            # Git ignore file
```

After installation:

```
/opt/MTProxy/
├── mtproto-proxy         # Binary executable
├── proxy-multi.conf      # Config file (downloaded from Telegram)
├── proxy-secret          # AES password file (downloaded from Telegram)
├── secret                # Secret key file (hex format)
└── proxy_info.txt        # Proxy information
```

## Uninstallation

### Using Automatic Script (Recommended)

```bash
# Make script executable
chmod +x uninstall.sh

# Run uninstallation script
sudo ./uninstall.sh
```

The script will:

- Stop and remove MTProxy service
- Remove installation directory `/opt/MTProxy`
- Remove logs
- Ask if you want to remove firewall rules
- Check and report any remaining files

### Manual Uninstallation

If you prefer manual uninstallation:

```bash
# Stop and remove service
sudo systemctl stop MTProxy
sudo systemctl disable MTProxy
sudo rm /etc/systemd/system/MTProxy.service
sudo systemctl daemon-reload

# Remove installation directory
sudo rm -rf /opt/MTProxy

# Remove mtproxy user (optional)
sudo userdel mtproxy
```

## Important Notes

- Default port is **8443** (ensure this port is not in use)
- Script automatically generates a new secret if one doesn't exist
- If already installed, script will use existing secret
- Script automatically configures firewall (UFW, firewalld, or iptables)
- Config file (`proxy-multi.conf`) is downloaded from Telegram, not created manually
- Secret is passed via `-S` flag in command, not in config file
- Channel promo is managed through @MTProxybot, not in config file
- Proxy tag is required for channel promo functionality

## Troubleshooting

If you encounter issues, check the logs:

```bash
# View service logs
sudo journalctl -u MTProxy -n 50

# View real-time logs
sudo journalctl -u MTProxy -f

# Check service status
sudo systemctl status MTProxy

# Check if port is in use
sudo netstat -tulnp | grep 8443
# or
sudo ss -tulnp | grep 8443
```

### Common Issues

**Port already in use:**

```bash
# Find process using the port
sudo lsof -i :8443
# or
sudo netstat -tulnp | grep 8443

# Kill the process or change port in config section
```

**Service fails to start:**

- Check logs: `sudo journalctl -u MTProxy -n 50`
- Verify config file exists: `ls -la /opt/MTProxy/proxy-multi.conf`
- Verify secret file exists: `ls -la /opt/MTProxy/secret`
- Check file permissions: `ls -la /opt/MTProxy/`

## Using Proxy in Telegram

After successful installation, you can use the proxy in the following ways:

**Method 1: Using Automatic Link**

- Copy the `tg://proxy?server=...` link from script output
- Open Telegram and paste the link in any chat
- Click on the link to connect

**Method 2: Manual Configuration**

- Go to Settings → Data and Storage → Connection Type → Use Proxy
- Select "Add Proxy" → "MTProto Proxy"
- Enter information:
  - Server: Your server IP
  - Port: 8443 (or your configured port)
  - Secret: Secret in Base64 format (displayed by script)

## How It Works

This installer follows the official MTProxy documentation from [TelegramMessenger/MTProxy](https://github.com/TelegramMessenger/MTProxy):

1. Downloads `proxy-secret` and `proxy-multi.conf` from Telegram
2. Generates a secret key (hex format)
3. Prompts user to register with @MTProxybot and get proxy tag
4. Creates systemd service with proper command format:
   ```
   mtproto-proxy -u mtproxy -p 8888 -H 8443 -S <secret> --aes-pwd proxy-secret proxy-multi.conf -M 1 -P <proxy-tag>
   ```
5. Configures firewall automatically

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a new branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is distributed under the MIT license. See the `LICENSE` file for more details.

## Links

- Repository: [https://github.com/hasoftware/MTProxy-Installer](https://github.com/hasoftware/MTProxy-Installer)
- MTProxy Official: [https://github.com/TelegramMessenger/MTProxy](https://github.com/TelegramMessenger/MTProxy)
- MTProxy Bot: [@MTProxybot](https://t.me/MTProxybot)

## Star

If this project is useful to you, please give it a star on GitHub!

---

**Made with ❤️ by hasoftware**
