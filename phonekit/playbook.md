# Playbook — TCL 50 XL NXTPAPER 5G, linked to the Kali laptop

Target device: **TCL 50 XL NXTPAPER 5G** · `T704V` / `Ruby_TF` · Android 15 (SDK 35) · **MediaTek MT6835**
Laptop: Kali (as of setup, `DOINKPATH` GitHub, zsh, adb 1.0.41 / fastboot 37).

> **KDE policy:** the phone cannot use KDE. No KDE tooling is used, installed, or referenced.
> **Safety policy (as requested):** safe wiring + docs **only** — no bootloader unlock, no root, no flashing yet. Root/kernel/OTA actions are documented below as **post-unlock** steps, not executed now.

---

## 0. Status legend
Every real action has a badge. **`[LIVE]`** = usable today; **`[POST-UNLOCK]`** = only after the bootloader is unlocked (per your direction to hold those).

---

## 1. ADB control plane `[LIVE]`

**USB (current):** the phone already appears (device id `HUDA7XMZWCROIRJN`, state `device usb:1-1`). Start the daemon: `adb start-server` (running at :5037).

**Wireless (recommended over the USB link):**
```bash
adb tcpip 5555           # phone listens for TCP ADB on :5555
./adbw                   # helper: tries USB, Bluetooth (bnep0 / 169.254.0.1), then Wi-Fi heuristics
adb devices -l           # expect a tcp: connection
adb -s <ip>:5555 shell uname -a
```
Wireless requires Developer options → `ADB/Debug` → wireless ADB on the phone.

**Bluetooth (helper read from ~/.zshrc):**
`PHONE_BT_ADDR=BC:94:24:32:E8:43`, `ADB_PORT=5555`; `adb-bt` / `adb-wifi` aliases exist.

---

## 2. Termux — install & first-run `[LIVE]`

**Install source (multi-source, per your ask):**
- Recommended: **F-Droid** (upstream stable APK) — install F-Droid, then Termux from it.
- GitHub (upstream source): `https://api.github.com/repos/termux/termux-app/releases/latest` for the termux-app APK.
- Your forks (beta/pre-release tooling): clone `DOINKPATH/termux-app`, `termux-packages`, `proot-distro`, `termux-x11`.

**Bootstrap:**
```bash
# inside Termux on the phone:
pkg update && pkg upgrade -y
pkg install -y openssh android-tools termux-api tmux git curl wget python nodejs-lts nano \
               fzf ripgrep bat proot-distro
```
Or run the bundled one-shot: `bash setup-termux.sh` (installs the above + ssh key + Kali proot).

---

## 3. The both-ways SSH bridge `[LIVE]`

**Create the tunnel (laptop):**
```bash
./adbr                 # binds 127.0.0.1:5022 -> phone Termux sshd :8022 (adb reverse tcp:5022 tcp:8022)
```
**Login (laptop → phone):**
```bash
./ssh2termux           # auto-spawns the tunnel, then: ssh -p 5022 termux@127.0.0.1
```

**Phone → laptop (both ways):** add your laptop key to Termux, and Termux's pubkey to laptop `~/.ssh/authorized_keys`:
```bash
# laptop:
cat ~/.ssh/id_ed25519.pub            # note it
# Termux:
mkdir -p ~/.ssh && echo '<laptop-pub>' >> ~/.ssh/authorized_keys
ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519 && cat ~/.ssh/id_ed25519.pub
# then add that to ~/.ssh/authorized_keys on the laptop
```
Now from Termux: `ssh nigel@kali` works too. That is the both-ways link.

---

## 4. Magisk control plane `[LIVE]` guard, `[POST-UNLOCK]` actions

- Read-only (safe now): `./magctl status` (device / verified-boot state / magisk installed / root reachable?), `./magctl modules`.
- Root-dependent (deferred, `[POST-UNLOCK]`): `./magctl gotoshell`, plus:
  - Modules live in `/data/adb/modules` — push new ones with `adb push`, enable in Magisk.
  - Control from laptop = `adb shell su -c 'your-module command'`; from Termux = same inside Termux with root (post-unlock).
---

## 5. Boot state & unlock `[POST-UNLOCK]` — DO NOT RUN NOW

Current device read: `verifiedbootstate=green`, `vbmeta locked`, `flash.locked=1` (locked, stock).
TCL ships `/system/priv-app/tct-bootloaderunlock-res` (privileged, their unlock back-end) — **its activity isn't auto-launched**, and it may be TCL-locked/Tier-1.

