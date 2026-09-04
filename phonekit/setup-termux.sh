#!/usr/bin/env bash
# setup-termux.sh - one-shot Termux provisioning. RUN THIS INSIDE TERMUX ON THE PHONE:
#
#   sh <(curl -fsSL https://raw.githubusercontent.com/DOINKPATH/Android-Debugger-Pro/main/phonekit/setup-termux.sh)
#
# OR copy this file to the phone and run:  bash setup-termux.sh
# This sets up the "both ways" SSH bridge + a stable multi-source package suite.
set -euo pipefail

LAPTOP_USER="${LAPTOP_USER:-nigel}"
LAPTOP_HOST="${LAPTOP_HOST:-kali}"
LAPTOP_KEY="${LAPTOP_KEY:-}"   # optional: your laptop's id_ed25519.pub content

echo "==> Termux provisioning started on: $(uname -a) ($(date))"

# 1) Package repositories: use Termux main + x11 + root (community/extra is in root)
if ! grep -q 'packages.termux.org' "$PREFIX/etc/apt/sources.list" 2>/dev/null; then
  pkg install -y termux-tools >/dev/null 2>&1 || true
fi
pkg update -y
pkg upgrade -y

# 2) Core packages for ADB/SSH/cli workflow
pkg install -y openssh android-tools termux-api tmux git curl wget python nodejs-lts nano \
               fzf ripgrep bat termux-auth termux-packages 2>/dev/null || \
pkg install -y openssh android-tools termux-api tmux git curl wget python nodejs-lts nano

# 3) SSH server for the both-ways bridge
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
if [ -n "$LAPTOP_KEY" ]; then
  echo "$LAPTOP_KEY" >> "$HOME/.ssh/authorized_keys"
else
  echo "NOTE: add your laptop key manually: echo '<pub>' >> ~/.ssh/authorized_keys"
fi

# 4) Start sshd (Termux sshd). Made persistent with termux-wake-lock if present.
command -v sshd >/dev/null && {
  [ ! -f "$PREFIX/var/service/sshd/run" ] && pkg install -y termux-services >/dev/null 2>&1 || true
  sv-enable sshd 2>/dev/null || sshd 2>/dev/null || true
}
touch "$HOME/.hushlogin" 2>/dev/null || true

# 5) Kali proot distro (via DOINKPATH/proot-distro) - gives a Kali environment
if ! command -v proot-distro >/dev/null; then
  pkg install -y proot-distro
fi
if ! proot-distro list | grep -qi kali 2>/dev/null; then
  echo "==> Installing Kali proot distro (may take a few minutes)..."
  proot-distro install kali || echo "proot Kali install deferred (needs network/time)"
fi

echo
echo "==> DONE. Verify with:"
echo "    sshd on :$PREFIX/bin/sshd  ->  run: sshd   (keep this terminal open)"
echo "    laptop->phone: ./ssh2termux"
echo "    phone's own IP (for termux->laptop ssh): $(command -v whoami >/dev/null && echo n/a)"