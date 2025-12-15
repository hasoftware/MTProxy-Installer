#!/bin/bash

# MTProxy Channel Promo Update Script
# NOTE: Channel promo is now managed through @MTProxybot via proxy tag
# This script is deprecated but kept for reference

set -e

# Colors
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

# Check root privileges
if [ "$EUID" -ne 0 ]; then
    log_error "Please run script with root privileges (sudo)"
    exit 1
fi

echo ""
log_warning "=========================================="
log_warning "  IMPORTANT NOTICE"
log_warning "=========================================="
echo ""
log_info "Channel promo is now managed through @MTProxybot via proxy tag."
log_info "This script is deprecated and no longer functional."
echo ""
log_info "To manage channel promo:"
log_info "1. Open Telegram and find bot: @MTProxybot"
log_info "2. Use /editproxy command with your proxy tag"
log_info "3. Follow the bot's instructions to update channel promo"
echo ""
log_warning "This script will exit now."
echo ""
exit 0