When you choose to proceed (not now):
1. Backup data. **Unlock wipes the phone.**
2. `adb reboot bootloader` → `fastboot getvar unlocked` / `oem device-info` to probe state.
3. Attempt TCL's own unlock flow (highest chance on this OEM device) — do **not** blind-`fastboot flashing unlock` on MediaTek/GKI.
4. If unlocked: Magisk patch path — extract device `init_boot` image → patch via `magisk-patch` → `fastboot flash init_boot`. Then:
   - Magisk active ✓
   - `magctl gotoshell` root ✓
   - NetHunter full ✓

**If unlock is blocked → pivot to Rootless NetHunter (Section 7) — no root, still useful Kali.**

---

## 6. Kernel / OTA update pipeline `[POST-UNLOCK]` (safe, from the laptop)

> **kernel.org is out of scope for this device.** MT6835 needs a vendor/GKI kernel with a matching `vendor_dlkm` (radio/Wi-Fi/GPU blobs). Upstream kernel.org builds won't boot this phone.

Safe laptop-driven update pipeline (once rooted):
```bash
# 1. Fetch T704V firmware/OTA from TCL (repo/URL kept in phonekit/config)
# 2. Extract the boot image:
#      cp <fw>/init_boot.img.img  ./  (or the A/B slot image the OTA ships)
# 3. Magisk-patch (post-unlock) then flash:
adb reboot bootloader
fastboot flash init_boot ./init_boot.img
fastboot reboot
# 4. Reapply Magisk module spin-up in /data/adb
```
- **Two slots exist** (`boot_a`/`boot_b`, `init_boot_a/b`) → keep one contiguous; flash the inactive slot first so a bad image is survivable.
- Guard script `flash-safe` (planned) will check: bootloader unlocked var, slot parity, decompressed image signature, then flash. **It refuses to run now.**

---

## 7. Kali NetHunter — realistic expectations

- NetHunter officially supports Pixel/Nexus/OnePlus/Samsung/Xiaomi/LG, **not TCL**. So full NetHunter *device support* won't exist for this phone.
- **Rootless NetHunter** (works before unlock, `[LIVE]`): NetHunter rootless chroot + Termux. That's exactly what `kali-boot` + `proot-distro kali` gives: your Kali profile starting on boot in a tmux session, reachable from the laptop over the bridge (Section 3), with Kali tools.
- **Full NetHunter** `[POST-UNLOCK]`: only after root (Section 5/6). It'll be the generic flavor; kernel-feature NetHunter (e.g., wireless chipset integration) is limited on MT6835 regardless.

---

## 8. Raspberry Pi — model needed

Kali on the Pi is separate ARM work (`rpi-imager`/`kali-arm`). The Pi isn't in this phonekit plan yet; tell me the model to add a Pi playbook.

---

## 9. Rollback / uninstall / safety

- Undo the tunnel: Ctrl-C on `adbr`; `adb reverse --remove tcp:5022`; `adb disconnect --all`.
- Termux uninstall: phone Settings → Apps → Termux → Uninstall (wipes its data dir).
- Any post-unlock flash revert: always re-flash the *other* (healthy) slot, then `fastboot reboot`.

---

## 10. Multi-source Termux package policy (per your ask)

- **Stable base:** F-Droid APK (upstream) — replace the stale `googleplay.2026.06.21`.
- **Betas / pre-releases:** your `DOINKPATH` forks (termux-app/packages/proot-distro/x11) via GH Actions, cloned on the phone, `pkg build` / `termux-create-package`.
- Keep `pkg` pointing at upstream main/x11/root; use your forks only for anything you modify.

---

### Checklist to hand off
- [ ] `adbw` connects wireless
- [ ] `setup-termux.sh` run on phone
- [ ] `ssh2termux` logs in (both ways working)
- [ ] `magctl status` clean
- [ ] `kali-boot` shows Kali up on boot
- [ ] (deferred) unlock → Magisk → NetHunter
- [ ] (deferred) kernel/OTA pipeline
---

## 11. Full dev stack on the phone `[LIVE]` — languages, SDKs, JDKs, toolchains

`setup-termux.sh` provisions (flags: `NDK=1`, `JDK=21`, `ML=1`, `DEBIAN=1`, `SKIP_HEAVY=1`):

