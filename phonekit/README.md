# phonekit — ADB ⇄ Termux ⇄ Magisk control plane

Safe, KDE-free tooling to link your **TCL 50 XL NXTPAPER 5G (T704V / Ruby_TF, Android 15, MediaTek MT6835)** to your Kali laptop.

> **Scope today:** safe wiring only — no bootloader unlock, no root, no flashing.
> **KDE:** this phone/IPv4 tooling has **zero KDE** dependencies; everything is ADB/SSH/tmux/CLI.

## Quick start
```bash
# on the Kali laptop
./adbw                      # USB -> wireless ADB to the phone
./ssh2termux                # ssh into Termux over adb reverse tunnel
./magctl status             # read-only probe of Magisk/root/boot state (safe now)
```

## Files
| Script | Purpose |
|---|---|
| `adbw` | wire USB/wireless/BT ADB to the phone |
| `adbr` | `adb reverse tcp` bridge: laptop ↔ Termux sshd |
| `ssh2termux` | drop into Termux over the bridge (key auth) |
| `magctl` | Magisk control wrapper — read-only now, full actions post-unlock |
| `kali-boot` | rootless Kali (proot) + sshd + tmux on boot in Termux |
| `setup-termux.sh` | one-shot Termux provisioning (run on the phone) |
| `playbook.md` | full setup/rollback/NetHunter/kernel docs |

## The both-ways link (how it works)
```
laptop  --adb(USB/wifi)-->  phone (Android Debug Bridge)
laptop  --ssh--tunnel-->    phone Termux sshd      (adb reverse tcp:5022:8022)
laptop  <--ssh--           phone Termux            (Termux ssh's back to laptop with shared key)
```

## The phone as a mobile server — `phonesrv` (run inside Termux)
| Mode | What it does |
|---|---|
| `phonesrv live` | **Stay live**: wake-lock, sshd, tmux Kali session, shows listeners + battery |
| `phonesrv dark` | **Go dark**: kills all listeners, releases wake-lock; `AIRPLANE=1` also cuts radios (needs `./grant-perms` once from laptop) |
| `phonesrv off` | **Turn off**: graceful stop, sync, power-off (or use `adb shell reboot -p` from laptop) |
| `phonesrv watch` | **Resilient**: watchdog loop — restarts sshd/tmux if they die, keeps wake-lock, heartbeats to `~/.phonesrv/phonesrv.log`; survives connection loss by serving locally |
| `phonesrv status` | listeners, battery, toolchain versions, radio state |

Laptop-side counterpart: `./srvwatch` — auto-reconnects ADB over USB/BT/Wi-Fi, re-establishes the reverse tunnel, backs off on loss (`--once` for cron).

## Full-stack provisioning (`setup-termux.sh` flags)
`NDK=1` Android NDK · `JDK=21` · `ML=1` torch/scipy/pandas · `DEBIAN=1` Debian proot · `LAPTOP_KEY='<pub>'`
Installs: clang/gcc toolchain, cmake/ninja, Python+pip+numpy, Node LTS, Ruby, PHP, Perl, Lua, Go, Rust, **OpenJDK 17/21**, android-tools, nginx/openssh, openssl/gnupg/age, and ends with a **toolchain compliance report**.

## Repositories (`repos` + `sources/`)
- `repos termux` — main + x11 + root + science + game + unstable
- `repos kali` — GNU/Kali `kali-rolling main contrib non-free non-free-firmware` inside the proot chroot
- `repos debian` — Debian trixie GNU repos in a Debian proot
- `sources/` — reference files: `kali-rolling.list`, `debian-gnu.list`, `termux-main.sources`, plus reality-notes `freebsd-pkg.conf.REFERENCE` and `dll-and-so.REFERENCE` (FreeBSD can't run natively on this Android device — VM/Pi path documented; Windows `.dll` ≠ Linux `.so` — NDK/`clang -shared` path documented).

## Architecture note
Phone is **aarch64** (MT6835); laptop x86_64. Termux covers aarch64/arm/x86_64/i686; the NDK cross-compiles all four; proot gives Kali/Debian GNU userland on the phone; Go/Rust cross-compile from either side.

See **[playbook.md](./playbook.md)** for the full document.