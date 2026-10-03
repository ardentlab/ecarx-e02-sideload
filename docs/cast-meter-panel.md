# Cast to Meter Panel — Move Any App to the Instrument Cluster

Adds a cast button to the bottom navigation bar. Tap it to move the app on screen to the meter panel, tap it again to bring it back. The app keeps running and does not restart. Everything runs in memory, so no system file is changed and one command undoes it.

**Brand:** Proton · **IHU:** ECarX E02 · V333 · **Android:** 9 · **Method:** Xposed runtime hooks · **System files changed:** None

---

## Contents

- [Step 0 — What You Get](#step-0--what-you-get)
- [Step 1 — Prerequisites](#step-1--prerequisites)
- [Step 2 — Enable Zygisk](#step-2--enable-zygisk)
- [Step 3 — Install Vector](#step-3--install-vector)
- [Step 4 — Build the Module](#step-4--build-the-module)
- [Step 5 — Install & Activate](#step-5--install--activate)
- [Step 6 — Use & Test](#step-6--use--test)
- [Step 7 — Restore to Stock](#step-7--restore-to-stock)
- [Fix Fast](#fix-fast)
- [Project Notes](#project-notes)

---

## The Short Path — Six Steps

Only these steps change anything on the unit. Do them in order and the cast button will work at the end.

- [Step 1](#step-1--prerequisites) — **Prerequisites.** Rooted unit, UART access, and WSL with the four build tools — skip 1.2 if you already have them or use the ready-made APK.
- [Step 2](#step-2--enable-zygisk) — **Enable Zygisk** in Magisk, then reboot. Skip if Magisk already shows `Zygisk: Yes`.
- [Step 3](#step-3--install-vector) — **Install Vector**, the Xposed framework the module loads through, then reboot. Skip if it is already installed.
- [Step 4](#step-4--build-the-module) — **Build the module APK** with the one-shot builder script, or download the ready-made APK.
- [Step 5](#step-5--install--activate) — **Install and activate it** — install the APK, set its scope (with `system/0`), reboot.
- [Step 6](#step-6--use--test) — **Use it in the car**, parked: tap cast, then press the steering POWER button once.

**Everything else is there to read, not to run.** [Step 0](#step-0--what-you-get) shows what you get and how it works. [Fix Fast](#fix-fast) is for when something goes wrong. [Project Notes](#project-notes) keeps the meter panel research. [Step 7](#step-7--restore-to-stock) removes the mod — only run it if you want it gone.

## Step 0 — What You Get

`Overview`

A white cast button sits in the bottom bar, between the all-apps button and the home button. It looks and behaves like the stock buttons: it dims while you press it. An empty screen icon means nothing is cast. A filled screen icon means an app is on the meter panel.

**Reference** — The full flow
```text
Step 2  UART    → enable Zygisk in Magisk
Step 3  UART    → install the Vector framework
Step 4  WSL     → build CastBar-signed.apk with one script
Step 5  UART    → install, enable, set scope, reboot
Step 6  Car     → tap cast, press steering POWER once, done
```

The module does three things at the same time:

| Part | Runs in | What it does |
|---|---|---|
| **The button** | `com.android.systemui` | Adds the cast button to the bottom bar. On tap it moves the app on screen to display 1 (the meter panel), or back to display 0. |
| **Navigation signal** | `com.android.systemui` | On the first cast of each drive it tells the meter panel that navigation is running. The meter panel only switches to the head unit picture when the steering POWER button is pressed while navigation is running. |
| **No restart** | `system_server` | Moving an app to a screen of a different size normally makes Android restart it. The module tells Android to let the app keep running instead. |

> [!TIP]
> **Nothing in /system is touched.** No stock APK is patched, replaced or re-signed. Everything runs in memory through the Vector framework. That is why the undo is one command and there is no backup to restore ([Step 7](#step-7--restore-to-stock)).

## Step 1 — Prerequisites

`Hardware + Software`

**1.1 — What you need**

| What | Why |
|---|---|
| **Proton S70 (ECarX IHU524P)** | Tested on firmware V333. |
| **Rooted IHU with Magisk** | Written on Magisk 30.7. Magisk 26+ is the minimum. |
| **UART / PuTTY root access** | 921600 baud. This is also how you fix things if something goes wrong, so do not skip it. |
| **Linux or WSL machine** | Needs `apktool`, `jarsigner`, `zipalign` and `keytool` on PATH — 1.2 below installs all four. Not needed if you use the ready-made APK. |
| **USB pendrive** | With a folder named `mod`. Only the centre console socket is wired to the head unit. Every other USB port in the car only charges. |

> [!TIP]
> **Already have Zygisk and Vector** (for example from the [Steering Wheel Button Remap](steering-button-remap.md))? Skip Steps 2 and 3. Check with `/data/adb/modules/zygisk_vector/cli status`.

**1.2 — Install WSL & its tools**

> [!TIP]
> **Already have WSL and the tools, or using the ready-made APK? Skip the whole of 1.2.** Run `wsl -l -v` in PowerShell, then `which apktool jarsigner zipalign keytool` inside Ubuntu. If the first lists an Ubuntu distro and the second prints four paths, your machine is ready. Go straight to [Step 2](#step-2--enable-zygisk).

If you do not have it: the build runs inside Ubuntu, so install it first. Run this in **PowerShell as Administrator**, then restart Windows.

**PowerShell** — Install Ubuntu WSL
```text
wsl --install
```

Then open Ubuntu and install the four tools the builder in [Step 4](#step-4--build-the-module) needs. They all come from the Ubuntu archive. Nothing to download by hand, and no Android Studio:

**WSL** — Install the build toolchain
```bash
sudo apt-get update
sudo apt-get install -y apktool zipalign openjdk-17-jdk-headless
```

Check all four are on your PATH before you carry on. The builder stops with an error if one is missing:

**WSL** — Verify the toolchain
```bash
which apktool jarsigner zipalign keytool
```

**Output** — Four paths, one per tool
```text
/usr/bin/apktool
/usr/bin/jarsigner
/usr/bin/zipalign
/usr/bin/keytool
```

> [!CAUTION]
> **Safety:** test only with the car **parked and the engine running**, never while driving. The meter panel shows your speed and warning lights, and while an app is cast they are gone. Use this responsibly.

## Step 2 — Enable Zygisk

`UART · PuTTY`

Zygisk is the part of Magisk that lets an Xposed framework load. It is off by default. Skip this step if the Magisk app already shows **Zygisk: Yes**.

**UART** — Become root — before anything else in this step
```bash
su
```

The UART shell starts as a normal user, and **the rollback below needs root as well**, so run `su` before anything else. The prompt changes from `$` to `#`. Every reboot puts you back to a normal user, so run `su` again each time you reconnect.

> [!CAUTION]
> **This is the first step that changes how the unit boots.** Copy the rollback below and keep it somewhere you can reach without the car screen, then carry on.

**UART** — ROLLBACK — keep this handy first
```bash
magisk --sqlite "REPLACE INTO settings (key,value) VALUES('zygisk',0)"
reboot
```

**UART** — Enable Zygisk, then verify
```bash
magisk --sqlite "REPLACE INTO settings (key,value) VALUES('zygisk',1)"
magisk --sqlite "select * from settings"
```

Check that the output has `key=zygisk|value=1` in it, then reboot. Zygisk only starts on a fresh boot:

**UART** — Reboot — Zygisk starts on the next boot
```bash
reboot
```

After it comes back, the Magisk app home screen should show **Zygisk: Yes**.

> [!TIP]
> Magisk has its own bootloop protection and turns modules off by itself if a boot fails. With that and UART access, you can recover from this step even if the screen never comes on.

## Step 3 — Install Vector

`UART · PuTTY`

Vector is the maintained replacement for LSPosed, the Xposed framework that loads the module. The original LSPosed is archived and no longer updated. Vector v2.2 works on Android 8.1 to 17 and needs Magisk 26+ with Zygisk. The S70 is well inside that range.

| What to download | Where |
|---|---|
| **Vector v2.2 — Release zip** — filename looks like `Vector-v2.2-3080-Release.zip` (~9 MB) | [github.com/JingMatrix/Vector — v2.2 release](https://github.com/JingMatrix/Vector/releases/tag/v2.2) All releases: [/releases](https://github.com/JingMatrix/Vector/releases) |

Scroll to **Assets** on that release page and take the file ending in `-Release.zip`. Skip the `-Debug.zip` file and skip anything marked `canary`. Those are test builds.

> [!CAUTION]
> **Do not use v2.1.** It has a bug where modules load but no hooks actually run. v2.2 fixes it.

`Manual · pendrive`

Put the release zip in the `mod` folder on the pendrive, and plug it into the **centre console USB socket**.

**UART** — Become root — the Step 2 reboot reset your shell
```bash
su
```

**UART** — ROLLBACK — removes Vector entirely
```bash
rm -rf /data/adb/modules/zygisk_vector
reboot
```

**UART** — Install Vector, then reboot
```bash
magisk --install-module /mnt/media_rw/*/mod/Vector-*-Release.zip
reboot
```

The framework only loads after the unit comes back up, so the reboot is part of the install, not optional. When it is back, reconnect UART and become root again before you check:

**UART** — Become root — again, after the reboot
```bash
su
```

**UART** — Verify the framework
```bash
/data/adb/modules/zygisk_vector/cli status
```

You should get the framework version and the API version.

> [!TIP]
> **Use the CLI, not the manager app.** The ECarX launcher closes any app that is not on its whitelist, so the Vector manager app keeps getting killed. Everything in this guide is done from UART with `/data/adb/modules/zygisk_vector/cli`.

## Step 4 — Build the Module

`WSL Ubuntu`

One script does everything: it writes the whole project (manifest, icons, code), builds the APK, makes a signing key the first time you run it, then signs and aligns the APK.

> [!TIP]
> **Want to skip the build?** Download the ready-made [apk/CastBar-signed.apk](../apk/CastBar-signed.apk) (~12 KB), put it in the `mod` folder on the pendrive, and go straight to [Step 5](#step-5--install--activate). It is the same module the builder makes, already signed.
>
> SHA-256: `8632a195dcb7786351e68b0eb04a5903f0c3738b234f258b013a6193cacba481`

> [!WARNING]
> **Pick one and stay with it.** The ready-made APK and your own build are signed with different keys. Android will not install one over the other with `pm install -r`. To switch, run `pm uninstall com.ardentlab.cast` first, then install and do all of [Step 5](#step-5--install--activate) again.

Or build it yourself.

> [!TIP]
> **Get the builder:** [scripts/build-castbar.sh](../scripts/build-castbar.sh) (~48 KB). Open it on GitHub and use the **Download raw file** button at the top right of the file view.

Read it before you run it — it is plain bash.

### 4.1 — Get the script into your Linux / WSL home folder

If you downloaded it on Windows, it is in your Downloads folder. WSL reads that through `/mnt/c`. First find your Windows username:

**WSL** — List Windows users
```bash
ls /mnt/c/Users/
```

Ignore `All Users`, `Default`, `Public` and `desktop.ini`. Those are Windows system entries. Whatever is left is your username.

> [!TIP]
> If OneDrive backs up your Downloads folder, the file goes to `C:\Users\NAME\OneDrive\Downloads` instead of `C:\Users\NAME\Downloads`. Use the path that matches where the file really is. Pick the wrong one and the copy below fails with "No such file or directory".

Now copy it across, replacing `YOUR_USERNAME` with your own Windows username:

**WSL** — Copy from the Windows Downloads folder
```bash
cp /mnt/c/Users/YOUR_USERNAME/Downloads/build-castbar.sh ~/
```

**WSL** — Same, if OneDrive backs up your Downloads folder
```bash
cp /mnt/c/Users/YOUR_USERNAME/OneDrive/Downloads/build-castbar.sh ~/
```

### 4.2 — Run it

**WSL** — Build, sign and align in one go
```bash
cd ~
bash build-castbar.sh
```

Running it with `bash` means you never need `chmod +x`. If it stops with "not found in PATH", a tool from [Step 1.2](#step-1--prerequisites) is missing — the script is not broken.

**Output** — A successful build ends like this
```text
== aligning ==

DONE -> /home/you/CastBar-signed.apk
-rw-r--r-- 1 you you 11937 Oct  1 00:09 /home/you/CastBar-signed.apk
```

The file you want is `~/CastBar-signed.apk`. Copy it to the `mod` folder on your pendrive for [Step 5](#step-5--install--activate).

> [!WARNING]
> **Keep `~/castbar.keystore`.** It is the signing key made on the first build. Later updates must be signed with the same key, or `pm install -r` fails and you have to uninstall and set the module up again.

## Step 5 — Install & Activate

`UART · PuTTY`

Copy `CastBar-signed.apk` into the `mod` folder on the pendrive and plug it back into the centre console socket.

**UART** — Become root — first command here
```bash
su
```

**UART** — Install the module APK
```bash
pm install -r /mnt/media_rw/*/mod/CastBar-signed.apk
```

You may see a line like `avc: denied ... permissive=1`. That is an SELinux notice in permissive mode, not an error. What matters is that it says `Success`.

**UART** — Enable the module
```bash
/data/adb/modules/zygisk_vector/cli modules enable com.ardentlab.cast
```

**UART** — Set which processes it is injected into
```bash
/data/adb/modules/zygisk_vector/cli scope set com.ardentlab.cast com.android.systemui/0 system/0
```

> [!WARNING]
> **The scope must include `system/0`.** That is the name Vector uses for the Android framework (`system_server`). Without it the button and the cast still work, but the app restarts every time it moves. Vector also does not read the scope from the module itself, so this command is required.

**UART** — Clear the log and reboot — hooks load on the next boot
```bash
/data/adb/modules/zygisk_vector/cli log clear
reboot
```

### Confirm the hooks landed

Reconnect UART after the reboot. You are a normal user again, so become root once more before you read the log:

**UART** — Become root — again, after the reboot
```bash
su
```

**UART** — Read the framework log
```bash
/data/adb/modules/zygisk_vector/cli log cat | grep -F "CAST"
```

**Output** — What a healthy install looks like
```text
CAST sys: hooked ensureActivityConfiguration=2 shouldRelaunchLocked=1
CASTBAR: hooked
CASTBAR: hooked
CASTBAR: inserted
```

- `CAST sys: hooked` — the no-restart part is active. If this line is missing, the scope is missing `system/0`.
- `CASTBAR: hooked` appears twice because SystemUI runs as two processes.
- `CASTBAR: inserted` — the button is in the bottom bar.

> [!CAUTION]
> **Xposed logs do not go to logcat.** They go to Vector's own log, under the tag `VectorLegacyBridge`. You can only read it with `cli log cat`. If you search logcat you find nothing and think the hook failed.

## Step 6 — Use & Test

`In the Car`

Car parked, engine running. Do this once to check the install, then it is the same on every drive.

| # | Do this | Expected |
|---|---|---|
| 1 | Open the app you want on the meter panel, for example a map or a video app | The app is on the head unit screen |
| 2 | Tap the cast button | The icon fills in and the app leaves the head unit screen |
| 3 | Press the steering POWER button once, one or two seconds later | The app appears on the meter panel |
| 4 | Tap the cast button again | The app comes back to the head unit. The icon goes back to empty. No restart. |

> [!TIP]
> **POWER is needed only once per drive.** After that you can cast and uncast as often as you like. The meter panel stays in this mode until the car is fully powered off.

> [!WARNING]
> **On the home screen the button does nothing.** The launcher is never cast. Open an app first.

The small meter panel widget (0m / remaining / car icon) appears after the first cast. It is part of the meter panel's navigation mode, which is what lets the meter panel show the head unit picture. It goes away after a full power cycle. This is normal.

To check what happened after a cast:

**UART** — Is the app on the meter panel?
```bash
su
dumpsys activity activities | grep -iE "displayId=[01] stacks="
/data/adb/modules/zygisk_vector/cli log cat | grep -F "CAST"
```

**Output** — While an app is cast
```text
  displayId=1 stacks=1
  displayId=0 stacks=1
CAST sys: relaunch skipped (display move)
CAST: nav stream connecting (no fixed wait)
CAST: nav stream running (status 1 every 500 ms), first frame after retries=0
```

## Step 7 — Restore to Stock

`Rollback · Deletes Things`

> [!CAUTION]
> **Stop — read this before you copy anything**
>
> **This step is the undo. Nothing here installs or repairs the mod.** The commands below turn the cast button off and then delete it — the module, its APK, and in the last block the Xposed framework and Zygisk too. If you came here to build, you want [Step 4](#step-4--build-the-module). If the button is behaving strangely, try [Fix Fast](#fix-fast) first.
>
> **Only run these if every line below is true:**
>
> - You really want the bottom bar back to stock, with no cast button.
> - You are fine with the deletions. The second block removes the module APK. The third deletes `/data/adb/modules/zygisk_vector` and turns Zygisk off.
> - **Any other Xposed module you use stops working too**, for example the [steering button remap](steering-button-remap.md). They all load through Vector, so removing it disables every module on the unit, not just this one.
> - Your UART cable is connected and you can get a root shell, so you can recover if a reboot goes wrong.
>
> **Not sure?** Run only the first block. Disabling can be undone — `enable` brings the mod straight back, with nothing to rebuild or reinstall. Stop there and you lose nothing.

Three levels, depending on how far back you want to go. The gentlest one is first. Only go as far down as you need. None of them need a backup restored, because nothing was overwritten in the first place.

**UART** — Become root — needed for all three
```bash
su
```

Each block below ends in a reboot, which puts you back to a normal user. Run `su` again before the next block.

### Turn the mod off, keep everything installed (Reversible)

**UART** — Disable the module, then reboot
```bash
/data/adb/modules/zygisk_vector/cli modules disable com.ardentlab.cast
reboot
```

After the reboot the cast button is gone. Turn it back on any time with `enable` instead of `disable`.

### Remove the module completely (Deletes the APK)

**UART** — Uninstall the module APK, then reboot
```bash
pm uninstall com.ardentlab.cast
reboot
```

If this is the only custom navbar button installed, you can also delete the button order setting with `settings delete global ardentlab_navbar_order`. After uninstalling, do one full power cycle so the meter panel goes back to the normal gauges.

### Remove the framework and Zygisk too (Point of no return)

> [!CAUTION]
> **Last stop.** This block is not about this mod any more. It removes the whole Xposed layer from the unit. Every module you installed through Vector stops working, and getting it back means doing [Step 2](#step-2--enable-zygisk) and [Step 3](#step-3--install-vector) again. Skip this unless you want a plain rooted head unit back.

**UART** — Back to a plain rooted unit
```bash
rm -rf /data/adb/modules/zygisk_vector
magisk --sqlite "REPLACE INTO settings (key,value) VALUES('zygisk',0)"
reboot
```

> [!TIP]
> **Why there is nothing else to undo.** No stock APK was changed, so there is no file to put back. `/system` is exactly as it shipped. This project leaves only a few things behind: the Zygisk setting, the Vector module folder, one APK in `/data/app` and the button order setting. The commands above remove all of them.

## Fix Fast

`Troubleshoot`

| Symptom | Cause and fix |
|---|---|
| No cast button in the bottom bar | Check the module is enabled and the scope has `com.android.systemui/0` (`cli scope ls com.ardentlab.cast`), then reboot. The log must show `CASTBAR: inserted`. |
| No CAST lines in the log | You are probably searching logcat. Use `cli log cat` instead. |
| Tapping the button does nothing | You are on the home screen. Open an app first. |
| The app leaves the screen, but the meter panel shows nothing | Press the steering POWER button once. If it still shows nothing, check the log for `nav stream running`. If it says `FAILED`, do a full power cycle and try again. |
| The steering POWER button does nothing | It only works after the first cast of the drive. Tap cast first, then press POWER. |
| The app restarts when cast or uncast | The `CAST sys: hooked` line is missing. Add `system/0` to the scope ([Step 5](#step-5--install--activate)) and reboot. |
| `pm install -r` fails with a signature error | The APK was signed with a different key (switching between the ready-made APK and your own build, or the keystore was lost). Run `pm uninstall com.ardentlab.cast`, install again, then enable and set the scope again. |
| The build stops with "not found in PATH" | Install the tools in [Step 1.2](#step-1--prerequisites). |
| The meter panel is stuck showing the IHU or an app | Full power cycle: engine off, lock the car, wait until the meter panel is dark (about 1 minute), start again. |
| Unit will not boot after enabling Zygisk | Connect UART and run the Zygisk rollback from [Step 2](#step-2--enable-zygisk). Magisk's bootloop protection may have turned the modules off for you already. |

## Project Notes

`Maintenance`

Nothing here needs to be run. The first part is what you need to keep the mod working. The rest is the research behind it, in the order it was worked out, so none of it has to be rediscovered.

- [1. Living with the mod](#1-living-with-the-mod) — updating, more buttons, safety.
- [2. How the meter panel works](#2-how-the-meter-panel-works) — the display, the HDMI switch, and the fake navigation that unlocks it.
- [3. Moving an app without a restart](#3-moving-an-app-without-a-restart) — the ways that were tried and the one that stuck.
- [4. Building the module](#4-building-the-module) — SystemUI, the button, smali and Vector lessons.
- [5. Reference](#5-reference) — vehicle properties, system components, dead ends, open questions and research methods.

### 1. Living with the mod

**Updating**

Run the builder again (or download the newer ready-made APK, if that is what you installed), then `pm install -r` the new APK and reboot. The module stays enabled and keeps its scope, so you do not need to redo Step 5.

**More navbar buttons**

Other custom navbar buttons from the same series can sit next to this one. They line up by install order: the first one installed sits next to home, and each later one goes further left, with all-apps always on the far left. The order is kept in `settings get global ardentlab_navbar_order`. Updating with `pm install -r` does not change it. Uninstalling and installing again moves that button to the far left. Install one button, reboot, then install the next.

**Safety**

- The meter panel shows speed, brake, ABS, airbag, oil pressure and coolant warnings. When it shows an app, all of those are gone. Test parked with the engine running, never while driving. Likely a compliance issue at a road-transport inspection.
- Stuck meter panel: full power cycle (engine off, wait 30 s to 1 min, restart).
- Do not open `ecarx.factorymode` casually. It may hold destructive calibration or reset functions.

### 2. How the meter panel works

Everything from here on was worked out on the author's own S70 over many hours in the car, before and during this project.

**Test environment**

| Item | Value |
|---|---|
| Vehicle | Proton S70 |
| Head unit | ECARX IHU524P, model SS11R |
| Android | 9 (Pie), build `ecarx/IHU524P/IHU524P:9/PQ2A.190405.003/333:user/dev-keys` (V333) |
| SELinux | Permissive (root operations are not blocked by policy) |
| Root | Magisk (context `u:r:magisk:s0`) |
| /system | read-only, `/dev/block/mmcblk0p42` (ext4) |
| Access | UART via CH340G USB-TTL, 921600 baud, 8N1, no flow control; `su` gives root |

It is a user build, so developer shell commands like `dumpsys car_service --help` and `cmd car_service` are blocked ("Commands not supported in user"). Tip: connect UART before powering the IHU to capture the full boot log.

**The meter panel is a second HDMI display**

The meter panel is a second display that is always powered and always connected to the IHU. Android sends it a picture the whole time. The meter panel's MCU decides whether to show that HDMI picture or its own native gauges.

`dumpsys display` shows two displays:

| Display | Unique ID | Resolution | Type | Flags |
|---|---|---|---|---|
| 0: IHU screen | `local:0` | 1920×720 @ 59.98 | BUILT_IN | DEFAULT_DISPLAY, SECURE |
| 1: Meter panel | `local:1` | 1280×480 @ 30 | HDMI | PRESENTATION, SECURE |

- Both are ratio 2.667, so mirroring scales cleanly with no distortion.
- Display 1 is always state ON, even while the meter panel shows gauges.
- Display 1 also exists on the bench unit with no meter panel attached (`displayId=1 stacks=0`), so casting can be tested there with `dumpsys` even though nothing is visible.
- The size difference (1920×720 vs 1280×480) is exactly why Android wants to relaunch an app moved between them. [Part 3](#3-moving-an-app-without-a-restart) covers how the module stops that.

Automatic mirroring (standard AOSP DisplayManagerService): when display 1 has no content of its own, Android mirrors display 0 onto it.

| State | mHasContent | mCurrentLayerStack | LayerStackRect | Meter panel shows (in HDMI mode) |
|---|---|---|---|---|
| No app owns display 1 | false | 0 | 1920×720 | Full IHU screen mirror |
| An app owns display 1 | true | 1 | 1280×480 | That app |

State probe: `dumpsys display | grep mHasContent` (line 1 = display 0, line 2 = display 1).

**Two separate channels into the meter panel**

- **DIM data channel:** `ECarXDimServiceImpl` sends byte frames (turn arrow, distance, ETA) through a vehicle property. The meter panel draws these with its own graphics. This is the small nav widget (0m / remaining / car icon).
- **HDMI video:** Android draws real pixels on display 1. The meter panel shows them only after the MCU has switched to the HDMI source.

They are independent: widget without video, or video without widget, are both possible.

**Reference** — Signal paths: steering button, navigation data and video
```text
steering button
      │
      ▼
 MCU (SWRC ADC) ──── CAN ────► meter panel source select ──► HDMI or native gauges
      │
      ▼
 HW_KEY_INPUT = 0x2d (45) ──► Android (notification only)

Proton Map ──► NaviService ──► ECarXDimServiceImpl ──► IPKSET_CMD ──► meter panel native overlay
Proton Map ──► Presentation on display 1 ─────────────────────────► HDMI video layer
```

**How the meter panel enters HDMI mode**

- The MCU only honours the steering POWER button source switch while it believes navigation is running. Without navigation the button does nothing.
- **Stock way:** open Proton Map → set a destination → Go → press steering POWER once.
- **Full Map setting:** the meter panel has its own menu. Steering MENU → Navi page → Full Map (Enable / Disable). It shows "Navi Not Planning Route" when no navigation is running. With navigation running, Full Map → Enable puts the meter panel into HDMI mode. Default is Disable, which is why the POWER button looked like it did nothing at first.
- **Persistence:** HDMI mode and the "navigation running" state live in MCU memory. They survive an IHU or Magisk reboot (the MCU never loses power) and are lost only on a full power cycle (engine off, car locked, meter panel dark about 30 s to 1 min). So POWER is pressed once per drive.

Why the famous "reboot loophole" worked: start guidance in Proton Map → press POWER (map shows on the meter panel via its Presentation on display 1) → reboot the IHU. The MCU stays in HDMI mode, Proton Map is no longer running, nobody owns display 1, so Android mirrors the IHU screen. The reboot itself is irrelevant: removing the owner of display 1 (`am force-stop com.neusoft.na.navigation`) does the same in one second.

**Faking "navigation running" without Proton Map**

So the one thing the mod needs is to make the MCU believe navigation is running.

First attempt (not enough): a single `ECarXDimServiceImpl.notifyNavigationStatus(2)` call (run with `app_process` from a small smali dex, and later from the module). It ran without error, but the MCU did not accept the POWER switch. Watching `dumpsys car_service | grep -iE "28700056|28700064"` showed no change.

Working method: stream fake navigation info, exactly like a real navigation app does:

1. `vsm = new com.ecarx.xui.adaptapi.car.impl.vehicle.VehicleSignalManager(ctx)`
2. `vsm.connect()` (easy to miss, but required)
3. `dim = com.malaysia.xui.adaptapi.dim.impl.ECarXDimServiceImpl.getInstance(ctx, vsm)`
4. Every 500 ms, call `dim.updateNAVInfo(info)`, where `info` implements `com.malaysia.xui.adaptapi.diminteraction.INaviInteraction$INavigationInfo` with `getNavigationStatus() = 1` and everything else empty.
5. To stop, send one frame with status 0.

Notes:

- `INavigationInfo` has 14 getters: `getDayNightMode()I`, `getDistanceToDestination()J`, `getDistanceToNextGuidancePoint()J`, `getDrivingDirection()I`, `getETA()J`, `getHighwayExitInfo()` (`INaviInteraction$IHighwayExitInfo`), `getLaneInfo()` (`[INaviInteraction$ILaneInfo`), `getMuteState()I`, `getNavigationStatus()I`, `getNavigationTurnId()I`, `getNavigationTurnSVG()` (String), `getNextGuidancePointName()` (String), `getRoadCameraInfo()` (`INaviInteraction$IRoadCamera`), `getServiceAreaInfo()` (`INaviInteraction$IServiceArea`). Returning 0 for numbers, `" "` for strings and null for objects works.
- These classes are on the boot classpath, so any process (`app_process`, SystemUI, an app) can use them. An app needs `android.car.permission.CAR_VENDOR_EXTENSION` (priv-app whitelist); SystemUI already has it, which is one reason the module lives there.
- The old app slept 5 s after connecting before the first frame. That wait is not needed: start sending at once and retry frames that fail while the car service connects. In the car the first frame went through immediately and POWER worked 1 to 2 s after the tap.

### 3. Moving an app without a restart

**Ways to put an app on display 1**

| Method | Result |
|---|---|
| `am start --display 1 -f 0x18000000 -n pkg/activity` | Works, but only as a new task. `0x18000000` = NEW_TASK + MULTIPLE_TASK. Without it Android ignores `--display 1` if the app already has a task on display 0 ("its current task has been brought to the front"). Needs a force-stop first, so the app restarts every time. |
| `am force-stop <owner of display 1>` | Frees display 1, and the meter panel goes back to mirroring the IHU. |
| `am display move-stack <stackId> <displayId>` | Moves the running app (same process). Note: under `am display`, not `am` or `am stack`. Android still relaunches the activity because the display size differs. |
| `IActivityManager.moveStackToDisplay(stackId, displayId)` via `ActivityManager.getService()` | Same as move-stack, callable from inside SystemUI with no shell or root. The focused stack comes from `getFocusedStackInfo().stackId`. This is what the button uses. |

**Why the app does not restart**

`moveStackToDisplay` keeps the same process, but Android would still relaunch the activity because the meter panel is a different size. The module's `system_server` hook forces `ActivityRecord.shouldRelaunchLocked` to false for display moves only, so the app just gets told its screen changed. Other configuration changes (language, dark mode) behave as stock.

Confirmed test targets: `com.malaysia.weather/.ui.host.HostActivity`, `com.malaysia.calendar/.ui.main.MainActivity`. Resolve any app's activity with `cmd package resolve-activity --brief <pkg> | tail -1`.

**Reference** — Useful state checks
```bash
dumpsys display | grep -E "mCurrentLayerStack|mHasContent"
dumpsys window displays | grep -A15 "Display: mDisplayId=1"
dumpsys activity activities | grep -iE "displayId=[01] stacks="
dumpsys activity activities | grep -inE "stack #|mFocusedStack|mResumedActivity"
logcat -b events -d | grep -iE "am_relaunch|am_proc_died|am_kill"
```

The same pid does not prove there was no restart. Check the events buffer for `am_relaunch_activity`, as in the last line above.

### 4. Building the module

**SystemUI and the navbar**

- The bottom bar window is `CarNavigationBar`, owned by `com.android.systemui` (uid 10012). Not the launcher.
- `/system/priv-app/SystemUI/SystemUI.apk` (15788509 bytes) is not odexed, so `apktool d` gives smali and resources directly.
- `res/layout/car_navigation_bar.xml` = `CarNavigationBarView` containing `com.ecarx.systemui.EcarxClimateBarView` (`@id/ecarx_navi_bar_layout`). Its `loadNavigationBarView()` gets the real bar from `com.ecarx.systemui.EcarxBars.getInstance(ctx).getNavigationBarView()`.
- `EcarxBars.getNavigationBarView()` loads `com.malaysia.systemuiplugin.MainActivity` from a `PathClassLoader` over `createPackageContext("com.malaysia.systemuiplugin")` and calls `createNavigationBarWidget(Context,Bundle)`. The plugin (`/system/app/SystemUIPlugin/SystemUIPlugin.apk`, 2006460 bytes) IS odexed, so we never touch it: we hook `EcarxBars.getNavigationBarView` (in SystemUI's own dex) and edit the returned view.
- The hook fires in two SystemUI processes.
- A tiny recon build that only logged the view tree mapped the bar before any button was built.

**Getting the button to look native**

- Every nav button is 80×80 px, height `MATCH_PARENT`, padding 0. Measured at runtime with a temporary `postDelayed` logger after layout (sizes are 0 before layout).
- What failed first: copying only home's width/height gave the wrong spacing. Cloning home's outer box + `FIT_CENTER` made the icon too big. Cloning home's inner box made it too small. Correct: clone the all-apps button's `LayoutParams`, inner `ImageView` `MATCH_PARENT` + `FIT_CENTER`.
- Icons: red/green was rejected in favour of white empty/filled screens. The SystemUI `ic_mr_button_connected_00/30_dark.png` (72×72) looked right but went soft when scaled, so the icons are vector drawables (Material cast / cast_connected paths, viewport 40, path translated 8).
- 1:2 spacing means visible glyph gaps, not box margins: custom buttons have zero side margins and the all-apps button's own `rightMargin=38` gives the double gap.
- Press dim: an `OnTouchListener` (DOWN alpha 0.5, UP alpha 1.0, CANCEL alpha 1.0), like the stock `PressedImageView`.

**Smali gotchas**

- Normal `invoke-*` can only address v0..v15. With `.locals 16`, `p1` becomes v17: use `invoke-virtual/range {p1 .. p1}`.
- Wide values (long) take two registers; `const-wide/16 vN` needs vN+1 free.
- Try ranges in dex must not overlap: use separate `:try_start_N` blocks instead of nesting.
- `if-*` instructions reach any register; only non-range invokes are limited.

**Vector lessons**

- Vector does not read the scope from the module; set it with `cli scope set`.
- The framework (`system_server`) scope must be named `system`. `android/0` was accepted by the CLI but the hook never loaded, which is why Step 5 uses `system/0` only (`handleLoadPackage` still sees package `"android"`).
- Xposed logs go only to `cli log cat` (tag `VectorLegacyBridge`), not logcat.
- Use the CLI from UART; the ECarX launcher kills the Vector manager app.

**Bench unit quirks**

- The bench clock resets to 1 Jan 2010 every boot (no network), which broke install-time ordering.
- Display 1 exists without a meter panel, so moves can be checked with `dumpsys`, but the bench can never show the relaunch problem or anything about the MCU.

### 5. Reference

**Vehicle properties that matter**

From `dumpsys car_service` → Dump Vehicle HAL → All properties / ALL PropertyValues (access 0x1 read, 0x2 write, 0x3 read+write).

| Property ID | Name | Access | Notes |
|---|---|---|---|
| `0x287000b0` (678428848) | INFO_ID_IPKSET_CMD | 0x3 | Command channel to the meter panel. DimService writes byte frames here. |
| `0x287000fa` | HW_KEY_INPUT | 0x1 | Steering POWER → value 0x2d (45). Read-only notification. |
| `0x2870006c` | INFO_ID_MMI_NAVSYNCDISPLAY | 0x2 | Write-only. Never seen changing during cast. |
| `0x2870012f` | INFO_ID_DISPLAYSOURCE_VIDEO_SOURCE | 0x3 | Value 0. Seems DVR/dashcam (QDrive) related, not the meter panel. |
| `0x28700065` | INFO_ID_HUDACTIVEREQ | 0x3 | Value 0. The S70 has no HUD. |
| `0x2870004f` | INFO_ID_IPK_SYNC_CURRENT_STATUS | 0x2 | Write-only. |

IPKSET_CMD frame format (DimService log matched against `VehicleEmulator_v2_0` write data):

**Reference** — IPKSET_CMD frame format
```text
DIM log:  updateNAVInfo   [3,42,0] {8,40,2,18,2f,80,6,58,10,4c,0,6f,...}
MCU wire: 11 11 03 04 00 2b 00 03 2a 00 08 40 02 18 2f 80 06 58 10 4c 00 6f ...

DIM log:  updateServiceAreaInfo IPK [9,10,0] {0,87,42,0,0,1,20,0}
MCU wire: 11 11 03 04 00 0b 00 09 0a 00 00 87 42 00 00 01 20 00

Structure:  11 11 03 04 00 <totalLen> 00 <msgId> <payloadLen> 00 <payload...>
Known msgId:  0x03 = navigation info      0x09 = service area info
```

AdapterAPI symbols (`/system/framework/boot-AdapterAPIImpl.vdex` is uncompressed dex, so it greps): `sendIPKCommand` (command channel), `sendIntToMCUByPropID`, `sendBytesToMcuByPropID` (write any MCU property), `sendDataToScreen`, `sendToMCU`, `updateNaviStatus`, `updateCurrentSourceType`, `startApplicationToDisplay`, `disableScreenProjection`, `getPresentationDisplay`.

**System components**

| Component | Path / package | Role |
|---|---|---|
| DimService | `com.malaysia.dim`, `/system/app/DimService/DimService.apk` | Pushes nav data to the meter panel. Logs as `[DimService APP]NavModule`. |
| AdapterAPI | `/system/framework/AdapterAPI.jar`, `boot-AdapterAPIImpl.vdex` | ECARX framework layer with `ECarXDimServiceImpl`, `sendIPKCommand`, `VehicleSignalManager`. |
| Navigation | `com.neusoft.na.navigation/.mots.MainActivity` | Proton Map. Owns a Presentation on display 1 while navigating. |
| Vehicle HAL | `automotive.vehicle@2.0-impl` | Bridges `CarPropertyManager` to the MCU serial link. |
| MCU bridge | `VehicleEmulator_v2_0` | Despite the name, the real MCU frame reader/writer, not an emulator. |
| Engineering apps | `ecarx.factorymode`, `ecarx.debugtools` | Not explored. Factory mode may hold destructive calibration/reset functions. |
| Launcher | `com.malaysia.launcher3/.ui.LauncherUi` | Home stack (stackId 0). Never cast it. |

**Dead ends (tested, do not work)**

| Attempt | Result |
|---|---|
| `settings put system visibility 42504` | No effect. The value changes during cast but is a passive record. |
| `setprop sys.nav.name` / `sys.nav.pid` | No effect. Published by the nav app, not read as a trigger. |
| `input keyevent 45` | No effect. The steering button goes through CarInputService, not the normal input pipeline. |
| `dumpsys car_service --help`, `cmd car_service -h` | Blocked on user builds. No shell path to write vehicle properties. |
| `lshal debug ...IVehicle/default` | Empty. The VHAL dump is inside `dumpsys car_service` instead. |
| VehicleEmulator TCP socket (AOSP port 33452) | Not present. |
| InstrumentClusterService | Always `renderer: false`, `renderer service: null`. ECARX does not use the AOSP cluster framework for the meter panel. |
| Diffing VHAL property values across cast/uncast | No change. The source switch is fire-and-forget. |
| Steering POWER without navigation running | No effect. |
| `am start --display 1` without `-f 0x18000000` | Ignored if the app already has a task on display 0. |
| A single `notifyNavigationStatus(2)` | Accepted without error, but the MCU does not switch. Needs the `updateNAVInfo` stream. |
| `am move-stack`, `am stack move-stack` | "Unknown command". The real one is `am display move-stack`. |
| Scope `android/0` for the `system_server` hook | Accepted by the CLI, but the hook never loads. Use `system/0`. |

**Still open**

- **Back to native gauges from Android:** not found. Only the steering button (in the stock flow) or a full power cycle does it. Uncasting only returns the meter panel to mirroring the IHU.
- **Stuck navigation widget:** if a nav app is force-stopped during active guidance, the widget stays because "guidance ended" is never sent. `am force-stop com.malaysia.dim` does not clear it; only a full power cycle does. (Our stream sends status 1 until reboot; a clean stop would send status 0.)
- `ecarx.factorymode` / `ecarx.debugtools` may contain direct meter panel tests.
- Talking to IPKSET_CMD directly (`sendIPKCommand` / `updateNaviStatus`) was never needed once the `updateNAVInfo` stream worked.

**Research methods that worked**

State diffing: capture, act, capture, then diff only the delta. Take two baselines first to measure the noise.

**Reference** — State diffing: capture, act, diff
```bash
dumpsys car_service > 1-car.txt   # ... do the action ...   dumpsys car_service > 2-car.txt
awk '/Dump Vehicle HAL/,0' 1-car.txt > 1v.txt; awk '/Dump Vehicle HAL/,0' 2-car.txt > 2v.txt
diff 1v.txt 2v.txt
```

- **Rare log lines:** strip digits so repeating telemetry collapses, then sort by frequency: `cut -c33-120 log.txt | tr -d '0-9' | sort | uniq -c | sort -n | head -60`
- **Self-terminating capture:** `logcat -c; logcat -b main -b system -v threadtime > btn.log 2>&1 & sleep 15; pkill -f "logcat -b main"`
- **Log markers:** `log -t TAG "MARK1"` ... action ... `log -t TAG "MARK2"`, then `sed -n '/MARK1/,/MARK2/p' log.txt`.
- **Symbols from .vdex** (uncompressed dex): `grep -aoE "send[A-Za-z]{2,40}" file.vdex | sort -u`, `grep -aoE "Lcom/vendor/pkg/[a-zA-Z0-9/_]{3,60};" file.vdex | sort -u`. APK/JAR contents are zipped and will not match.
- **Reading an APK without tools:** a ~100-line Python dex parser (string/type/method tables + invoke/const-string decoding) was enough to recover exactly what the old app's classes.dex did.
