#!/bin/bash
# Setup passwordless sudo for openfortivpn
# Run with: sudo bash Scripts/setup-sudoers.sh

set -euo pipefail

SUDOERS_FILE="/etc/sudoers.d/openfortivpn"
USER=$(logname 2>/dev/null || echo "$SUDO_USER")
HOMEBREW="/opt/homebrew/bin/openfortivpn"
BUNDLED="/Applications/AutoForti.app/Contents/MacOS/openfortivpn"

if [ -z "$USER" ]; then
    echo "Error: Cannot determine username"
    exit 1
fi

{
    echo "$USER ALL=(ALL) NOPASSWD: $HOMEBREW"
    [ -f "$BUNDLED" ] && echo "$USER ALL=(ALL) NOPASSWD: $BUNDLED"
    echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/killall openfortivpn"
} > "$SUDOERS_FILE"
chmod 0440 "$SUDOERS_FILE"
visudo -c -f "$SUDOERS_FILE"

echo "Done: $USER can now run openfortivpn without password"
