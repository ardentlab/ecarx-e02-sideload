# Steering Wheel Button Remap — Drive Mode & 360 Camera

Short press `Hi Proton` to change drive mode. Hold it and the voice assistant still comes up. Hold the call button to open the 360 camera. A short press still answers calls. The apps are hooked while they run, so no system file is changed and one command undoes everything.

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

Only these steps change anything on the unit. Do them in order and the buttons will work at the end.

- [Step 1](#step-1--prerequisites) — **Prerequisites.** Rooted unit, UART access, and WSL with the four build tools — skip 1.2 if you already have them.
- [Step 6](#step-6--enable-zygisk) — **Enable Zygisk** in Magisk, then reboot.
- [Step 7](#step-7--install-the-xposed-framework) — **Install Vector**, the Xposed framework the module loads through, then reboot.
- [Step 8](#step-8--build-the-module) — **Build the module APK** with the one-shot builder script.
- [Step 9](#step-9--install--activate) — **Install and activate it** — install the APK, set its scope, reboot.
- [Step 10](#step-10--test) — **Test in the car**, parked, with a phone paired.

**Everything else is there to read, not to run.** [Step 0](#step-0--what-you-get) shows what you get. [Steps 2](#step-2--how-the-steering-buttons-actually-work) and [3](#step-3--why-the-stock-apps-are-not-patched) explain why it works this way. [Step 4](#step-4--trace-any-button-yourself) shows how to find a different button yourself. [Step 5](#step-5--reference-values) lists the values this guide already found. [Fix Fast](#fix-fast) is for when something goes wrong. [Step 11](#step-11--restore-to-stock) removes the mod — only run it if you want it gone.

## Step 0 — What You Get

`Overview`

Two steering wheel buttons get a new job when you hold them. On **Hi Proton**, voice moves from a short press to a hold, and the short press now changes drive mode instead. On the call button nothing changes on a short press — holding it opens the 360 camera.

| Button | Short press | Hold ~2 seconds |
|---|---|---|
| **Hi Proton** | **Cycle drive mode** — Comfort → ECO → Sport → back to Comfort | Voice assistant, exactly as stock |
| **Pick up call** | Answer call / dialler, exactly as stock | 360 camera |

> [!TIP]
> **Nothing in /system is touched.** No stock APK is patched, replaced or re-signed. The changes happen in memory while the apps are running. That is why the undo is one command and there is no backup to restore — /system stays exactly as it shipped.

The same method works for any steering button on this platform. [Step 4](#step-4--trace-any-button-yourself) shows how to find the values yourself instead of trusting the ones in this guide.

## Step 1 — Prerequisites

`Hardware + Software`

**1.1 — What you need**

| What | Why |
|---|---|
| **Rooted IHU with Magisk** | Written on Magisk 30.7. Magisk 26+ is the minimum. |
| **UART / PuTTY root access** | 921600 baud. This is also how you fix things if something goes wrong, so do not skip it. |
| **Linux or WSL machine** | Needs `apktool`, `jarsigner`, `zipalign` and `keytool` on PATH — 1.2 below installs all four. |
| **USB pendrive** | To move files between your PC and the car. Only the centre console socket is wired to the head unit. Every other USB port in the car only charges. |

**1.2 — Install WSL & its tools**

> [!TIP]
> **Already have WSL and the tools? Skip the whole of 1.2.** Run `wsl -l -v` in PowerShell, then `which apktool jarsigner zipalign keytool` inside Ubuntu. If the first lists an Ubuntu distro and the second prints four paths, your machine is ready. Go straight to [Step 6](#step-6--enable-zygisk). There is nothing here to reinstall, update or repeat.

If you do not have it: the build runs inside Ubuntu, so install it first. Run this in **PowerShell as Administrator**, then restart Windows.

**PowerShell** — Install Ubuntu WSL
```text
wsl --install
```

Then open Ubuntu and install the four tools the builder in [Step 8](#step-8--build-the-module) needs. They all come from the Ubuntu archive. Nothing to download by hand, and no Android Studio:

**WSL** — Install the build toolchain
```bash
sudo apt-get update
sudo apt-get install -y apktool zipalign openjdk-17-jdk-headless
```

| Package | What it gives you |
|---|---|
| **apktool** | `apktool` — builds the module project into an unsigned APK. |
| **zipalign** | `zipalign` — aligns the signed APK. This is the last step before you can install it. |
| **openjdk-17-jdk-headless** | `jarsigner` and `keytool` — signs the APK and makes the signing key the first time you run it. The JRE is not enough. `jarsigner` only comes with the JDK. |

Check all four are on your PATH before you carry on. The builder stops with an error if one is missing:

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
> **Use the version apt gives you.** This was written on Ubuntu 24.04 in WSL2, where `apt` installs apktool 2.7. The builder writes an **apktool 2.x** project file, so that is the version you want. If you install 3.x by hand it complains about `apktool.yml` instead. [Step 8](#step-8--build-the-module) has the fix if that happens.

> [!CAUTION]
> **Safety:** test with the car **parked, handbrake up, engine running**. Never while driving. These are steering wheel buttons, so take it seriously. Do not test the call button before you read [Step 9](#step-9--install--activate) — with a phone paired, holding it dials the last number.

## Step 2 — How the Steering Buttons Actually Work

`How It Works`

Read this before you change anything. It explains why the obvious approach does not work.

The steering buttons are **not** normal Android input. They never show up in `getevent`. They come in as CAN bus signals. The car input service turns them into Android key events and hands them to a dispatcher app, which sends them out to every app that asked for them:

**Reference** — Signal path
```text
CAN bus
  -> CarInputService              (keyCode 298 / 299)
  -> com.malaysia.ConnectService  (maps to internal id, classifies press type)
  -> 12 subscriber apps           (voicemaster, btphone, screensaver, ...)
```

Every app that receives them has the same three methods:

**Reference** — The callback trio
```text
onHkShortPress(int keyId)
onHkLongPress(int keyId)
onHkRelease(int keyId)
```

> [!TIP]
> **This is the whole idea behind the project.** To change a button, you intercept one of those three methods in the app that currently acts on that key. This works for every steering button on this platform, not just the two covered here.

> [!WARNING]
> **A long press already does something.** Holding a button is not an empty slot. Several apps already receive `onHkLongPress` and act on it. The call button redials the last number when a phone is paired. So a long-press mod has to block the old action as well as add the new one, or you get both at the same time.

## Step 3 — Why the Stock Apps Are Not Patched

`Important`

The obvious idea is to decompile the app that handles the button, edit it, and put it back. On this platform that does not work. Here is the quick check that tells you why, before you break anything:

**UART** — Become root
```bash
su
```

**UART** — Is this app platform-signed?
```bash
dumpsys package com.malaysia.btphone | grep -E "userId|sharedUser|pkgFlags|codePath"
```

Both apps we need answer like this:

**Output** — The blocker
```text
userId=1000
sharedUser=SharedUserSetting{android.uid.system/1000}
codePath=/system/app/BTPhone
```

> [!CAUTION]
> **android.uid.system** means the app runs with the system identity. To do that it has to be signed with the manufacturer's private platform key, which you do not have. Sign it with your own key and it will not load — and your Bluetooth phone stops working. `com.malaysia.voicemaster` is the same. Run this check on any app before you plan to patch it.

So we do not edit the apps. We hook them while they run, using an Xposed framework. The APK files on disk are never touched.

## Step 4 — Trace Any Button Yourself

`UART · PuTTY`

You do not have to trust the values in this guide. And if you want to remap a different button, this is how you find its values.

### 4.1 — Watch the buttons

**UART** — Become root
```bash
su
```

**UART** — Clean button trace — press a button after running this
```bash
logcat -c && logcat -v time | grep -E "KeyInput|onHk|CarInputListener|KeyPressed"
```

Nothing appears until you press a steering button. Then you see the raw keycode, the internal id, which apps it went to, and which app's `onHk*` method ran, with its full class name.

> [!CAUTION]
> **Words that will flood your screen.** Never grep logcat for `avm`, `Dynamic` or `Camera` on this unit. `avm` matches the 360 camera daemon and `Dynamic` matches the audio ring buffer. Both log non-stop and will bury what you are looking for. Use exact tag names, case-sensitive, like the command above.

> [!WARNING]
> **getevent will not help here.** Steering buttons never reach the Linux input layer, so an empty `getevent` is normal, not a fault. Do not spend an hour on it like we did.

### 4.2 — Find what an on-screen action sends

To find out how to trigger something yourself, drive mode for example, watch the log while you do it the normal way on the screen:

**UART** — Watch activity launches and intents
```bash
logcat -c && logcat -v time | grep -E "START u0|Displayed"
```

The intent and component name show up in the log. You can replay them from the shell to check they work before you write any code.

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

You can test both actions from the shell before you build anything. It is a quick way to check that your unit matches this guide.

**UART** — Become root
```bash
su
```

**UART** — Open the 360 camera
```bash
am start -n ecarx.camera.calibration/.MainActivity
```

**UART** — Switch to Sport mode
```bash
am broadcast -a ecarx.settings.vehicle.setting.widget.CarSettingWidget.action.ACTION_CLICK -n ecarx.settings/.vehicle.setting.widget.DriveModeSportWidget
```

> [!WARNING]
> **The 360 camera app has a confusing name.** `ecarx.camera.calibration` sounds like a factory calibration tool, but it is the real 360 view. No package on the unit has "avm", "360" or "surround" in its name. The image itself comes from a native daemon that has no Android activity of its own.

## Step 6 — Enable Zygisk

`UART · PuTTY`

Zygisk is the part of Magisk that lets an Xposed framework load. It is off by default.

**UART** — Become root — before anything else in this step
```bash
su
```

The UART shell starts as a normal user, and **the rollback below needs root as well**, so run `su` before anything else. The prompt changes from `$` to `#`. Every reboot puts you back to a normal user, so run `su` again each time you reconnect.

> [!CAUTION]
> **This is the first step that changes how the unit boots.** Everything before this only read things. Copy the rollback below and keep it somewhere you can reach without the car screen, then carry on.

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

## Step 7 — Install the Xposed Framework

`UART · PuTTY`

The original LSPosed is archived and no longer updated. Its replacement is **Vector**, from the same developer who kept the LSPosed fork going. Vector v2.2 works on Android 8.1 to 17 and needs Magisk 26+ with Zygisk. The S70 is well inside that range.

| What to download | Where |
|---|---|
| **Vector v2.2 — Release zip** — filename looks like `Vector-v2.2-3080-Release.zip` (~9 MB) | [github.com/JingMatrix/Vector — v2.2 release](https://github.com/JingMatrix/Vector/releases/tag/v2.2) All releases: [/releases](https://github.com/JingMatrix/Vector/releases) |

Scroll to **Assets** on that release page and take the file ending in `-Release.zip`. Skip the `-Debug.zip` file and skip anything marked `canary`. Those are test builds.

> [!CAUTION]
> **Do not use v2.1.** It has a bug where modules load but no hooks actually run. v2.2 fixes it. Take the `Release` file, not `Debug`.

`Manual · pendrive`

Download the release zip on your computer, put it in a folder named `mod` on a pendrive, and plug it into the **centre console USB socket**.

**UART** — Become root — the Step 6 reboot reset your shell
```bash
su
```

You rebooted at the end of Step 6, so you are a normal user again. Become root first. Both the rollback and the install below need it.

**UART** — ROLLBACK — removes Vector entirely
```bash
rm -rf /data/adb/modules/zygisk_vector
reboot
```

**UART** — Install the module, then reboot
```bash
magisk --install-module /mnt/media_rw/*/mod/Vector-*-Release.zip
reboot
```

Magisk checks every file against its checksum while it installs. The framework only loads after the unit comes back up, so the reboot is part of the install, not optional. When it is back, reconnect UART and become root again before you check:

**UART** — Become root — again, after the reboot
```bash
su
```

**UART** — Verify the framework
```bash
/data/adb/modules/zygisk_vector/cli status
```

You should get the framework version, the API version, and `Enabled Modules: 0`.

> [!TIP]
> **Use the CLI, not the manager app.** Vector comes with a command line tool at `/data/adb/modules/zygisk_vector/cli`. It has `status`, `modules`, `scope`, `config`, `db` and `log` commands. This matters on this head unit: the ECarX launcher closes any app that is not on its whitelist, so the manager app keeps getting killed. Doing everything from UART avoids that.

## Step 8 — Build the Module

`WSL Ubuntu`

The builder below does everything on its own. It creates the apktool project, writes the manifest, the resources, the Xposed entry point and the hook class, builds the APK, makes a signing key the first time you run it, then signs and aligns the APK.

> [!TIP]
> **Get the builder:** [scripts/build-steering-mod.sh](../scripts/build-steering-mod.sh) (~18 KB). Open it on GitHub and use the **Download raw file** button at the top right of the file view.

Read it before you run it — it is plain bash, and [8.3](#83--the-full-source) explains where to find every part.

### 8.1 — Get the script into your Linux / WSL home folder

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
cp /mnt/c/Users/YOUR_USERNAME/Downloads/build-steering-mod.sh ~/
```

**WSL** — Same, if OneDrive backs up your Downloads folder
```bash
cp /mnt/c/Users/YOUR_USERNAME/OneDrive/Downloads/build-steering-mod.sh ~/
```

Rather paste it? Open the script on GitHub, use the **Copy raw file** button, then make the file by hand, paste, and press `Ctrl+D` to finish:

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

Running it with `bash` means you never need `chmod +x`. The script checks that `apktool`, `jarsigner`, `zipalign` and `keytool` are all on your PATH, and stops with a clear message if one is missing. So if it fails here, a tool is missing — the script is not broken.

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
> **Two warnings you can ignore.** apktool may print `Could not extract resource /prebuilt/linux/aapt_64 (defaulting to $PATH binary)`, and jarsigner will say `The signer's certificate is self-signed`. Both are normal. A self-signed certificate is the right thing here. This is your own module, not something that has to match a vendor key.

The file you want is `~/SWMod-signed.apk`, roughly 90 KB. Copy it to your pendrive for [Step 9](#step-9--install--activate).

> [!WARNING]
> **If apktool rejects apktool.yml:** the format of that file changes between apktool major versions, and the script writes the 2.x format. If yours complains, run `apktool d` on any small APK, copy the `apktool.yml` it produces into `~/SWMod/`, and build again.

### 8.3 — The full source

`Reference`

**You do not need to run anything here.** The complete builder lives in [scripts/build-steering-mod.sh](../scripts/build-steering-mod.sh) — the same file you copied in 8.1. It writes, in order:

| Part | What it is |
|---|---|
| `apktool.yml` | apktool 2.x project metadata |
| `AndroidManifest.xml` | Declares the package `com.protons70.swmod` as an Xposed module |
| `res/values/arrays.xml` | The module scope: `com.malaysia.voicemaster` and `com.malaysia.btphone` |
| `assets/xposed_init` | Points the framework at the hook class |
| `smali/com/protons70/swmod/Hook.smali` | The hook itself, described in the table below |

It then builds with apktool, creates `~/swmod.keystore` the first time you run it, and signs and aligns the APK.

### What the hook actually does

One class handles both apps. It tells them apart with a flag, because the module class is loaded separately inside each app it hooks.

| Where | Method | Behaviour |
|---|---|---|
| voicemaster | onHkShortPress(200231) | Block the original, which is what stops voice waking up, and change the drive mode instead |
| voicemaster | onHkLongPress(200231) | Block the original, then call the app's own short-press method so voice still works |
| voicemaster | onHkLongPress(200005) | Open the 360 camera |
| btphone | onHkLongPress(200005) | Drop it, so no call is made |

> [!TIP]
> **How holding the button still wakes voice.** Instead of rebuilding whatever the voice stack does, the hook sets a one-time bypass flag and calls the app's own short-press method again. The hook sees the flag, stands aside once, and the stock code runs as normal. You never have to understand how voice works.

The actions use `startActivity` and `sendBroadcast` through the app's own Context, not the `am` shell command. These apps run in the system domain, where SELinux often blocks starting a shell.

## Step 9 — Install & Activate

`UART · PuTTY`

Copy `SWMod-signed.apk` into the `mod` folder on the pendrive and plug it back into the centre console socket.

**UART** — Become root — first command here
```bash
su
```

**UART** — Install the module APK
```bash
pm install -r /mnt/media_rw/*/mod/SWMod-signed.apk
```

You may see a line like `avc: denied ... permissive=1`. That is an SELinux notice in permissive mode, not an error. What matters is that it says `Success`.

**UART** — Enable the module
```bash
/data/adb/modules/zygisk_vector/cli modules enable com.protons70.swmod
```

**UART** — Set which apps it is injected into
```bash
/data/adb/modules/zygisk_vector/cli scope set com.protons70.swmod com.malaysia.voicemaster/0 com.malaysia.btphone/0
```

> [!WARNING]
> **Vector does not read the scope from the module.** The module says which apps it wants, but Vector starts with an empty list. You have to set it yourself with the command above, then reboot. With no scope the module is on but does nothing, which is an easy way to lose an hour.

**UART** — Reboot — hooks load on the next boot
```bash
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
/data/adb/modules/zygisk_vector/cli log cat | grep -F "SWMod"
```

**Output** — What a healthy install looks like
```text
SWMod: btphone onHkLongPress hooks = 1
SWMod: voicemaster hooks installed
SWMod: voicemaster hooks installed
```

voicemaster appears twice because it runs as two processes. If the btphone count is `0`, the method is not where we expect it on your firmware. The module prints that number on purpose, so you can tell without guessing.

> [!CAUTION]
> **Xposed logs do not go to logcat.** `XposedBridge.log` writes to Vector's own log, under the tag `VectorLegacyBridge`. You can only read it with `cli log cat`. If you search logcat for your module you find nothing and think the hook failed.

## Step 10 — Test

`In the Car`

Car parked, handbrake up, engine running. Pair a phone over Bluetooth **before** you test the call button. The redial problem only happens when a phone is connected, so testing without one looks fine when it is not.

| # | Do this | Expected |
|---|---|---|
| 1 | Hi Proton, short press | Drive mode changes. No voice. |
| 2 | Hi Proton, short press ×3 | Each press moves one mode — Comfort → ECO → Sport → back to Comfort |
| 3 | Hi Proton, hold 2s | Voice assistant wakes normally |
| 4 | Call button, hold 2s | 360 camera opens. **No call placed.** |
| 5 | Call button, short press | Phone / dialler, unchanged |

## Step 11 — Restore to Stock

`Rollback · Deletes Things`

> [!CAUTION]
> **Stop — read this before you copy anything**
>
> **This step is the undo. Nothing here installs or repairs the mod.** The commands below turn the remap off and then delete it — the module, its APK, and in the last block the Xposed framework and Zygisk too. If you came here to build, you want [Step 8](#step-8--build-the-module). If a button is behaving strangely, try [Fix Fast](#fix-fast) first.
>
> **Only run these if every line below is true:**
>
> - You really want the buttons back to stock. A short press on `Hi Proton` goes back to voice, and the call button stops opening the 360 camera.
> - You are fine with the deletions. The second block removes the module APK. The third deletes `/data/adb/modules/zygisk_vector` and turns Zygisk off.
> - **Any other Xposed module you use stops working too.** They all load through Vector, so removing it disables every module on the unit, not just this one.
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
/data/adb/modules/zygisk_vector/cli modules disable com.protons70.swmod
reboot
```

The hooks are already inside the running apps, so they keep working until those apps restart. Reboot and the buttons are back to stock. Turn it back on any time with `enable` instead of `disable`.

### Remove the module completely (Deletes the APK)

**UART** — Uninstall the module APK, then reboot
```bash
pm uninstall com.protons70.swmod
reboot
```

### Remove the framework and Zygisk too (Point of no return)

> [!CAUTION]
> **Last stop.** This block is not about this mod any more. It removes the whole Xposed layer from the unit. Every module you installed through Vector stops working, and getting it back means doing [Step 6](#step-6--enable-zygisk) and [Step 7](#step-7--install-the-xposed-framework) again. Skip this unless you want a plain rooted head unit back.

**UART** — Back to a plain rooted unit
```bash
rm -rf /data/adb/modules/zygisk_vector
magisk --sqlite "REPLACE INTO settings (key,value) VALUES('zygisk',0)"
reboot
```

> [!TIP]
> **Why there is nothing else to undo.** No stock APK was changed, so there is no file to put back. `/system` is exactly as it shipped. This project leaves only three things behind: the Zygisk setting, the Vector module folder, and one APK in `/data/app`. The commands above remove all three.

## Fix Fast

`Troubleshoot`

| Symptom | Cause and fix |
|---|---|
| Module not listed by **cli modules ls** | The APK did not install. Re-run `pm install -r` and check it reports `Success`. |
| Module enabled but nothing changes | Scope is empty. Run `cli scope ls com.protons70.swmod` — it must list both packages. Set it, then reboot. |
| No SWMod lines in the log | You are probably searching logcat. Use `cli log cat` instead. |
| btphone onHkLongPress hooks = 0 | The method is somewhere else on your firmware. Trace it with the [Step 4](#step-4--trace-any-button-yourself) filter and note which class the log prints. |
| Camera opens *and* the car dials someone | btphone is not in scope, or its hook count is 0. Both have to be right before the redial is blocked. |
| Voice no longer wakes at all | Disable the module and check that voice comes back. Then check that `onHkLongPress` hooked successfully in voicemaster. |
| Unit will not boot after enabling Zygisk | Connect UART and run the Zygisk rollback from [Step 6](#step-6--enable-zygisk). Magisk's bootloop protection may have turned the modules off for you already. |

## Project Notes

`Known Limitations`

- **The drive mode counter can go out of step.** The module keeps its own counter to track the cycle. If you change drive mode from the IHU screen, the counter no longer matches, and the next press may jump to a mode you did not expect. It sorts itself out once you cycle through. Reading the current mode instead of counting would fix it properly.
- **A firmware update will undo this.** A system update replaces the apps and may move the classes. Run the trace in [Step 4](#step-4--trace-any-button-yourself) again and update the class names before you rebuild.
- **Other apps still receive the key.** Screensaver, control board and notification centre also get `onHkLongPress`. They do nothing visible here, but if you remap a different button, check what else reacts to it first.
- **Tested on one car.** Proton S70 Flagship, firmware V333. Other variants will probably have different class names, and maybe different key ids. That is what [Step 4](#step-4--trace-any-button-yourself) is for.

> [!WARNING]
> **Updating the module later:** rebuild it, copy the new APK across, and `pm install -r` over the top. The module stays enabled and keeps its scope. You only need a reboot, or to restart the hooked apps, for the new code to take effect.
