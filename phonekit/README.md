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

## Status label
- Running `magctl status` with a **locked** bootloader will report root/Magisk unavailable and direct you to `playbook.md` — mutating actions are intentionally deferred.

See **[playbook.md](./playbook.md)** for the full document.