#!/bin/bash

# MTProxy Uninstaller Script
# Completely remove MTProxy and all related files

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
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

# Confirmation function
confirm_uninstall() {
    echo ""
    log_warning "Are you sure you want to completely remove MTProxy?"
    log_warning "All data and configuration will be lost!"
    echo ""
    read -p "Type 'yes' to continue: " confirm
    
    confirm=$(echo "$confirm" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')
    
    case "$confirm" in
        yes|y|YES|Y)
            log_info "Confirmed, starting uninstallation..."
            ;;
        *)
            log_info "Uninstallation cancelled."
            exit 0
            ;;
    esac
}

# Stop and remove service
remove_service() {
    log_info "Stopping and removing MTProxy service..."
    
    if systemctl is-active --quiet MTProxy 2>/dev/null; then
        systemctl stop MTProxy
        log_success "Stopped MTProxy service"
    elif systemctl is-active --quiet mtproxy 2>/dev/null; then
        systemctl stop mtproxy
        log_success "Stopped mtproxy service (legacy)"
    else
        log_info "MTProxy service is not running"
    fi
    
    if systemctl is-enabled --quiet MTProxy 2>/dev/null; then
        systemctl disable MTProxy
        log_success "Disabled MTProxy service"
    elif systemctl is-enabled --quiet mtproxy 2>/dev/null; then
        systemctl disable mtproxy
        log_success "Disabled mtproxy service (legacy)"
    fi
    
    if [ -f "$SERVICE_FILE" ]; then
        rm -f "$SERVICE_FILE"
        log_success "Removed service file: $SERVICE_FILE"
    fi
    
    if [ -f "/etc/systemd/system/mtproxy.service" ]; then
        rm -f "/etc/systemd/system/mtproxy.service"
        log_success "Removed legacy service file"
    fi
    
    systemctl daemon-reload
    log_success "Reloaded systemd"
}

# Remove installation directory
remove_installation_directory() {
    log_info "Removing installation directory..."
    
    if [ -d "$MT_PROXY_DIR" ]; then
        rm -rf "$MT_PROXY_DIR"
        log_success "Removed directory: $MT_PROXY_DIR"
    else
        log_info "Installation directory does not exist"
    fi
    
    if [ -d "/opt/mtproxy" ]; then
        rm -rf "/opt/mtproxy"
        log_success "Removed legacy directory: /opt/mtproxy"
    fi
}

# Remove mtproxy user
remove_user() {
    log_info "Removing mtproxy user..."
    
    if id "$MT_PROXY_USER" &>/dev/null; then
        userdel -r "$MT_PROXY_USER" 2>/dev/null || userdel "$MT_PROXY_USER" 2>/dev/null || true
        log_success "Removed user: $MT_PROXY_USER"
    else
        log_info "User $MT_PROXY_USER does not exist"
    fi
}

# Remove log files
remove_logs() {
    log_info "Removing logs..."
    
    if journalctl -u MTProxy --no-pager > /dev/null 2>&1; then
        journalctl --vacuum-time=1s --unit=MTProxy > /dev/null 2>&1 || true
        log_success "Removed journal logs"
    fi
    
    if journalctl -u mtproxy --no-pager > /dev/null 2>&1; then
        journalctl --vacuum-time=1s --unit=mtproxy > /dev/null 2>&1 || true
        log_success "Removed legacy journal logs"
    fi
}

# Remove firewall rules (optional)
remove_firewall_rules() {
    log_info "Checking firewall rules..."
    
    local ports="8443 8888 443"
    
    for port in $ports; do
        if command -v ufw &> /dev/null; then
            if ufw status | grep -q "${port}/tcp"; then
                log_warning "Found firewall rule for port ${port}"
                log_info "Do you want to remove firewall rule for port ${port}? (y/n)"
                read -p "Choice: " remove_fw
                if [ "$remove_fw" = "y" ] || [ "$remove_fw" = "Y" ]; then
                    ufw delete allow ${port}/tcp 2>/dev/null || true
                    log_success "Removed firewall rule for port ${port}"
                fi
            fi
        fi
        
        if command -v firewall-cmd &> /dev/null; then
            if firewall-cmd --list-ports 2>/dev/null | grep -q "${port}/tcp"; then
                log_warning "Found firewall rule for port ${port} in firewalld"
                log_info "Do you want to remove firewall rule for port ${port}? (y/n)"
                read -p "Choice: " remove_fw
                if [ "$remove_fw" = "y" ] || [ "$remove_fw" = "Y" ]; then
                    firewall-cmd --permanent --remove-port=${port}/tcp 2>/dev/null || true
                    firewall-cmd --reload 2>/dev/null || true
                    log_success "Removed firewall rule for port ${port}"
                fi
            fi
        fi
    done
}

# Check and remove remaining files
check_remaining_files() {
    log_info "Checking for remaining files..."
    
    local found=0
    
    if [ -d "/opt/MTProxy" ]; then
        log_warning "Still found directory /opt/MTProxy"
        found=1
    fi
    
    if [ -d "/opt/mtproxy" ]; then
        log_warning "Still found legacy directory /opt/mtproxy"
        found=1
    fi
    
    if [ -f "/etc/systemd/system/MTProxy.service" ]; then
        log_warning "Still found service file /etc/systemd/system/MTProxy.service"
        found=1
    fi
    
    if [ -f "/etc/systemd/system/mtproxy.service" ]; then
        log_warning "Still found legacy service file /etc/systemd/system/mtproxy.service"
        found=1
    fi
    
    if systemctl list-unit-files | grep -qiE "MTProxy|mtproxy"; then
        log_warning "Still found service in systemd"
        found=1
    fi
    
    if id "$MT_PROXY_USER" &>/dev/null; then
        log_warning "Still found user: $MT_PROXY_USER"
        found=1
    fi
    
    if [ $found -eq 0 ]; then
        log_success "No remaining files related to MTProxy"
    fi
}

# Hàm main
main() {
    echo ""
    log_info "Bắt đầu gỡ cài đặt MTProxy..."
    echo ""
    
    # Kiểm tra quyền root
    if [ "$EUID" -ne 0 ]; then
        log_error "Vui lòng chạy script với quyền root (sudo)"
        exit 1
    fi
    
    # Xác nhận
    confirm_uninstall
    
    remove_service
    remove_installation_directory
    remove_user
    remove_logs
    
    echo ""
    log_info "Do you want to remove firewall rules? (may affect other services)"
    read -p "Remove firewall rules? (y/n, default: n): " remove_firewall
    if [ "$remove_firewall" = "y" ] || [ "$remove_firewall" = "Y" ]; then
        remove_firewall_rules
    else
        log_info "Skipping firewall rules removal"
    fi
    
    check_remaining_files
    
    echo ""
    log_success "MTProxy has been completely uninstalled!"
    echo ""
    log_info "All files and services have been removed."
    log_info "You can run install_mtproxy.sh again to reinstall if needed."
    echo ""
}

# Chạy main function
main