| Layer | Packages |
|---|---|
| Compilers / build | clang, lld, mold, gcc-family via clang, make, cmake, ninja, binutils, pkg-config, autoconf/automake, bison/flex, gdb, strace |
| Languages | Python (+pip, numpy), Node LTS, Ruby, PHP, Perl, Lua 5.4, Go, Rust |
| JDK / JRE / OpenJDK | `openjdk-17` (default) or `openjdk-21` (`JDK=21`) — includes JRE via jre dir |
| Android SDK/NDK | `android-tools` (adb/fastboot), `android-ndk` + `ndk-multilib` with `NDK=1` (aarch64/armv7/x86_64/i686 cross) |
| Servers | openssh (sshd), nginx, sqlite, rsync, aria2 |
| Crypto / encode / decode | openssl-tool, gnupg, age, jq, xxd, base64/coreutils, p7zip/zip/unzip, qrencode |
| AI / Machine Learning | numpy always; `ML=1` adds scipy, pandas, matplotlib, torch/torchvision (aarch64 wheels; torch optional/long) |

**Architecture matrix:** phone = aarch64 (MT6835). Termux repos serve aarch64/arm/x86_64/i686. NDK = cross toolchains for all four ABIs. Go/Rust cross-compile from laptop→phone targets (`GOARCH=arm64`, `--target aarch64-linux-android`).

---

## 12. Server lifecycle — `phonesrv` `[LIVE]` (rootless)

Run inside Termux. Modes:

- **`phonesrv live`** — stay live: `termux-wake-lock`, sshd, tmux `kali` session, prints listeners + battery. This is the "always-on mobile server" state (screen off OK).
- **`phonesrv dark`** — go dark: kills sshd, releases wake-lock, verifies zero listeners. `AIRPLANE=1 ./phonesrv dark` also cuts Wi-Fi/cellular radios via `settings put global airplane_mode_on` — requires the one-time laptop grant: **`./grant-perms`** (`pm grant com.termux android.permission.WRITE_SECURE_SETTINGS`, reversible with `pm revoke`).
- **`phonesrv off`** — graceful: stop services, `sync`, then power-off. If Termux can't (`reboot -p` needs elevated shell), run from laptop: `adb shell reboot -p`.
- **`phonesrv watch`** — resilient watchdog: loop restarts sshd/tmux if they die, re-locks wake, heartbeats to `~/.phonesrv/phonesrv.log`. Designed to **withstand connection loss**: listeners keep serving locally and come straight back when the link returns.
- **`phonesrv status`** — uptime, listeners, tmux, battery, toolchain versions, radio state.
- **`phonesrv airplane-off`** — restores radios after DARK.

**Laptop-side resilience — `srvwatch`** `[LIVE]`: loop that repairs the ADB link (USB → `PHONE_IP:5555` → Bluetooth bnep0), re-establishes the `adb reverse` tunnel, exponential backoff on loss (`SRVWATCH_INTERVAL=15`, `PHONE_IP=x.x.x.x ./srvwatch`, `--once` for cron). Pair `srvwatch` (laptop) + `phonesrv watch` (phone) = connection-loss-proof stack.

**Boot persistence:** `kali-boot` in `~/.termux/boot/` (Termux:Boot add-on) auto-starts sshd + tmux Kali on phone boot.

---

## 13. Source lists — Linux / GNU / Termux (+ FreeBSD reality) `[LIVE]`

- `./repos termux` — Termux `main + x11 + root + science + game + unstable` (`$PREFIX/etc/apt/sources.list.d/`)
- `./repos kali` — inside the kali proot: `kali-rolling main contrib non-free non-free-firmware` (GNU/Kali)
- `./repos debian` (`DEBIAN=1`) — Debian trixie GNU repos in a proot distro
- `./repos show` / `./repos verify` — inspect current sources / apt policy
- Reference files in `sources/`: `kali-rolling.list`, `debian-gnu.list`, `termux-main.sources`

**FreeBSD:** cannot run natively on this Android device (kernel mismatch, locked bootloader). Realistic paths: FreeBSD VM on the laptop, or FreeBSD on a Pi/spare box reachable over the network from Termux. Reference config kept at `sources/freebsd-pkg.conf.REFERENCE`.

**DLLs:** Windows PE `.dll` files don't load on aarch64 Android. Native shared objects are ELF `.so` (`clang -shared`, `$PREFIX/lib`). Windows-targeting builds → mingw-w64 cross-compile from the laptop; experimental Box64+Wine exists but is out of scope. See `sources/dll-and-so.REFERENCE`.
- **Central principle:** one control surface (`magctl`), three entry points (laptop ADB, Termux SSH, phone GUI) — all converge on Magisk.