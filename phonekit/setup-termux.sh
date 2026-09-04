#!/data/data/com.termux/files/usr/bin/bash
# setup-termux.sh - FULL-STACK Termux provisioning (dev + server + crypto + AI/ML).
# Run INSIDE Termux on the phone. Idempotent - safe to re-run.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/DOINKPATH/Android-Debugger-Pro/main/phonekit/setup-termux.sh)
#
# Flags:  NDK=1 (Android NDK, ~1.5GB)   JDK=21 (default 17)   ML=1 (torch/scipy)
#         SKIP_HEAVY=1   DEBIAN=1 (Debian proot too)   LAPTOP_KEY='<ed25519 pub>'
set -uo pipefail
STEP(){ printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ARCH="$(uname -m)"
command -v pkg >/dev/null || { echo 'ERROR: run inside Termux (pkg not found)' >&2; exit 1; }

STEP "0. Environment: arch=$ARCH  android=$(getprop ro.build.version.release 2>/dev/null || echo '?')"
pkg update -y; pkg upgrade -y || true

STEP "1. Multi-repo source.list: main + x11 + root + science + game + unstable"
pkg install -y x11-repo root-repo science-repo game-repo unstable-repo 2>/dev/null || true
ls "$PREFIX/etc/apt/sources.list.d/" 2>/dev/null || true

STEP "2. Core CLI"
pkg install -y coreutils findutils gawk sed which tar gzip xz-utils zip unzip p7zip \
  curl wget aria2 rsync git jq xxd file less nano vim tmux fzf ripgrep bat htop btop tree 2>/dev/null || true

STEP "3. Compilers & build toolchain (C/C++/make/cmake/binutils/gdb)"
pkg install -y clang make cmake ninja binutils pkg-config autoconf automake m4 libtool \
  bison flex gdb strace lld mold 2>/dev/null || true

STEP "4. Programming & scripting languages"
pkg install -y python python-pip python-numpy nodejs-lts ruby php perl lua54 golang rust 2>/dev/null || true

STEP "5. SDK / NDK / JDK / JRE (OpenJDK)"
JDK_VER="${JDK:-17}"
pkg install -y "openjdk-${JDK_VER}" 2>/dev/null || pkg install -y openjdk-17 || true
if [ "${NDK:-0}" = 1 ]; then STEP '5b. Android NDK (heavy)'; pkg install -y android-ndk ndk-multilib 2>/dev/null || true; else echo '  (set NDK=1 to install android-ndk ~1.5GB)'; fi

STEP "6. Servers & network"
pkg install -y openssh rsync sqlite nginx 2>/dev/null || true

STEP "7. Crypto / encoding / decoding toolkit"
pkg install -y openssl-tool gnupg age qrencode 2>/dev/null || true

STEP "8. AI / Machine Learning (pip)"
python3 -m pip install --upgrade pip 2>/dev/null || true
python3 -m pip install numpy 2>/dev/null || true
if [ "${ML:-0}" = 1 ]; then
  python3 -m pip install scipy pandas matplotlib 2>/dev/null || true
  python3 -m pip install torch torchvision 2>/dev/null || echo '  (torch build may fail on some arches)'
else
  echo '  (set ML=1 for torch/scipy/pandas)'
fi

STEP "9. Termux platform add-ons (API, services, wake-lock)"
pkg install -y termux-api termux-services termux-wake-lock 2>/dev/null || true
termux-wake-lock 2>/dev/null || true

STEP "10. SSH bridge: start sshd + install laptop key"
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
if [ -n "${LAPTOP_KEY:-}" ]; then
  echo "$LAPTOP_KEY" >> "$HOME/.ssh/authorized_keys"; chmod 600 "$HOME/.ssh/authorized_keys"
  echo '  laptop key installed'
else
  echo '  NOTE: add laptop key ->  echo "<ed25519 pub>" >> ~/.ssh/authorized_keys'
fi
pgrep -x sshd >/dev/null || sshd
# persistent service via termux-services (survives across Termux sessions)
if [ -d "$PREFIX/var/service/sshd" ]; then
  [ -e "$PREFIX/var/service/sshd/down" ] && rm -f "$PREFIX/var/service/sshd/down"
  echo '  sshd service enabled (termux-services)'
fi

STEP "11. Linux/GNU source.list inside proot (Kali, optional Debian/Ubuntu/Alpine)"
command -v proot-distro >/dev/null || pkg install -y proot-distro
if ! proot-distro list 2>/dev/null | grep -qi 'kali.*installed'; then
  echo '  installing Kali proot (takes a few minutes)...'
  proot-distro install kali 2>/dev/null || echo '  kali install deferred'
fi
if [ "${DEBIAN:-0}" = 1 ]; then
  proot-distro install debian 2>/dev/null || true
fi
# GNU/Kali source.list inside the chroot (required tools + repos, rootless)
proot-distro login kali -- bash -c 'echo "deb http://http.kali.org/kali kali-rolling main contrib non-free non-free-firmware" > /etc/apt/sources.list && apt-get update -qq' 2>/dev/null \
  && echo '  kali-rolling source.list configured (main contrib non-free non-free-firmware)' \
  || echo '  kali source.list deferred (install finished later; re-run setup)'

STEP "12. Compliance report - installed toolchains"
for c in clang gcc make cmake ninja git python3 pip3 node npm ruby php perl lua5.4 go rustc java javac; do
  v="$(command -v "$c" >/dev/null 2>&1 && "$c" --version 2>/dev/null | head -1 || echo 'not installed')"
  printf '  %-9s %s\n' "$c" "$v"
done
echo "  openssl    $(openssl version 2>/dev/null || echo 'not installed')"
echo "  gpg        $(gpg --version 2>/dev/null | head -1 || echo 'not installed')"

STEP "13. DONE"
echo '  Next (on phone):  phonesrv live        # or: phonesrv watch (resilient)'
echo '  Next (laptop):    ./adbr && ./ssh2termux && ./magctl status'
