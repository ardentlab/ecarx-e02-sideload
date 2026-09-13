# Sideload for ECarX E02 Android 9 — Live Deploy over UART

Flash `lk.bin` and `boot.bin` once — everything after that is done on the running system over UART. Every command is copy-paste ready.

**Brand:** Proton · **IHU:** ECarX E02 · **Android:** 9 · **Method:** UART + USB drive · **Flash:** lk + boot only

---

## Contents

- [Step 0 — Overview](#step-0--overview)
- [Step 1 — Prerequisites](#step-1--prerequisites)
- [Step 2 — Config & Folders](#step-2--config--folders)
- [Step 3 — Collect Files](#step-3--collect-files)
- [Step 4 — Patch lk.bin](#step-4--patch-lkbin)
- [Step 5 — Patch boot.bin (Magisk)](#step-5--patch-bootbin-magisk)
- [Step 6 — Backup, Unlock & Flash](#step-6--backup-unlock--flash)
- [Step 7 — Connect UART](#step-7--connect-uart)
- [Step 8 — Get Root](#step-8--get-root)
- [Step 9 — Deploy services.jar](#step-9--deploy-servicesjar)
- [Step 10 — Reboot & Test](#step-10--reboot--test)
- [Step 11 — Stabilise Magisk](#step-11--stabilise-magisk)
- [Step 12 — File Manager](#step-12--file-manager)
- [Step 13 — SwipeBack](#step-13--swipeback)
- [Fix Fast](#fix-fast)
- [Project Notes](#project-notes)

---

## Step 0 — Overview

`Read First`

This guide shows how to unlock APK sideloading on an ECarX E02 head unit (Proton X50 RC, S70, X90 — Android 9) by flashing **two small files once**, then doing everything else on the running system over UART.

> [!TIP]
> **What gets flashed:** Two small files, one time — `lk.bin` (~1MB) and `boot.bin` (~32MB). That is the whole flashing stage, and the writing itself takes about five minutes. What takes longer is the full partition backup in [6.2](#62--back-up-every-partition-first) that comes before it — that is your only way back if anything goes wrong, so it is not the place to save time. Everything after the flash happens directly on the running system over UART, so deploying `services.jar` takes a few seconds.

**What actually blocks installs:**

Stock firmware ships `/system/framework/services.jar` as a **183-byte stub** — an empty file. The real one is about 3.7MB and holds a real `classes.dex`. Because of that stub, `pm install` is blocked completely. Replace the file with the real one and the block disappears. That is the whole point of this method; every other step just gets you there safely.

**The full flow:**

**Reference** — From nothing to installing APKs on your own
```text
Phase 1  Prepare files   → patch lk.bin, patch boot.bin (Magisk), get services.jar
Phase 2  Back up & flash → MTKClient: dump partitions, unlock, write lk & boot
Phase 3  Live deploy     → UART: root → remount rw → swap services.jar    ← 2 min
Phase 4  Finish up       → Magisk, File Manager, SwipeBack
```

> [!WARNING]
> **Where does root come from?** Not from Magisk. ECarX leaves a binary at `/system/xbin/su` in stock firmware — setuid root, group shell. Since the UART shell runs as uid `shell`, that binary hands you root directly. Magisk does something else entirely: it disables dm-verity so `/system` becomes **writable**. Two separate things, and you need both.

> [!CAUTION]
> **Risk:** This process unlocks and modifies a car head unit. A wrong flash can brick the IHU. Follow every step in order, don't skip. All original files are `renamed`, never deleted — so if it bootloops you can recover over UART. Keep the `ORI` folder safe.

## Step 1 — Prerequisites

`Hardware + Software`

### 1.1 — Hardware

| Item | Notes |
|---|---|
| CH340G USB-to-TTL adapter | Must be set to **3.3V**, not 5V. 5V will permanently damage the IHU UART pins. |
| Micro JST GH 6-pin cable, single connector | Connector on one end, bare wire ends on the other. GH series is 1.25 mm pitch — a 6-pin cable from any other JST series will not fit the IHU port. Full pinout is in [Step 6.1](#step-6--backup-unlock--flash). **The three wires you are not actively using must be insulated** — see [Step 7.1](#step-7--connect-uart). |
| Heat shrink tube + heat gun | To cover the bare ends of the blue, green and red wires whenever you are not shorting them for BROM. Electrical tape works too — but they must not be left bare. [Step 7.1](#step-7--connect-uart). |
| USB A-to-A cable (male-to-male) | For MTKClient during flashing. Must be a data cable, not charge-only. |
| USB drive, **FAT32** | To move files onto the IHU. exFAT and NTFS are not read. |
| Android phone | Android 10 or newer, to patch boot.bin with the Magisk app. |
| Windows PC + Ubuntu WSL | WSL is used to run the lk.bin patch script. |

![CH340G USB-to-TTL adapter seen from above, pin header labelled 5V, 3V3, TXD, RXD, GND](../images/ch340g-adapter-front.jpg)

*CH340G adapter. The pin header is labelled `5V`, `3V3`, `TXD`, `RXD`, `GND`.*

![The same CH340G adapter at an angle, showing the yellow voltage-select jumper](../images/ch340g-adapter-angled.jpg)

*The yellow jumper selects the voltage. It must sit on **3V3**, never 5V.*

![Micro JST GH 6-pin cable with the white connector on the right and bare tinned wire ends](../images/jst-6pin-cable-connector.jpg)

*Micro JST GH 6-pin cable, single connector. The connector plugs into the IHU; the bare ends go to the adapter.*

![A plain USB-A flash drive photographed from above](../images/usb-flash-drive-top.jpg)

*Any small USB-A drive works, as long as it is formatted **FAT32**. It carries the files onto the IHU in [Step 9](#step-9--deploy-servicesjar).*

> [!CAUTION]
> **Before you buy anything else, get heat shrink or electrical tape.** The Micro JST GH cable arrives with six bare tinned ends. Three (yellow, black, white) are your permanent UART wires; the other three — blue, green and red — you short only briefly in [Step 6](#step-6--backup-unlock--flash) for BROM, and the rest of the time they sit bare and live next to your working wires, with red carrying **3.3V from the IHU** whenever the unit is powered. Cover them whenever you are not deliberately shorting them. Full detail in [Step 7.1](#step-7--connect-uart).

### 1.2 — Software on the PC

| Software | Used for |
|---|---|
| MTKClient | Unlock the bootloader and flash lk.bin & boot.bin. Use the original [bkerler/mtkclient](https://github.com/bkerler/mtkclient) installed from source at `C:\mtkclient`. The [MTKClient Windows install guide](./mtkclient-windows-install.md) walks the whole setup, including the GUI bug that otherwise loops "Handshake failed, retrying" forever on an E02. |
| UsbDk + WinFsp | So Windows can see the IHU in BROM mode. UsbDk is the one that does the work — [daynix/UsbDk releases](https://github.com/daynix/UsbDk/releases), file `UsbDk_1.0.22_x64.msi`. WinFsp ([winfsp.dev/rel](https://winfsp.dev/rel/)) is only needed for MTKClient's optional filesystem mount, which this guide never uses — you can skip it. |
| Python 3 + Git | MTKClient dependencies. [python.org/downloads](https://www.python.org/downloads/) and [git-scm.com/download/win](https://git-scm.com/download/win). Tick **"Add python.exe to PATH"** on the first installer screen — miss it and `python` sends you to the Microsoft Store instead of running. |
| PuTTY 64-bit | Serial terminal for UART. This is where most of the work happens. Take `putty-64bit-*-installer.msi` from [the official PuTTY page](https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html). |
| CH340G driver | So the COM port shows up in Device Manager. From the chip maker, WCH: [CH341SER driver](https://www.wch-ic.com/downloads/CH341SER_EXE.html) — the same package covers the CH340/CH340G. |
| Ubuntu WSL | Install with `wsl --install` in PowerShell as Administrator — [Microsoft's reference](https://learn.microsoft.com/en-us/windows/wsl/install). |

### 1.3 — Install WSL & its tools

First install Ubuntu WSL itself. Run this in **PowerShell as Administrator**, then reboot. Skip it if `wsl -l -v` already lists an Ubuntu distro.

**PowerShell** — Install Ubuntu WSL
```text
wsl --install
```

Then open Ubuntu and install the one package this guide needs inside WSL:

**WSL** — Install required packages
```bash
sudo apt-get update
sudo apt-get install -y python3
```

### 1.4 — Files you need

| File | Size | Where it comes from |
|---|---|---|
| `lk.bin` | ~1MB | Original firmware from your own unit. **Must match your model and version.** |
| `boot.bin` | ~32MB | Original firmware from your own unit. |
| `services.jar` (modified) | ~3.7MB | Built from your own unit's firmware — see the [Build services.jar guide](./build-services-jar.md). The single most important file in the whole guide. |
| `Magisk.apk` | ~11MB | Official releases only — [github.com/topjohnwu/Magisk/releases](https://github.com/topjohnwu/Magisk/releases). Take the `Magisk-vXX.X.apk` asset from the newest release — never a repackaged copy from a mirror site. |
| `Files.apk` | — | File Manager+ (`com.alphainventor.filemanager`) from [APKPure](https://apkpure.com/file-manager/com.alphainventor.filemanager). Take an **arm64-v8a** build that still supports Android 9. |
| `SwipeBack.apk` | ~1MB | Optional. Swipe-back button (`ace.jun.simpleback`) from [APKPure](https://apkpure.com/swipe-back/ace.jun.simpleback). |

> [!TIP]
> **You need a modified `services.jar` before you start.** You build it yourself from your own unit's firmware with the [Build services.jar guide](./build-services-jar.md). Without this file you cannot start at all.

## Step 2 — Config & Folders

**WSL** — Set your paths once, at the top of the session

```bash
# Your Windows username — the folder name under C:\Users\
export WINUSER="your-windows-username"

# Pick ONE of these two, depending on whether your Desktop syncs to OneDrive
export DESKTOP="/mnt/c/Users/$WINUSER/OneDrive/Desktop"
# export DESKTOP="/mnt/c/Users/$WINUSER/Desktop"

ls "$DESKTOP"        # sanity check: this must list your Desktop
```

Every command below uses `$DESKTOP`, so this is the only place you type your
username. Nothing else needs editing.

> [!WARNING]
> These variables live only in the shell you set them in. Close the terminal,
> or open a second one, and they are gone — run the block above again before
> continuing, or the commands will write to the wrong place.

`WSL Ubuntu`

### 2.1 — Find your Windows username

**WSL** — List Windows users
```bash
ls /mnt/c/Users/
```

Ignore `All Users`, `Default`, `Public` and `desktop.ini` — those are Windows system entries. Whatever is left is your username.

> [!TIP]
> If OneDrive sync is ON, your Desktop lives at `C:\Users\NAME\OneDrive\Desktop`. If it is OFF, it is at `C:\Users\NAME\Desktop`. Pick whichever one actually holds your files — get this wrong and every command below will say "No such file or directory".

### 2.2 — Set the BASE path

Run this every time you open a new WSL session. `export` does not survive closing the terminal, and the patch script in Step 4 reads this variable.

**WSL** — Set BASE
```bash
export BASE="$DESKTOP/IHU_DEPLOY"
```

### 2.3 — Create the folders

**WSL** — Create folder structure
```bash
mkdir -p "$BASE/ORI"
mkdir -p "$BASE/MOD"
echo "Folders created:"
ls "$BASE"
```

> [!WARNING]
> **Never modify anything inside `ORI`.** All patching is done on copies in `MOD`. If something goes wrong, `ORI` is your way back.

## Step 3 — Collect Files

`WSL Ubuntu`

### 3.1 — Put lk.bin and boot.bin into ORI

Put your unit's original `lk.bin` and `boot.bin` directly on the Desktop, named exactly like that, then run:

**WSL** — Copy originals into ORI
```bash
cp "$DESKTOP/lk.bin"   "$BASE/ORI/lk.bin"
cp "$DESKTOP/boot.bin" "$BASE/ORI/boot.bin"
ls -lh "$BASE/ORI/"
```

> [!CAUTION]
> **These must match your exact model and firmware version.** Flashing an `lk.bin` from another model will brick the IHU. If you keep several firmware dumps around, double-check the pair you copy really belongs to your unit.

### 3.2 — Put services.jar into MOD

Take the modified `services.jar` you built yourself (see the [Build services.jar guide](./build-services-jar.md)), drop it on the Desktop with exactly that name, then run:

**WSL** — Copy services.jar into MOD
```bash
cp "$DESKTOP/services.jar" "$BASE/MOD/services.jar"
ls -lh "$BASE/MOD/services.jar"
```

> [!TIP]
> **You should see something like this:** **Output** Expected output -rwxrwxrwx 1 user user 3.7M ... /mnt/c/.../IHU_DEPLOY/MOD/services.jar What matters is that it is about 3.7MB — definitely not 183 bytes (the stub). Your exact size will differ slightly from the example above.

> [!CAUTION]
> **If the size is 183 bytes:** that is the stub, not the real file. The real one is about 3.7MB and contains a `classes.dex` inside. Do not continue with the stub — `pm install` will stay blocked.

> [!WARNING]
> **Built the jar yourself?** Confirm it is `dex 039`: `unzip -p services.jar classes.dex | head -c 8 | xxd` must read `dex 039`. A `dex 035` build loads and boots but leaves installs blocked — rebuild it with `smali a -a 28` (see the Build guide).

## Step 4 — Patch lk.bin

`WSL Ubuntu`

After the bootloader is unlocked, the IHU shows an **orange state** warning screen on every boot. This patch removes it for good. The script finds the offset by itself — nothing to edit.

> [!WARNING]
> **How it works:** The script scans `lk.bin` for the byte pattern `0E 4B 7B 44`, then confirms the right one by checking for the ARM Thumb function prologue `08 B5` (`PUSH {r3,lr}`) just before it. Those four bytes are replaced with `00 20 08 BD` (`MOVS r0,#0 / POP {r3,pc}`), which makes the check function return immediately.

> [!TIP]
> **Confirmed offsets:** Model Firmware Offset Proton X50 RC V144 `0x0003B392` Proton S70 V333 `0x0003C0FE` Proton X90 V735 `0x0003C0FE` The offset differs per model — that is normal. The script handles it.

### 4.1 — Copy lk.bin into MOD

**WSL** — Copy ORI → MOD
```bash
cp "$BASE/ORI/lk.bin" "$BASE/MOD/lk.bin"
```

### 4.2 — Run the patch script

> [!WARNING]
> **Make sure `BASE` is set** in this terminal (Step 2.2). Without it the script fails with `KeyError: 'BASE'`.

**WSL** — Auto-detect offset & patch
```bash
echo aW1wb3J0IHN5cywgb3MKYmFzZSA9IG9zLmVudmlyb25bIkJBU0UiXQpvcmkgPSBvcGVuKGJhc2UgKyAiL09SSS9say5iaW4iLCAicmIiKS5yZWFkKCkKbW9kX3BhdGggPSBiYXNlICsgIi9NT0QvbGsuYmluIgpQQVRURVJOICA9IGJ5dGVzKFsweDBFLCAweDRCLCAweDdCLCAweDQ0XSkKUEFUQ0ggICAgPSBieXRlcyhbMHgwMCwgMHgyMCwgMHgwOCwgMHhCRF0pClBST0xPR1VFID0gYnl0ZXMoWzB4MDgsIDB4QjVdKQpmb3VuZCA9IE5vbmUKcG9zID0gMAp3aGlsZSBUcnVlOgogICAgaWR4ID0gb3JpLmZpbmQoUEFUVEVSTiwgcG9zKQogICAgaWYgaWR4ID09IC0xOgogICAgICAgIGJyZWFrCiAgICBpZiBQUk9MT0dVRSBpbiBvcmlbbWF4KDAsIGlkeCAtIDE2KTppZHhdOgogICAgICAgIGZvdW5kID0gaWR4CiAgICAgICAgYnJlYWsKICAgIHBvcyA9IGlkeCArIDEKaWYgZm91bmQgaXMgTm9uZToKICAgIHByaW50KCJFUlJPUjogUGF0dGVybiBub3QgZm91bmQuIFRoaXMgZmlybXdhcmUgdmVyc2lvbiBtYXkgbm90IGJlIHN1cHBvcnRlZC4iKQogICAgcHJpbnQoIiAgICAgICBEbyBub3QgY29udGludWUuIE1ha2Ugc3VyZSBsay5iaW4gY2FtZSBmcm9tIHlvdXIgb3duIHVuaXQuIikKICAgIHN5cy5leGl0KDEpCnByaW50KCJbK10gRm91bmQgYXQgb2Zmc2V0IDogMHglMDhYIChkZWNpbWFsOiAlZCkiICUgKGZvdW5kLCBmb3VuZCkpCnByaW50KCJbK10gT3JpZ2luYWwgYnl0ZXMgIDogIiArIG9yaVtmb3VuZDpmb3VuZCs0XS5oZXgoIiAiKS51cHBlcigpKQp3aXRoIG9wZW4obW9kX3BhdGgsICJyK2IiKSBhcyBmOgogICAgZi5zZWVrKGZvdW5kKQogICAgY3VyID0gZi5yZWFkKDQpCiAgICBpZiBjdXIgPT0gUEFUQ0g6CiAgICAgICAgcHJpbnQoIlshXSBBbHJlYWR5IHBhdGNoZWQgLSBub3RoaW5nIGNoYW5nZWQuIikKICAgIGVsaWYgY3VyICE9IFBBVFRFUk46CiAgICAgICAgcHJpbnQoIkVSUk9SOiBVbmV4cGVjdGVkIGJ5dGVzIGluIE1PRCBmaWxlOiAiICsgY3VyLmhleCgiICIpLnVwcGVyKCkpCiAgICAgICAgcHJpbnQoIiAgICAgICBEZWxldGUgTU9EL2xrLmJpbiwgY29weSBpdCBhZ2FpbiBmcm9tIE9SSSwgdGhlbiByZXRyeS4iKQogICAgICAgIHN5cy5leGl0KDEpCiAgICBlbHNlOgogICAgICAgIGYuc2Vlayhmb3VuZCkKICAgICAgICBmLndyaXRlKFBBVENIKQogICAgICAgIHByaW50KCJbK10gUGF0Y2ggd3JpdHRlbiAgIDogIiArIFBBVENILmhleCgiICIpLnVwcGVyKCkpCndpdGggb3Blbihtb2RfcGF0aCwgInJiIikgYXMgZjoKICAgIGYuc2Vlayhmb3VuZCkKICAgIHJlcyA9IGYucmVhZCg0KQppZiByZXMgPT0gUEFUQ0g6CiAgICBwcmludCgiIikKICAgIHByaW50KCJbT0tdIFBBVENIIFNVQ0NFU1NGVUwiKQogICAgcHJpbnQoIiAgICAgT2Zmc2V0ICAgOiAweCUwOFgiICUgZm91bmQpCiAgICBwcmludCgiICAgICBCeXRlcyAgICA6ICIgKyByZXMuaGV4KCIgIikudXBwZXIoKSkKICAgIHByaW50KCIgICAgIE9SSSBmaWxlIDogdW50b3VjaGVkIikKZWxzZToKICAgIHByaW50KCJFUlJPUjogVmVyaWZpY2F0aW9uIGZhaWxlZCAtIGJ5dGVzIGFmdGVyIHdyaXRlOiAiICsgcmVzLmhleCgiICIpLnVwcGVyKCkpCiAgICBzeXMuZXhpdCgxKQo= | base64 -d | python3
```

> [!TIP]
> **You should see something like this:** **Output** Example — X50 RC V144 [+] Found at offset : 0x0003B392 (decimal: 242578) [+] Original bytes : 0E 4B 7B 44 [+] Patch written : 00 20 08 BD [OK] PATCH SUCCESSFUL Offset : 0x0003B392 Bytes : 00 20 08 BD ORI file : untouched The line that matters is `[OK] PATCH SUCCESSFUL`.

> [!CAUTION]
> **If it says "Pattern not found":** stop. Either your firmware version is not confirmed yet, or that `lk.bin` did not come from your unit. Do not continue.

## Step 5 — Patch boot.bin (Magisk)

`Android Phone`

Magisk gets in by patching the boot image with the Magisk app on an Android phone. This is what disables dm-verity — without it, `/system` will never become writable, even with root.

### 5.1 — Send boot.bin to the phone

- Connect the phone to the PC, set USB mode to **File Transfer (MTP)**
- Copy `ORI/boot.bin` into the phone's `Downloads` folder

### 5.2 — Patch it in the Magisk app

- Open **Magisk** → tap **Install** next to Magisk at the top

> [!CAUTION]
> **An Options screen appears here — before you tap Next:** Make sure `Preserve AVB 2.0 / dm-verity` is **NOT ticked**. Leave it ticked and `/system` will refuse to remount rw, and you will get stuck at Step 8.

- Tap **Next** → **Select and Patch a File**
- Go to **Downloads**, pick `boot.bin`
- Tap **LET'S GO** and wait for it to finish
- Magisk saves the result as `magisk_patched_XXXXX.img` in Downloads

### 5.3 — Bring it back to the PC

Copy `magisk_patched_XXXXX.img` to the Desktop, then find its exact filename:

**WSL** — Find the patched filename
```bash
ls "$DESKTOP/" | grep magisk_patched
```

### 5.4 — Enter that filename here

### 5.5 — Copy it in as MOD/boot.bin

**WSL** — Copy & rename
```bash
cp "$DESKTOP/magisk_patched_XXXXX.img" "$BASE/MOD/boot.bin"
ls -lh "$BASE/MOD/"
```

> [!TIP]
> Renaming `.img` to `.bin` is completely safe — the extension is only a label, the contents do not change. Your `MOD` folder should now hold `lk.bin` (~1MB), `boot.bin` (~32MB) and `services.jar` (~3.7MB).

## Step 6 — Backup, Unlock & Flash

`MTKClient`

This is the only time you use MTKClient. Everything after this happens over UART. If it is not installed yet, set it up first with the [MTKClient Windows install guide](./mtkclient-windows-install.md) and come back once its partition list loads.

> [!CAUTION]
> **Power must stay stable.** Never let the IHU lose power during a BROM operation. Also, unlocking the bootloader **wipes userdata** — settings and Bluetooth pairings are gone. That is expected.

### 6.1 — Enter BROM mode

![Side panel of the ECarX E02 chassis with the Micro JST GH port low down, next to a red TAP marking](../images/jst-port-location.jpg)

*Where to look: the port sits low on the side panel of the chassis. The red **TAP** marking here is hand-written, your unit will not have it.*

![Close-up of the Micro JST GH port showing six gold pins inside a white plastic housing](../images/jst-port-closeup.jpg)

*The same port close up — six pins in a white housing. Count them against the table below before you push the connector in.*

| Pin | Colour | Function | When used |
|---|---|---|---|
| 1 | White | GND | Always |
| 2 | Blue | Recovery | Short to GND for BROM / recovery |
| 3 | Green | USB | Short to 3.3V to switch the USB port into device mode |
| 4 | Black | UART RX | Always |
| 5 | Yellow | UART TX | Always |
| 6 | Red | 3.3V | Used to short with green |

![Micro JST GH 6-pin cable with the wires fanned out, showing white, blue, yellow, green, black and red](../images/jst-6pin-cable-wires.jpg)

*The six wire colours, matching the table above: white, blue, green, black, yellow, red.*

On the JST GH cable, short **white (GND) ↔ blue (Recovery)** and **green (USB) ↔ red (3.3V)**.

- **Disconnect IHU power.** Unplug **Socket Block A — Power**, the black connector sitting lowest in the ISO stack. Pulling the socket is what guarantees a true cold boot; standby is not enough.

  ![The ISO connector block on the back of the IHU with all sockets plugged in](../images/power-socket-before.jpg)

  *The ISO connectors as they normally sit, everything still plugged in.*

  ![The same ISO connector block with a red box drawn around the black power socket at the bottom of the stack](../images/power-socket-highlighted.jpg)

  *Unplug the one in the red box: **Socket Block A — Power**, the black connector at the very bottom of the ISO stack.*

- **Make both shorts on the JST jumper.** White↔blue, and green↔red. Join them properly — twisted and tinned, or soldered. A jumper you have to pinch by hand will let go at the worst possible moment, and a short that opens mid-flash is exactly how a unit gets bricked.

  ![Micro JST GH cable with only four wires fitted, white joined to blue at one pair of ends and green joined to red at the other, bare tinned copper still showing](../images/jst-jumper-shorted.jpg)

  *The two joins made: white to blue, green to red. Yellow and black are left off the connector entirely — they are the UART pair, unused during flashing.*

  ![The same jumper with each shorted pair sealed inside its own piece of black heat shrink tubing, no copper visible](../images/jst-jumper-shorted-insulated.jpg)

  *The same jumper finished. Each join sits inside **its own** piece of heat shrink, with no copper showing anywhere. This is what it should look like before it goes near a powered unit — PVC tape works if you have no heat gun.*

- **Plug the JST jumper into the IHU port** — the one shown at the top of this step.
- **Start MTKClient** (`gui.bat` → Run as administrator) and wait until it says "Waiting for connection". The tool must be listening before the unit boots, not after.
- **Plug the POWER socket back in.**
- **Immediately plug the USB male-to-male cable**: IHU USB port → PC USB 2.0 port.

  ![A laptop connected by a USB A-to-A cable to the car's centre-console USB socket, with the gear selector in P](../images/usb-a-to-a-laptop-to-ihu.jpg)

  *The A-to-A cable running from the laptop to the car's centre-console USB socket. This is the **only** socket wired to the IHU. Every other USB port in the car is charge-only and will never enumerate, whatever cable you use.*

- MTKClient detects it and connects on its own.

> [!CAUTION]
> **Two ways to get the shorts wrong, and both cost you hardware.**
>
> - **Wrong pair.** Red is a live 3.3 V rail whenever the unit is powered. Red touching white is a dead short straight across the IHU's 3.3 V supply. There are exactly two joins on this jumper — **white↔blue** and **green↔red** — and nothing else may touch. Check the colours twice before the tube goes on, because once it is shrunk you cannot see what is underneath.
> - **Bare copper left showing.** A join you tinned but never covered will find the other pair the first time the cable shifts — and it shifts every session. Cover each join completely, past the tip, not just over the middle.
>
> Sleeve the two joins **separately**. Bundling both pairs into one lump of tape or one length of tube is precisely how white↔blue ends up touching green↔red.

### 6.2 — Back up every partition first

> [!CAUTION]
> **Do this before you erase or unlock anything. It is the most important step on this page.** ECarX does not publish firmware for these units. There is no official image to download, no vendor recovery tool, and nobody else's dump will fully do — `nvdata` and `proinfo` carry calibration and serial data unique to your board. The dump you take right now is the only original copy of your unit that will ever exist. Take it, and almost any mistake later is recoverable. Skip it, and a bad flash means a dead head unit and a trip to the dealer.

You are still connected in BROM from 6.1, so stay where you are and go to the **Read partition(s)** tab:

- Tick **Select all partitions**
- **Untick `userdata`** — the one exception, explained below
- Tick **Dump GPT** as well, so you keep the partition layout itself and not just the contents
- Click **Read partition(s)** and point it at an empty folder — `ORI_DUMP` is a good name
- Leave it alone until every partition reports done. Do not touch the USB cable, the jumper or the power while it runs

> [!WARNING]
> **Why userdata is the exception.** It is by far the largest partition on the unit — tens of gigabytes, against a few hundred megabytes for everything else combined — so reading it can take hours. It also holds nothing you need: it is your settings, accounts and Bluetooth pairings, and unlocking the bootloader in [6.4](#64--unlock-the-bootloader) wipes it anyway. Backing it up buys you nothing and costs most of an evening. Every *other* partition is small, and one of them missing is what turns a recoverable mistake into a brick.

> [!TIP]
> **Check the dump before moving on.** Open the folder and confirm the files are actually there and none of them are 0 bytes. A read that was interrupted still leaves files behind, and finding that out later — when you need them — is too late.

> [!TIP]
> **Then put the dump somewhere it cannot be lost.** Not the Desktop, not a folder you will clear out next month. A separate drive, and a second copy elsewhere if you can. The ones that matter most for recovery are `lk`, `boot`, `system`, `seccfg`, `nvdata`, `nvcfg` and `proinfo`. `system` is the largest of these by a wide margin, and it is the one you overwrite if you ever go near a modified `system.bin` — without a stock copy there is no way back from that.

### 6.3 — Erase partitions

Go to the **Erase partition(s)** tab and erase these:

- `metadata`
- `userdata`
- `md_udc` (only if it appears in the list)

> [!WARNING]
> **Erase first, unlock after.** Skipping this can leave the IHU bootlooping after the flash.

### 6.4 — Unlock the bootloader

**Flash Tools** tab → **Unlock bootloader** → wait for it to finish.

### 6.5 — Write lk.bin & boot.bin

You are still in BROM mode from the unlock, so just switch to the **Write partition(s)** tab:

- Click **Add files manually** — avoid "Select from directory", it picks the wrong file too easily
- `MOD/lk.bin` → partition `lk`
- `MOD/boot.bin` → partition `boot`
- Double-check both come from the **MOD** folder, not ORI
- Click **Write**

> [!TIP]
> Both finish in 2–5 minutes. Then shut it down **in this order**: unplug the **POWER socket first**, then the USB cable, then remove the JST jumper. **Leave the power unplugged** — that is exactly where [Step 7](#step-7--connect-uart) begins, so there is nothing to switch on yet.

> [!TIP]
> Whenever the unit does next boot, the orange state screen **will not** appear, because lk.bin is already patched. You do not need to boot it now to check — the flash either reported success in MTKClient or it did not.

> [!CAUTION]
> **Never pull the JST jumper while the unit is powered.** Red is a live 3.3 V rail, the joined ends sit millimetres apart, and a jumper being tugged out is exactly when they meet. Power off first, every time — there is no situation where the jumper needs to come out with the unit live.

> [!CAUTION]
> **If a flash fails halfway:** do not cut power. Re-enter BROM and try again. If it bootloops, flash `ORI/lk.bin` and `ORI/boot.bin` back to recover. If something worse goes wrong, the dump you took in [6.2](#62--back-up-every-partition-first) is what puts the unit back.

## Step 7 — Connect UART

`UART · PuTTY`

UART gives you a shell directly inside the IHU. From here on, **everything happens here**. No ADB needed at all.

> [!CAUTION]
> **3.3V only.** Confirm the CH340G is set to 3.3V before connecting anything. 5V will damage the IHU UART pins beyond repair.

### 7.1 — Insulate the unused wires

Port location and the full six-pin table are in [Step 6.1](#step-6--backup-unlock--flash). This section is about what to do with the three wires you are *not* using once flashing is done.

> [!TIP]
> **For the UART work you only need three wires:** yellow, black and white to the CH340G. Green, blue and red are shorted only in [Step 6](#step-6--backup-unlock--flash) for BROM; once flashing is done, keep them insulated for all the UART work below — leave the green pin un-shorted or the USB drive in [Step 9](#step-9--deploy-servicesjar) will not mount.

> [!CAUTION]
> **Insulate blue, green and red before the UART working phase. This is the highest-risk part of the hardware setup.** You short these three in [Step 6](#step-6--backup-unlock--flash) for BROM, but from here on you are in plain UART and they must not be shorted or left bare. Their ends are **bare tinned copper**, and while the unit is powered:
>
> - **Red is a live 3.3V rail.** Red touching white (GND), or touching the adapter's GND pin, is a dead short across the IHU's 3.3V supply — the worst outcome on this list.
> - **Blue is Recovery.** Blue touching GND drops the unit into BROM / recovery instead of booting normally.
> - **Green is USB mode.** Green touching red flips the USB port into device mode, and then the USB drive in [Step 9](#step-9--deploy-servicesjar) will not mount.
>
> All three ends hang loose right next to the wires you *are* using, and the cable moves every time you reach around the unit. Cover them.

**How to cover them**

| Method | How |
|---|---|
| **Heat shrink tube** (best) | Slide a ~15mm piece of 2–3mm tube over each bare end **individually**, then shrink it with a heat gun at roughly 100–150 °C, a few seconds each, turning the wire as it tightens. Adhesive-lined tube seals best. |
| No heat gun? | The barrel of a hot soldering iron held close (not touching), or a lighter held a few cm below the tube — move it constantly, never let the flame touch the tube or the wire. A hair dryer is usually not hot enough for standard polyolefin tube. |
| PVC electrical tape | Wrap each end separately, two or three turns past the tip, then fold the tip back and tape it down so nothing can poke out. |
| Self-amalgamating silicone tape | Stretch and wrap each end; it fuses to itself and leaves no adhesive residue. Good if the cable will be re-opened later. |
| Spare dupont housing | Push an empty 1-pin dupont shell or a short offcut of empty wire sleeving over each end. Fast, reversible, no heat needed. |

> [!WARNING]
> **Insulate them separately, never bundled together.** Taping the three bare ends into one lump is how you short blue to red. One cover per wire.

> [!WARNING]
> **Do not cut them off.** Blue, green and red are exactly the wires you short in [Step 6](#step-6--backup-unlock--flash) to enter BROM mode — and your recovery path if a flash ever goes wrong. Snip them and you throw that away — insulate, don't amputate.

### 7.2 — Wire it up and open PuTTY

- Make sure the IHU **POWER socket is unplugged** before wiring anything — that is **Socket Block A — Power**, the black connector sitting lowest in the ISO stack — shown in [Step 6.1](#step-6--backup-unlock--flash)
- **Check blue, green and red are still covered** — heat shrink or tape intact, no copper showing. Do this every session, not just the first one
- Yellow (TX) and black (RX) to the CH340G, white to GND
- Device Manager → Ports (COM & LPT) → find **USB-SERIAL CH340** and note the COM number
- PuTTY → Connection type: **Serial**, Speed: `921600`
- Click **Open**, then plug the IHU POWER socket back in — the boot log starts scrolling
- Wait for boot to finish, then press **Enter** once to get a prompt

![CH340G adapter from above with three jumper wires attached to the pin header](../images/ch340g-jumper-wires-top.jpg)

*Only three wires are used — yellow, black and white — on `TXD`, `RXD` and `GND`.*

![The same three jumper wires at an angle, with the pin labels readable](../images/ch340g-jumper-wires-angled.jpg)

*Angled view, so you can check each wire against its pin label.*

![CH340G adapter joined by jumper wires to the Micro JST GH 6-pin cable, ready to plug into the IHU](../images/ch340g-jst-cable-wired.jpg)

*The finished lead: adapter, three jumpers, and the JST GH cable that plugs into the IHU.*

> [!TIP]
> **The prompt should look like this:** **Output** Expected prompt console:/ $ The `$` means you are **not** root yet. That is normal — Step 8 handles it.

> [!WARNING]
> **No text at all in PuTTY?** TX and RX are probably swapped. Swap those two wires and reconnect. Also confirm the speed is exactly `921600`.

## Step 8 — Get Root

`UART · PuTTY`

This is where most people get stuck. Your root does **not** come from Magisk at this stage.

> [!TIP]
> **Why a plain `su` fails:** Once Magisk is flashed, `/sbin` comes first in PATH. Typing `su` on its own hits MagiskSU — and MagiskSU needs the Magisk app installed before it can approve the request. The app is not there yet, so it denies you with `Permission denied`. But ECarX leaves `/system/xbin/su` in stock firmware — `-rwsr-x--- root shell`. Setuid root, group shell. Your UART shell is uid 2000 (shell), so that binary hands you root with no conditions at all.

### 8.1 — Call the factory su by full path

**UART** — Get root
```bash
/system/xbin/su
```

> [!TIP]
> **The prompt should change:** **Output** Expected console:/ $ /system/xbin/su console:/ # The `#` means you have root.

### 8.2 — Remount /system as writable

**UART** — Remount rw & verify
```bash
mount -o rw,remount /system
mount | grep ' /system '
```

> [!TIP]
> **The output must contain `rw`:** **Output** Expected output /dev/block/mmcblk0p42 on /system type ext4 (rw,seclabel,relatime,...)

> [!CAUTION]
> **Still shows `ro`?** Your boot.bin was patched with `Preserve AVB 2.0 / dm-verity` ticked. Go back to Step 5, patch again with that option **unticked**, and reflash boot.

> [!WARNING]
> **Neither of these survives a reboot.** After every IHU restart you have to run `/system/xbin/su` and `mount -o rw,remount /system` again.

## Step 9 — Deploy services.jar

`UART · PuTTY`

This is the core of the method. We swap `services.jar` and clear the old cache so the system actually loads the new jar.

The jar itself is the one you staged into `$BASE/MOD/` back in [Step 3.2](#step-3--collect-files). If you landed straight on this step without one, it is built from your own unit's firmware in the [Build services.jar guide](./build-services-jar.md). A stock jar will not work, and one built against a different firmware version may not either.

> [!CAUTION]
> **Why the cache has to go:** Android loads the compiled `.odex` / `.vdex` / `.art` files, **not** the jar. Swap the jar but leave the old cache behind and the IHU keeps running the original code — your new jar just sits there unused. This is the number one reason for "I deployed it but installs are still blocked".

### 9.1 — Copy the files onto a USB drive

The drive must be **FAT32**. Create a folder called `mod` at the root of the drive and put these inside:

- `services.jar` — from `$BASE/MOD/`
- `Magisk.apk`
- `Files.apk`
- `SwipeBack.apk` (optional)

Plug the drive into the IHU USB port, then find where it mounted:

**UART** — Find the USB drive
```bash
ls -la /mnt/media_rw/
mount | grep -i vfat
```

> [!TIP]
> **It usually shows up as `usbotg-otg1`:** **Output** Expected output drwxrwx--- 5 media_rw media_rw 8192 ... usbotg-otg1 /dev/block/vold/public:8,1 on /mnt/media_rw/usbotg-otg1 type vfat (rw,...) You may also see an empty `usbotg` folder — that is a stale mount point, ignore it. The real one is whichever appears in the `mount` list.

> [!WARNING]
> **Drive not showing up?** Make sure the green pin is **not** shorted to red. While green is shorted, the IHU USB port is in device mode and will not read a drive at all.

### 9.2 — Stage the files to internal storage

Copy them inside first, because once you run `stop` the USB drive becomes unreachable.

**UART** — Stage the files
```bash
mkdir -p /data/local/tmp/mod
cp /mnt/media_rw/usbotg-otg1/mod/* /data/local/tmp/mod/
ls -lh /data/local/tmp/mod/
```

### 9.3 — Back up, swap the jar, clear the cache

> [!WARNING]
> **Every original file is `renamed`, never deleted.** If it bootloops, you go back in over UART, rename them back, reboot, done. Never use `rm` here.

Type these line by line rather than pasting the whole block — PuTTY often mangles long pastes.

**UART** — Back up the original jar
```bash
cp /system/framework/services.jar /data/local/tmp/services.jar.orig
```

**UART** — Stop the UI
```bash
stop
```

**UART** — Rename the original jar
```bash
mv /system/framework/services.jar /system/framework/services.jar.orig
```

**UART** — Copy in the new jar
```bash
cp /data/local/tmp/mod/services.jar /system/framework/services.jar
```

**UART** — Set permissions
```bash
chmod 644 /system/framework/services.jar
```

**UART** — Set owner
```bash
chown root:root /system/framework/services.jar
```

**UART** — Rename services.odex
```bash
mv /system/framework/oat/arm64/services.odex /system/framework/oat/arm64/services.odex.orig
```

**UART** — Rename services.vdex
```bash
mv /system/framework/oat/arm64/services.vdex /system/framework/oat/arm64/services.vdex.orig
```

**UART** — Rename services.art
```bash
mv /system/framework/oat/arm64/services.art /system/framework/oat/arm64/services.art.orig
```

**UART** — Check the jar
```bash
ls -lh /system/framework/services.jar
```

**UART** — Check the cache
```bash
ls -l /system/framework/oat/arm64/ | grep -i services
```

> [!WARNING]
> **After `stop`, the IHU screen freezes and stops responding.** That is normal — the UI is shut down, but UART keeps working. Don't panic and don't cut power.

> [!TIP]
> **You should see something like this:** **Output** Expected output -rw-r--r-- 1 root root 3.7M ... /system/framework/services.jar -rw-r--r-- 1 root root 503808 ... services.art.orig -rw-r--r-- 1 root root 25222088 ... services.odex.orig -rw-r--r-- 1 root root 10125680 ... services.vdex.orig The jar is now about 3.7MB (your exact size will vary slightly), and nothing ends in `.odex`, `.vdex` or `.art` any more — they all became `.orig`. That is exactly what you want.

## Step 10 — Reboot & Test

`UART · PuTTY`

**UART** — Reboot
```bash
reboot
```

> [!WARNING]
> **This first boot is slow** — it can take several minutes, because the framework is recompiling from the new jar. **Do not cut power.** It only happens once; later boots are normal again.

### 10.1 — The real test

Once it has booted, try installing Magisk. This proves whether the patch worked.

**UART** — Test pm install
```bash
/system/xbin/su
pm install -r /data/local/tmp/mod/Magisk.apk
```

> [!TIP]
> **If it says `Success`, the hard part is over.** The `pm install` block is gone. Everything left is just tidying up.

> [!CAUTION]
> **If you get an `INSTALL_FAILED_...` other than `ALREADY_EXISTS`,** or the IHU reboots the moment you install — see [Fix Fast](#fix-fast). **If `services.jar` went back to 183 bytes after the reboot,** dm-verity is still active. Go back to Step 5.

## Step 11 — Stabilise Magisk

`UART · PuTTY`

Magisk is installed now but not yet stable. Two things to sort out: let the shell use MagiskSU, and remove the factory `su` that conflicts with it.

### 11.1 — Open the Magisk app on the IHU screen

Open the app list on the IHU screen and tap the Magisk icon. It may ask for extra setup and a reboot — just follow it. For now it will show **"Abnormal state"**; that is expected, and 11.3 fixes it. Tap OK and the IHU will reboot.

### 11.2 — Let the shell use MagiskSU

When you type `su`, a superuser permission dialog pops up on the IHU screen. Tap **Grant** there before it closes. On most units it disappears far too quickly to catch, and if you miss it the request is denied. Setting the policy directly avoids the race entirely:

**UART** — Grant permanent root to shell
```bash
/system/xbin/su
magisk --sqlite "REPLACE INTO policies (uid,policy,until,logging,notification) VALUES(2000,2,0,1,1)"
magisk --sqlite "SELECT * FROM policies"
```

> [!TIP]
> **Output:** **Output** Expected output uid=2000|policy=2|until=0|logging=1|notification=1 `uid 2000` is the shell, `policy 2` means allow forever. Test it: exit, then type a plain `su` — you should get `#` straight away with no dialog.

### 11.3 — Remove the conflicting factory su

> [!CAUTION]
> **Do not do this until a plain `su` is confirmed working.** `/system/xbin/su` is your last safety net. If MagiskSU is not stable yet and you rename this binary, you lose root completely.

Run these one line at a time, not as a single paste.

**UART** — Get root
```bash
su
```

**UART** — Remount rw
```bash
mount -o rw,remount /system
```

**UART** — Rename the factory su
```bash
mv /system/xbin/su /system/xbin/su.bak
```

**UART** — Verify
```bash
ls -l /system/xbin/su*
```

After renaming, **do not reboot yet**. Test in a fresh shell first:

**UART** — Leave the root shell
```bash
exit
```

**UART** — Test MagiskSU on its own
```bash
su
```

> [!TIP]
> If you still get `#`, go ahead and `reboot`. After it comes back, the Magisk app should show **"Installed"** instead of "Abnormal state".

## Step 12 — File Manager

`UART · PuTTY`

This is what removes the need for a PC from here on. File Manager+ can install APKs straight off a USB drive on the IHU screen.

**UART** — Install & grant permission
```bash
su
pm install -r /data/local/tmp/mod/Files.apk
appops set com.alphainventor.filemanager REQUEST_INSTALL_PACKAGES allow
appops get com.alphainventor.filemanager REQUEST_INSTALL_PACKAGES
```

> [!TIP]
> **Output:** **Output** Expected output Success REQUEST_INSTALL_PACKAGES: allow

> [!WARNING]
> **Do not use `pm grant ... android.permission.INSTALL_PACKAGES`.** That command fails with a SecurityException — File Manager+ does not declare that permission in its manifest. What it actually uses is `REQUEST_INSTALL_PACKAGES`, which the `appops` line above already handles.

**Test it:** on the IHU screen, open File Manager+, browse to the USB drive, tap any APK and install. If it goes through without the IHU rebooting, **you are done**. Apps can be installed from the head unit itself now, no PC involved.

## Step 13 — SwipeBack

`Optional`

SwipeBack adds a floating button for the "back" gesture on the IHU. It runs through an Accessibility Service, so it has to be registered first.

### 13.1 — Install it

**UART** — Install SwipeBack
```bash
su
pm install -r /data/local/tmp/mod/SwipeBack.apk
```

### 13.2 — Confirm the service class name

Do not guess this name — if it is wrong, the setting is accepted but the button never appears. Ask the device instead:

**UART** — Find the real class name
```bash
pm dump ace.jun.simpleback | grep -iE 'accessibility|Service' | head -20
```

> [!TIP]
> **Output:** **Output** Expected output android.accessibilityservice.AccessibilityService: ace.jun.simpleback/.service.AccService filter ... permission android.permission.BIND_ACCESSIBILITY_SERVICE So the full name is `ace.jun.simpleback/ace.jun.simpleback.service.AccService`.

### 13.3 — Turn it on

**UART** — Register & enable accessibility
```bash
settings put secure enabled_accessibility_services ace.jun.simpleback/ace.jun.simpleback.service.AccService
settings put secure accessibility_enabled 1
settings get secure enabled_accessibility_services
```

> [!TIP]
> The button appears on screen within a few seconds. **This setting survives reboots** — no Magisk boot script needed, no need to repeat it every time.

## Fix Fast

`Troubleshoot`

| Symptom | Cause | Fix |
|---|---|---|
| `su` returns "Permission denied" | PATH picks `/sbin/su` (Magisk), and the Magisk app is not there to approve it | Use the full path: `/system/xbin/su`. That is the correct route before Magisk is set up. |
| `mount remount,rw` fails, `/system` stays `ro` | dm-verity still active — `Preserve AVB 2.0` was ticked during the Magisk patch | Patch `boot.bin` again with that option **unticked** and reflash. There is no command that works around this. |
| Jar swapped but `pm install` still blocked | The old `.odex` / `.vdex` / `.art` cache is still in place | Check with `ls /system/framework/oat/arm64/ \| grep services` — if anything is not `.orig` yet, rename it and reboot. |
| `services.jar` back to 183 bytes after reboot | dm-verity restored the original partition | Same as the `ro` issue above — repatch boot without AVB. |
| IHU bootloops after deploying the jar | Wrong jar, or the cache was only half renamed | Get into UART, run `/system/xbin/su`, remount rw, rename the `.orig` files back, then `reboot`. This is exactly why we rename instead of delete. |
| USB drive does not appear under `/mnt/media_rw/` | Green pin still shorted to red, or the drive is not FAT32 | Remove the green-red short and reboot the IHU. Format the drive as FAT32 — exFAT and NTFS are not read. |
| `ls /storage/usbotg-otg1/` — Permission denied | Not root yet; uid shell cannot read the FUSE mount | Run `/system/xbin/su` first, then use the `/mnt/media_rw/usbotg-otg1/` path. |
| Magisk shows "Abnormal state" | The factory `/system/xbin/su` conflicts with MagiskSU | Step 11.3 — rename it to `su.bak`, but only **after** a plain `su` is confirmed working. |
| "Allow USB debugging" dialog never appears / ADB stays `unauthorized` | The car launcher grabs focus and closes the dialog before you can tap it | Ignore it entirely. This method never uses ADB — everything is done over UART. |
| MTKClient does not detect the IHU | BROM not entered, driver issue, or a charge-only USB cable | Check both shorts are actually made, use a USB 2.0 (black) port, confirm the A-to-A cable carries data, and verify UsbDk is installed. Close any other MTKClient instance — two cannot share one USB device. |
| MTKClient reads the chip, then loops `Handshake failed, retrying...` | A bug in upstream `mtk_gui.py` 2.1.4 — it initialises the preloader twice, and the BROM accepts only one handshake per power-on. Your wiring is fine. | Apply the one-line patch in the [MTKClient install guide, Step 6](./mtkclient-windows-install.md#step-6--patch-the-double-init-bug). |
| lk.bin script says "Pattern not found" | Firmware version not confirmed yet, or lk.bin is not from your unit | Stop. Verify that `lk.bin` really came from your model and firmware version. |
| Orange state screen still appears after flashing | `ORI/lk.bin` was flashed instead of `MOD/lk.bin` | Confirm Step 4 printed `[OK] PATCH SUCCESSFUL`, then reflash `MOD/lk.bin` only. |
| No text at all in PuTTY | TX/RX swapped, wrong baud rate, or wrong COM port | Swap the TX and RX wires. Confirm the speed is `921600` and the COM port matches Device Manager. |
| IHU reboots instantly during `pm install` | The ECarX security watchdog flagged that APK (confirmed with Termux) | That APK cannot go in through `pm install` or File Manager. The only route is injecting it into `system.bin` before flashing. |
| File Manager+ says "parse error" | APK is not arm64-v8a, or its minSdk is too high | Download an arm64-v8a build that is compatible with Android 9 (API 28). |

## Project Notes

`Findings & Evidence`

This section is not a step — these are the investigation notes behind the guide above. Keep them as reference if you later work on another model, or want to understand why each choice was made.

### 1 — Root comes from ECarX, not Magisk

This is the single most important finding in the whole project, and it is what makes this method far shorter than people assume.

Stock ECarX firmware leaves this binary behind:

**Evidence** — ls -l /system/xbin/su — stock firmware, before any modification
```text
-rwsr-x--- 1 root shell 68400 2009-01-01 00:00 /system/xbin/su
```

The `s` in `rws` is the setuid bit. Owner `root`, group `shell` — and the UART shell runs as uid 2000, which is in the `shell` group. So this binary was built to hand root to the shell. No conditions, no app, no dialog.

The catch: once Magisk is flashed, `/sbin` comes first in PATH. A plain `su` hits MagiskSU, which denies you because there is no Magisk app installed yet to approve the request:

**Evidence** — which -a su — two binaries, two very different behaviours
```text
console:/ $ which -a su
/sbin/su              ← Magisk (symlink to ./magisk) — DENIES, exit 13
/system/xbin/su       ← ECarX factory — ACCEPTS, drops straight to #
```

Plenty of people get stuck here, because the error reads `Permission denied` — which sounds like there is no root at all, when in fact root is right there and you simply knocked on the wrong door.

### 2 — Magisk is not for root; it is for write access

This was verified directly on the unit: even before boot.bin was patched, `/system/xbin/su` already gave root on the UART shell. The only thing that failed at that point was `remount`, because dm-verity was still active.

So the real job of the Magisk patch in this method is to **disable dm-verity / AVB** so that `/system` becomes writable. That is why `Preserve AVB 2.0 / dm-verity` must stay **unticked**. Leave it ticked and you still get root, but `mount -o rw,remount` fails and anything you write reverts on the next boot.

### 3 — ecarx.policy.jar does not need to be deployed

Older guides tell you to deploy both `services.jar` and `ecarx.policy.jar`. We tested that file properly.

The modified version was compared against the original, pulled straight from `/system/framework/oat/arm64/ecarx.policy.vdex` on an X50 RC V144 unit. That vdex is in `cdex001` (CompactDex) format, so it was parsed with a custom DEX parser to compare class by class:

| Measure | ORI (from vdex) | MOD (as supplied) |
|---|---|---|
| Total classes | 3912 | 3912 |
| Total types | 6290 | 6290 |
| Classes present in only one | 0 | 0 |
| Classes with different method/field counts | **0** |  |
| Total strings | 80,536 | 80,531 |

The five strings missing from the modified copy:

**Evidence** — Strings present in ORI but absent in MOD
```text
absoluteCodePaths
acoSignature
set1
set2
~~D8{"min-api":28,"version":"v1.1.11"}
```

The last one is a D8 compiler marker — build metadata. The other four are local variable names from debug info. The modified copy adds **no new strings at all**.

> [!TIP]
> **Conclusion:** the modified `ecarx.policy.jar` is not a patched build — it is simply a **deodexed copy** of the original, and the deodex process dropped a little debug info. No classes added, no methods removed, no string constants changed.

**Limits of this check:** the actual bytecode was not compared, because CompactDex stores code items in a compressed layout that differs from standard DEX. In theory a single opcode could be changed without affecting the structure. To rule that out you would have to convert the cdex to dex first with `vdexExtractor`.

### 4 — So why was that file included at all?

The answer sits in the old guide itself, in one line:

**Reference** — From the system.bin rebuild method
```text
sudo rm -f "$OAT/ecarx.policy.odex" "$OAT/ecarx.policy.vdex"
```

It deletes the `ecarx.policy` cache too. On Android 9, all boot classpath jars are compiled together as one set, and their odex/vdex files carry checksums that reference each other. Once `services.jar` is replaced and its cache removed, that set no longer matches — so the safe move for anyone rebuilding a full image is to **deodex every jar in the set**, giving each one its full code inside the jar.

Delete the cache without supplying a jar that contains the code, and `ecarx.policy` disappears entirely and the IHU bootloops. So that file exists as a **replacement**, not as a patch.

> [!TIP]
> **This method never runs into that problem** — we only rename the `services.*` cache. `ecarx.policy.odex` and `.vdex` are left untouched, so it keeps loading from its original cache as usual. We touch only what needs touching instead of clearing everything.

### 5 — Rename, never delete

Older guides use `rm -f` to clear the cache. The 4PDA forum (post #305) uses `mv`. We follow the forum.

The difference matters when things go wrong. Rename it and if the IHU bootloops, you get in over UART, rename them back, reboot — a minute's work. Delete it and the only way back is reflashing `system.bin`, which is an hour.

### 6 — The green JST pin switches the USB port into device mode

The JST port is not only for BROM. The green pin (USB) is independent of the blue pin (Recovery):

| Pin state | Effect |
|---|---|
| Green floating | IHU USB port acts as **host** — it can read a USB drive |
| Green shorted to red (3.3V) | IHU USB port acts as a **device** — the PC sees it as an Android ADB interface |
| Blue shorted to white (GND) | Recovery / BROM |

An earlier note in this project claimed "USB port is host-mode only, USB ADB will not work on this unit". **That is not accurate.** With green shorted to red, `adb devices` does see the IHU. It just reports `unauthorized` — a separate problem.

Side effect worth remembering: while green is shorted, that USB port **cannot read a USB drive**. That is why Step 9 insists on removing the short first.

### 7 — ADB is not needed at all

A lot of time went into trying to clear `unauthorized`. Every route was closed:

| Attempt | Result |
|---|---|
| Tap the "Allow USB debugging" dialog on screen | The dialog does appear, but the car launcher grabs focus instantly. `dumpsys` shows `mLastClosingApp=...UsbDebuggingActivity` |
| Catch the dialog with an `input keyevent` loop | Failed — it closes before it can even be detected |
| Launch `UsbDebuggingActivity` manually with `am start` | Failed — `SecurityException: not exported from uid 10008` |
| Write the key into `/data/misc/adb/adb_keys` | Failed — the folder is `drwxr-s--- system shell`, group has no write permission |
| Use WiFi ADB instead of USB | Identical result — `ro.adb.secure=1`, and auth is key-based, not transport-based |

> [!TIP]
> **None of it turned out to matter.** This method completes entirely over UART. ADB is not required at any step. If you see `unauthorized`, ignore it and carry on.

### 8 — Corrections to older notes

Several claims in older guides were tested and turned out to be wrong:

| Old claim | What is actually true |
|---|---|
| SwipeBack accessibility resets on every reboot, needs a Magisk boot script | **Wrong.** The setting survives reboots. No boot script needed. |
| `pm grant ... INSTALL_PACKAGES` is required for File Manager | **No.** That command always fails — File Manager+ does not declare it. `appops REQUEST_INSTALL_PACKAGES` is enough on its own. |
| Both `services.jar` and `ecarx.policy.jar` must be deployed | **No.** `services.jar` alone is sufficient — see notes 3 and 4. |
| ADB TCP must be re-enabled over UART after every reboot | True, but **irrelevant** — this method never uses ADB. |

### 9 — Model coverage

**Shared** across all E02 Android 9 units: `/system/xbin/su`, the role of the Magisk patch, the cache rename order, the MagiskSU policy, and the File Manager steps.

**Model-specific:** `lk.bin` and `boot.bin` must come from your own unit's firmware. The orange state offset differs too — X50 RC V144 sits at `0x0003B392`, S70 V333 and X90 V735 at `0x0003C0FE`. The Step 4 script finds it automatically, so this is not a problem as long as the `lk.bin` is correct.

> [!WARNING]
> **One interesting data point:** the `services.jar` used in testing came from an **S70** build, and it ran fine on an **X50 RC V144**. So the jar appears to carry across models within the E02 Android 9 family. But that is a single case — do not assume it holds for every combination until it is tested.

### 10 — ECarX security watchdog

Some APKs are flagged by the ECarX security policy. Try to install one through `pm install` or File Manager and the IHU reboots instantly — the install never completes. Termux is a confirmed example.

For those APKs the only route is injecting them into `system.bin` before flashing. Ordinary apps (Brave, RetroArch, microG, FakeStore, ViPER4Android) install without trouble.

### 11 — Sources

This method builds on other people's work:

- **4PDA post #81** (topic 1085149) — the main ECarX guide: drivers, dumping, root, restore, installing apps
- **4PDA post #305** (topic 1068514) — the full sequence for swapping `services.jar` over UART on a Geely Atlas-PRO/Tugella E01. Note: E01 runs Android 5.1 and gives root on UART without `su` at all, so that sequence cannot be copied to E02 as-is

> [!TIP]
> **A note on `services.jar`:** it CAN be built from scratch — pull the stock `services.vdex` off your own unit and rebuild it with the [Build services.jar guide](./build-services-jar.md). The patch is three constant-return signature stubs plus one branch redirect in `installPackageLI` (the aco whitelist), assembled as `dex 039`. The 4PDA forum only noted that the file is patched to disable the system-app signature check; this project reverse-engineered the exact changes.
