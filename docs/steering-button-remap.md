# Steering Wheel Button Remap — Drive Mode, Voice & 360 Camera

A short press on `Hi Proton` cycles the drive mode, while holding it still wakes the voice assistant. Holding the call button opens the 360 camera, and a short press still answers calls as before. Everything is done by hooking the apps at runtime, so not a single system file is modified and the undo is one command.

**Brand:** Proton · **IHU:** ECarX E02 · V333 · **Android:** 9 · **Method:** Xposed runtime hooks · **System files changed:** None

---

## Contents

- [Step 0 — What You Get](#step-0--what-you-get)
- [Step 1 — Prerequisites](#step-1--prerequisites)
- [Step 2 — How Buttons Work](#step-2--how-the-steering-buttons-actually-work)
- [Step 3 — Why Not Patch Apps](#step-3--why-the-stock-apps-are-not-patched)
- [Step 4 — Trace Any Button](#step-4--trace-any-button-yourself)
- [Step 5 — Reference Values](#step-5--reference-values)
- [Step 6 — Enable Zygisk](#step-6--enable-zygisk)
- [Step 7 — Install Vector](#step-7--install-the-xposed-framework)
- [Step 8 — Build the Module](#step-8--build-the-module)
- [Step 9 — Install & Activate](#step-9--install--activate)
- [Step 10 — Test](#step-10--test)
- [Step 11 — Restore to Stock](#step-11--restore-to-stock)
- [Fix Fast](#fix-fast)
- [Project Notes](#project-notes)

---

## The Short Path — Six Steps

These are the only steps that change anything on the unit. Follow them in order and the buttons work at the end.

- [Step 1](#step-1--prerequisites) — **Prerequisites.** Rooted unit, UART access, and WSL with the four build tools installed.
- [Step 6](#step-6--enable-zygisk) — **Enable Zygisk** in Magisk, then reboot.
- [Step 7](#step-7--install-the-xposed-framework) — **Install Vector**, the Xposed framework the module loads through.
- [Step 8](#step-8--build-the-module) — **Build the module APK** with the one-shot builder script.
- [Step 9](#step-9--install--activate) — **Install and activate it** — install the APK, set its scope, reboot.
- [Step 10](#step-10--test) — **Test in the car**, parked, with a phone paired.

**Everything else is there to explain, not to run.** [Step 0](#step-0--what-you-get) is what you get, [Steps 2](#step-2--how-the-steering-buttons-actually-work) and [3](#step-3--why-the-stock-apps-are-not-patched) explain why it is done this way, [Step 4](#step-4--trace-any-button-yourself) shows how to trace a different button, and [Step 5](#step-5--reference-values) lists the values this guide already found for you. [Fix Fast](#fix-fast) is for when something misbehaves, and [Step 11](#step-11--restore-to-stock) is the undo — do not run it unless you want the mod gone.

## Step 0 — What You Get

`Overview`

Two steering wheel buttons gain a second function on a long press, while their normal short-press behaviour stays exactly as it was.

| Button | Short press | Hold ~2 seconds |
|---|---|---|
| **Hi Proton** | **Cycle drive mode** — Comfort → ECO → Sport → back to Comfort | Voice assistant, exactly as stock |
| **Pick up call** | Answer call / dialler, exactly as stock | 360 camera |

> [!TIP]
> **Nothing in /system is touched.** No stock APK is patched, replaced or re-signed. Every change happens in memory while the apps are running. That is why the undo is a single command and there is no backup to restore — the partition is byte-for-byte as it shipped.

The method generalises. Any steering button on this platform can be remapped the same way, and [Step 4](#step-4--trace-any-button-yourself) shows how to trace one yourself rather than trusting the values in this guide.

## Step 1 — Prerequisites

`Hardware + Software`

**1.1 — What you need**

| What | Why |
|---|---|
| **Rooted IHU with Magisk** | Written on Magisk 30.7. Magisk 26+ is the minimum. |
| **UART / PuTTY root access** | 921600 baud. This is also your recovery path if anything goes wrong, so do not skip it. |
| **Linux or WSL machine** | Needs `apktool`, `jarsigner`, `zipalign` and `keytool` on PATH — 1.2 below installs all four. |
| **USB pendrive** | To move files across. Only the centre console socket is wired to the head unit — every other USB port in the car is charge-only. |

**1.2 — Install WSL & its tools**

Everything on the build side happens inside Ubuntu. Install it first — run this in **PowerShell as Administrator**, then reboot. Skip it if `wsl -l -v` already lists an Ubuntu distro.

**PowerShell** — Install Ubuntu WSL
```text
wsl --install
```

Then open Ubuntu and install the four tools the builder in [Step 8](#step-8--build-the-module) calls. All of them come straight from the Ubuntu archive — nothing to download by hand, no Android Studio:

**WSL** — Install the build toolchain
```bash
sudo apt-get update
sudo apt-get install -y apktool zipalign openjdk-17-jdk-headless
```

| Package | What it gives you |
|---|---|
| **apktool** | `apktool` — builds the module project into an unsigned APK. |
| **zipalign** | `zipalign` — aligns the signed APK, the last step before it is installable. |
| **openjdk-17-jdk-headless** | `jarsigner` and `keytool` — signs the APK and creates the signing key on first run. The JRE alone is not enough; `jarsigner` ships only with the JDK. |

Check all four landed on your PATH before you go any further — the builder stops with an error if one is missing:

**WSL** — Verify the toolchain
```bash
apktool --version
which apktool jarsigner zipalign keytool
```

**Output** — Four paths, one per tool
```text
2.7.0-dirty
/usr/bin/apktool
/usr/bin/jarsigner
/usr/bin/zipalign
/usr/bin/keytool
```

> [!TIP]
> **Why the archive version is the right one.** Written on Ubuntu 24.04 in WSL2, where `apt` gives you apktool 2.7. The builder writes an **apktool 2.x** project file, so the packaged version is exactly what you want — a hand-installed 3.x build complains about `apktool.yml` instead (there is a fix in [Step 8](#step-8--build-the-module) if you end up on one).

> [!CAUTION]
> **Safety:** test with the car **parked, handbrake up, engine running** — never while driving. You are changing buttons on the steering wheel, so treat that seriously. Do not test the call button until you have read [Step 9](#step-9--install--activate); with a phone paired, the stock long press dials the last number.

## Step 2 — How the Steering Buttons Actually Work

`How It Works`

Worth understanding before changing anything, because it explains why the obvious approach fails.

The steering buttons are **not** normal Android input. They never appear in `getevent`. They arrive as CAN bus signals, get turned into Android key events by the car input service, and are then handed to a dispatcher app that broadcasts them to every interested app:

**Reference** — Signal path
```text
CAN bus
  -> CarInputService              (keyCode 298 / 299)
  -> com.malaysia.ConnectService  (maps to internal id, classifies press type)
  -> 12 subscriber apps           (voicemaster, btphone, screensaver, ...)
```

Every subscriber app implements the same three callbacks:

**Reference** — The callback trio
```text
onHkShortPress(int keyId)
onHkLongPress(int keyId)
onHkRelease(int keyId)
```

> [!TIP]
> **This is the key insight for the whole project.** Changing a button means intercepting one of those three methods in whichever app currently acts on that key. The same pattern applies to every steering button on this platform, not just the two covered here.

> [!WARNING]
> **Long press already does something.** Holding a button is not a free slot. Several apps already receive `onHkLongPress` and act on it — the call button in particular redials the last number when a phone is paired. Any long-press mod has to suppress the existing behaviour as well as add the new one, or you get both at once.

## Step 3 — Why the Stock Apps Are Not Patched

`Important`

The instinct is to decompile the app that handles the button, edit it, and put it back. On this platform that is a dead end — and it costs nothing to check before you break something.

**UART** — Is this app platform-signed?
```bash
dumpsys package com.malaysia.btphone | grep -E "userId|sharedUser|pkgFlags|codePath"
```

Both apps we care about answer like this:

**Output** — The blocker
```text
userId=1000
sharedUser=SharedUserSetting{android.uid.system/1000}
codePath=/system/app/BTPhone
```

> [!CAUTION]
> **android.uid.system** means the app shares the system identity, which requires it to be signed with the manufacturer's private platform key. Re-sign it with your own key and it refuses to load — and your Bluetooth phone stops working. `com.malaysia.voicemaster` is the same. Run this check on any app before you plan to patch it.

So instead of editing the apps, we hook them at runtime with an Xposed framework. The APK files on disk are never touched.

## Step 4 — Trace Any Button Yourself

`UART · PuTTY`

You do not have to take the values in this guide on faith, and you will need this method if you want to remap a different button.

### 4.1 — Watch the buttons

**UART** — Become root
```bash
su
```

**UART** — Clean button trace — press a button after running this
```bash
logcat -c && logcat -v time | grep -E "KeyInput|onHk|CarInputListener|KeyPressed"
```

The screen stays silent until you press a steering button. You then see the raw keycode, the internal id, which apps it is dispatched to, and which app's `onHk*` callback fires — including the full class name.

> [!CAUTION]
> **Filter words that will flood your console.** Never put `avm`, `Dynamic` or `Camera` in a logcat grep on this unit. `avm` matches the 360 camera daemon and `Dynamic` matches the audio ring buffer — both log continuously and will bury what you are looking for. Use exact tag names, case-sensitive, as above.

> [!WARNING]
> **getevent is a dead end here.** Steering buttons never reach the Linux input layer, so an empty `getevent` is expected behaviour, not a fault. Do not waste an hour on it like we did.

### 4.2 — Find what an on-screen action sends

To learn how to trigger something yourself — drive mode, for example — watch the log while you do it the normal way on the screen:

**UART** — Watch activity launches and intents
```bash
logcat -c && logcat -v time | grep -E "START u0|Displayed"
```

The intent and component name appear in the log, and you can replay them from the shell to confirm before writing any code.

### 4.3 — Get an app's exact class names

**UART** — Running components of a package
```bash
dumpsys activity services com.malaysia.btphone | grep -oE "com\.malaysia\.btphone/[A-Za-z0-9_./$]*" | sort -u
```

## Step 5 — Reference Values

`Findings`

| Item | Value |
|---|---|
| Hi Proton button | keyCode 298 → id 200231 (0x30E27), label "VR" |
| Pick-up-call button | keyCode 299 → id 200005 (0x30D45), label "Phone" |
| Dispatcher app | com.malaysia.ConnectService |
| VR key handler | com.malaysia.voicemaster.util.ConnectServiceUtil$3 |
| Phone key handler | com.malaysia.btphone.service.BlueToothService |
| 360 camera app | ecarx.camera.calibration/.MainActivity |
| Drive mode action | ecarx.settings.vehicle.setting.widget.CarSettingWidget.action.ACTION_CLICK |
| Drive mode targets | ecarx.settings/.vehicle.setting.widget.DriveMode{Comfort \| ECO \| Sport}Widget |

Both actions can be tested from the shell before you build anything — a good sanity check that your unit matches this guide.

**UART** — Open the 360 camera
```bash
am start -n ecarx.camera.calibration/.MainActivity
```

**UART** — Switch to Sport mode
```bash
am broadcast -a ecarx.settings.vehicle.setting.widget.CarSettingWidget.action.ACTION_CLICK -n ecarx.settings/.vehicle.setting.widget.DriveModeSportWidget
```

> [!WARNING]
> **The 360 camera app has a misleading name.** `ecarx.camera.calibration` sounds like a factory calibration tool, but it is the actual 360 view. No package on the unit contains "avm", "360" or "surround" — the imaging itself is done by a native daemon with no Android activity of its own.

## Step 6 — Enable Zygisk

`UART · PuTTY`

Zygisk is the part of Magisk that lets an Xposed framework load. It is off by default.

> [!CAUTION]
> **This is the first step that touches the boot path.** Everything before it was read-only. Copy the rollback below and keep it somewhere you can reach without the car screen, then proceed.

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

Confirm the output contains `key=zygisk|value=1`, then `reboot`. After it comes back, the Magisk app home screen should show **Zygisk: Yes**.

> [!TIP]
> Magisk has its own bootloop protection and will disable modules by itself if a boot fails. Between that and UART access, this step is recoverable even if the screen never comes up.

## Step 7 — Install the Xposed Framework

`UART · PuTTY`

The original LSPosed is archived and no longer maintained. Its successor is **Vector**, by the same developer who kept the LSPosed fork alive. Vector v2.2 supports Android 8.1 through 17 and needs Magisk 26+ with Zygisk — the S70 sits comfortably inside that range.

| What to download | Where |
|---|---|
| **Vector v2.2 — Release zip** — filename looks like `Vector-v2.2-3080-Release.zip` (~9 MB) | [github.com/JingMatrix/Vector — v2.2 release](https://github.com/JingMatrix/Vector/releases/tag/v2.2) All releases: [/releases](https://github.com/JingMatrix/Vector/releases) |

Scroll to **Assets** on that release page and take the file ending in `-Release.zip`. Ignore the `-Debug.zip` build and ignore anything labelled `canary` — those are test builds.

> [!CAUTION]
> **Do not use v2.1.** It shipped with a bug where modules load but no hooks take effect. v2.2 is the fix. Take the `Release` asset, not `Debug`.

`Manual · pendrive`

Download the release zip on your computer, put it in a folder named `mod` on a pendrive, and plug it into the **centre console USB socket**.

**UART** — ROLLBACK — removes Vector entirely
```bash
rm -rf /data/adb/modules/zygisk_vector
reboot
```

**UART** — Install the module, then reboot
```bash
magisk --install-module /mnt/media_rw/*/mod/Vector-*-Release.zip
```

Every file is checksum-verified during install. After rebooting, confirm the framework is alive:

**UART** — Verify the framework
```bash
/data/adb/modules/zygisk_vector/cli status
```

You should get the framework version, the API version, and `Enabled Modules: 0`.

> [!TIP]
> **Use the CLI, not the manager app.** Vector ships a command line tool at `/data/adb/modules/zygisk_vector/cli` with `status`, `modules`, `scope`, `config`, `db` and `log` subcommands. On this head unit that matters — the ECarX launcher kills foreground apps that are not on its whitelist, so driving everything from UART avoids a fight you do not need to have.

## Step 8 — Build the Module

`WSL Ubuntu`

The builder below is self-contained. It creates the apktool project, writes the manifest, the resources, the Xposed entry point and the hook class, builds the APK, creates a signing key on first run, then signs and aligns it.

> [!TIP]
> **Get the builder:** [scripts/build-steering-mod.sh](../scripts/build-steering-mod.sh) (~18 KB). Open it on GitHub and use the **Download raw file** button at the top right of the file view.

Read it before you run it — it is plain bash, and [8.3](#83--the-full-source) explains where to find every part.

### 8.1 — Get the script into your Linux / WSL home folder

If you downloaded it on Windows it will be in your Downloads folder, which WSL reads through `/mnt/c`. First find your Windows username:

**WSL** — List Windows users
```bash
ls /mnt/c/Users/
```

Ignore `All Users`, `Default`, `Public` and `desktop.ini` — those are Windows system entries. Whatever is left is your username.

> [!TIP]
> If OneDrive is backing up your Downloads folder, the file lands in `C:\Users\NAME\OneDrive\Downloads` instead of `C:\Users\NAME\Downloads`. Use the path that matches where the file actually is — get it wrong and the copy below stops with "No such file or directory".

Now copy it across, replacing `YOUR_USERNAME` with your own Windows username:

**WSL** — Copy from the Windows Downloads folder
```bash
cp /mnt/c/Users/YOUR_USERNAME/Downloads/build-steering-mod.sh ~/
```

**WSL** — Same, if OneDrive backs up your Downloads folder
```bash
cp /mnt/c/Users/YOUR_USERNAME/OneDrive/Downloads/build-steering-mod.sh ~/
```

Prefer to paste it instead? Open the script on GitHub, use the **Copy raw file** button, then create the file by hand, paste, and press `Ctrl+D` to finish:

**WSL** — Paste the source into a new file
```bash
cat > ~/build-steering-mod.sh
```

### 8.2 — Run it

**WSL** — Build, sign and align in one go
```bash
cd ~
bash build-steering-mod.sh
```

Running it with `bash` means you never need `chmod +x`. The script checks that `apktool`, `jarsigner`, `zipalign` and `keytool` are all on your PATH and stops with a clear message if one is missing, so a failure here is a missing tool, not a broken script.

**Output** — A successful build ends like this
```text
== building ==
I: Built apk into: /home/you/SWMod.apk
== signing ==
jar signed.
== aligning ==

DONE -> /home/you/SWMod-signed.apk
```

> [!WARNING]
> **Two harmless warnings you will see.** apktool may print `Could not extract resource /prebuilt/linux/aapt_64 (defaulting to $PATH binary)`, and jarsigner will say `The signer's certificate is self-signed`. Both are expected. A self-signed certificate is exactly right here — this is your own module, not something that needs to match a vendor key.

The file you want is `~/SWMod-signed.apk`, roughly 90 KB. Copy it to your pendrive for [Step 9](#step-9--install--activate).

> [!WARNING]
> **If apktool rejects apktool.yml:** the metadata format changes between apktool major versions and the script targets 2.x. If yours complains, run `apktool d` on any small APK, copy the `apktool.yml` it produces into `~/SWMod/`, and run the build again.

### 8.3 — The full source

`Reference`

**Nothing here needs to be run.** The complete builder lives in [scripts/build-steering-mod.sh](../scripts/build-steering-mod.sh) — the same file you copied in 8.1. It writes, in order:

| Part | What it is |
|---|---|
| `apktool.yml` | apktool 2.x project metadata |
| `AndroidManifest.xml` | Declares the package `com.protons70.swmod` as an Xposed module |
| `res/values/arrays.xml` | The module scope: `com.malaysia.voicemaster` and `com.malaysia.btphone` |
| `assets/xposed_init` | Points the framework at the hook class |
| `smali/com/protons70/swmod/Hook.smali` | The hook itself, described in the table below |

It then builds with apktool, creates `~/swmod.keystore` on first run, and signs and aligns the APK.

### What the hook actually does

One class handles both apps and tells them apart with a per-process flag, since the module class is loaded separately in each hooked process.

| Where | Method | Behaviour |
|---|---|---|
| voicemaster | onHkShortPress(200231) | Block the original — this is what kills the voice wake-up — and cycle the drive mode instead |
| voicemaster | onHkLongPress(200231) | Block the original, then call the app's own short-press method so voice still works |
| voicemaster | onHkLongPress(200005) | Open the 360 camera |
| btphone | onHkLongPress(200005) | Swallow it, so no call is placed |

> [!TIP]
> **The long-press-wakes-voice trick is worth calling out.** Rather than reimplementing whatever the voice stack does, the hook sets a one-shot bypass flag and re-invokes the app's own short-press method. Our hook sees the flag, steps aside exactly once, and the stock code runs untouched. You never need to understand the voice implementation at all.

Actions are performed with `startActivity` and `sendBroadcast` through the app's own Context rather than by shelling out to `am`. These apps run in the system domain, where spawning a shell is liable to be refused by SELinux.

## Step 9 — Install & Activate

`UART · PuTTY`

Copy `SWMod-signed.apk` into the `mod` folder on the pendrive and plug it back into the centre console socket.

**UART** — Install the module APK
```bash
pm install -r /mnt/media_rw/*/mod/SWMod-signed.apk
```

An `avc: denied ... permissive=1` line may appear. That is a permissive-mode SELinux notice, not an error — `Success` is what matters.

**UART** — Enable the module
```bash
/data/adb/modules/zygisk_vector/cli modules enable com.protons70.swmod
```

**UART** — Set which apps it is injected into
```bash
/data/adb/modules/zygisk_vector/cli scope set com.protons70.swmod com.malaysia.voicemaster/0 com.malaysia.btphone/0
```

> [!WARNING]
> **Scope is not applied automatically from the manifest.** The module declares its scope, but Vector still starts with it empty. Set it explicitly with the command above, then `reboot`. A module with no scope is enabled and does absolutely nothing, which is a confusing way to lose an hour.

### Confirm the hooks landed

**UART** — Read the framework log
```bash
/data/adb/modules/zygisk_vector/cli log cat | grep -F "SWMod"
```

**Output** — What a healthy install looks like
```text
SWMod: btphone onHkLongPress hooks = 1
SWMod: voicemaster hooks installed
SWMod: voicemaster hooks installed
```

voicemaster appears twice because it runs two processes. If the btphone count is `0`, the method is not where we expect on your firmware — the module logs the number on purpose so you can tell without guessing.

> [!CAUTION]
> **Xposed logs do not go to logcat.** `XposedBridge.log` output lands in Vector's own log under the tag `VectorLegacyBridge`, reachable only through `cli log cat`. Searching logcat for your module finds nothing and makes you think the hook failed.

## Step 10 — Test

`In the Car`

Car parked, handbrake up, engine running. Pair a phone over Bluetooth **before** testing the call button — the redial problem only shows up when a phone is connected, so testing without one gives you a false pass.

| # | Do this | Expected |
|---|---|---|
| 1 | Hi Proton, short press | Drive mode changes. No voice. |
| 2 | Hi Proton, short press ×3 | Each press advances one mode — Comfort → ECO → Sport → back to Comfort |
| 3 | Hi Proton, hold 2s | Voice assistant wakes normally |
| 4 | Call button, hold 2s | 360 camera opens. **No call placed.** |
| 5 | Call button, short press | Phone / dialler, unchanged |

## Step 11 — Restore to Stock

`Rollback · Deletes Things`

> [!CAUTION]
> **Stop — read this before you copy anything**
>
> **This step is the undo. Nothing on this page installs or repairs the mod.** The commands below switch the remap off and then delete it — the module, its APK, and in the last block the Xposed framework and Zygisk as well. If you came here for the build, you want [Step 8](#step-8--build-the-module). If a button is misbehaving, try [Fix Fast](#fix-fast) first.
>
> **Only run these if every line below is true:**
>
> - You genuinely want the steering wheel buttons back to stock — short press on `Hi Proton` goes back to voice, and the call button stops opening the 360 camera.
> - You accept the deletions. The second block removes the module APK; the third wipes `/data/adb/modules/zygisk_vector` and turns Zygisk off.
> - **Any other Xposed module you run dies with it.** Vector is the framework they all load through — removing it disables every module on the unit, not just this one.
> - Your UART cable is connected and you can get a root shell, so a reboot that misbehaves is recoverable.
>
> **Not sure?** Run only the first block. Disabling is fully reversible — `enable` brings the mod straight back, with nothing to rebuild or reinstall. Stop there and nothing is lost.

Three levels, depending on how far back you want to go. They are ordered gentlest first — run only as far down as you actually need to go. None of them require restoring a backup, because nothing was overwritten in the first place.

### Turn the mod off, keep everything installed (Reversible)

**UART** — Instant undo
```bash
/data/adb/modules/zygisk_vector/cli modules disable com.protons70.swmod
```

Buttons return to stock behaviour. Re-enable any time with `enable` in place of `disable`.

### Remove the module completely (Deletes the APK)

**UART** — Uninstall the module APK
```bash
pm uninstall com.protons70.swmod
```

### Remove the framework and Zygisk too (Point of no return)

> [!CAUTION]
> **Last stop.** This block is not about this mod any more — it takes the whole Xposed layer off the unit. Every module you have installed through Vector stops working, and getting back means redoing [Step 6](#step-6--enable-zygisk) and [Step 7](#step-7--install-the-xposed-framework). Skip it unless you want a plain rooted head unit again.

**UART** — Back to a plain rooted unit
```bash
rm -rf /data/adb/modules/zygisk_vector
magisk --sqlite "REPLACE INTO settings (key,value) VALUES('zygisk',0)"
reboot
```

> [!TIP]
> **Why there is nothing else to undo.** No stock APK was modified, so there is no file to put back. `/system` is byte-for-byte as it shipped. The only persistent traces of this project are the Zygisk setting, the Vector module directory, and one APK in `/data/app` — all three removed by the commands above.

## Fix Fast

`Troubleshoot`

| Symptom | Cause and fix |
|---|---|
| Module not listed by **cli modules ls** | The APK did not install. Re-run `pm install -r` and check it reports `Success`. |
| Module enabled but nothing changes | Scope is empty. Run `cli scope ls com.protons70.swmod` — it must list both packages. Set it, then reboot. |
| No SWMod lines in the log | You are probably searching logcat. Use `cli log cat` instead. |
| btphone onHkLongPress hooks = 0 | The method sits elsewhere on your firmware. Trace it with the [Step 4](#step-4--trace-any-button-yourself) filter and note which class the log prints. |
| Camera opens *and* the car dials someone | btphone is not in scope, or its hook count is 0. Both must be true for the redial to be suppressed. |
| Voice no longer wakes at all | Disable the module, confirm stock behaviour returns, then check that `onHkLongPress` hooked successfully in voicemaster. |
| Unit will not boot after enabling Zygisk | UART in and run the Zygisk rollback from [Step 6](#step-6--enable-zygisk). Magisk's bootloop protection may also have disabled modules for you already. |

## Project Notes

`Known Limitations`

- **The drive mode counter can desync.** The cycle is tracked by a counter inside the module, so changing drive mode from the IHU screen leaves the counter out of step and the next press may jump to an unexpected mode. It corrects itself after cycling through. Reading the current mode instead of counting would fix it properly.
- **Firmware updates will reset this.** A system update replaces the apps and may move the classes. Re-run the trace in [Step 4](#step-4--trace-any-button-yourself) and adjust the class names before rebuilding.
- **Other subscribers still receive the key.** Screensaver, control board and notification centre also get `onHkLongPress`. They happen to do nothing visible here, but if you remap a different button, check what else reacts to it first.
- **Tested on one car.** Proton S70 Flagship, firmware V333. Other variants very likely differ in class names, and possibly in key ids — which is exactly what [Step 4](#step-4--trace-any-button-yourself) is for.

> [!WARNING]
> **Updating the module later:** rebuild, copy the new APK across, and `pm install -r` over the top. The module stays enabled and keeps its scope — only a reboot, or restarting the hooked apps, is needed for the new code to take effect.
