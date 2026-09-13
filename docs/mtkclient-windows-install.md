# Install MTKClient from Source on Windows

Get upstream `bkerler/mtkclient` running against an ECarX E02 head unit. The official Windows README gets you most of the way, then leaves you stuck on two things it never mentions: the Python PATH trap on Windows 11, and a bug in the 2.1.4 GUI that loops `Handshake failed, retrying` forever on any device whose USB port does not re-enumerate. Both are fixed here.

**Platform:** Windows 11 · **Source:** bkerler/mtkclient · **Version:** 2.1.4 · **Target:** ECarX E02 (MT6771) · **Time:** ~15 min

---

## Contents

- [Step 0 — Overview](#step-0--overview)
- [Step 1 — What You Need](#step-1--what-you-need)
- [Step 2 — Python & Git](#step-2--python--git)
- [Step 3 — Fix the PATH Trap](#step-3--fix-the-path-trap)
- [Step 4 — Clone & Install](#step-4--clone--install)
- [Step 5 — USB Driver](#step-5--usb-driver)
- [Step 6 — Patch the Double-Init Bug](#step-6--patch-the-double-init-bug)
- [Step 7 — One-Click Launcher](#step-7--one-click-launcher)
- [Step 8 — Enter BROM](#step-8--enter-brom)
- [Step 9 — Verify](#step-9--verify)
- [Fix Fast](#fix-fast)
- [Project Notes](#project-notes)

---

## Step 0 — Overview

`Read First`

This guide installs the original [bkerler/mtkclient](https://github.com/bkerler/mtkclient) from source on Windows and gets it talking to an ECarX E02 head unit. It is the tool you use to dump and flash partitions; everything else in the sideload workflow assumes it already works.

> [!WARNING]
> **Why not just follow README-WINDOWS.md?** Because it stops short. Follow it exactly and you still land on two walls that have nothing to do with your hardware:
>
> - **Python is installed but Windows cannot find it.** Not a missing install — a PATH checkbox and a Microsoft Store stub, covered in [Step 3](#step-3--fix-the-path-trap).
> - **The GUI connects, reads your chip, then loops forever.** A real bug in `mtk_gui.py` 2.1.4, covered in [Step 6](#step-6--patch-the-double-init-bug). This one costs people entire evenings and gets misdiagnosed as bad wiring, a bad cable, or a dead unit.

**What "working" looks like at the end:**

**Output** — The two lines that mean you are done
```text
Preloader - Jumping to 0x200000
Preloader - Jumping to 0x200000: ok.
```

…with the partition list populated in the **Read partition(s)** tab. Anything short of that, see [Fix Fast](#fix-fast).

> [!TIP]
> **Scope.** This guide gets the tool running and connected. It does not flash anything. Erasing, unlocking and writing partitions belong to the [sideload guide](./sideload.md) — do not run those until this guide ends cleanly.

## Step 1 — What You Need

`Hardware + Software`

### 1.1 — Software

| Item | Version | Notes |
|---|---|---|
| Python | 3.9 or newer | [python.org/downloads](https://www.python.org/downloads/) — take the latest **Windows installer (64-bit)**. **Not** the Microsoft Store build; see [Step 2](#step-2--python--git) for why that one bites. |
| Git for Windows | any current | [git-scm.com/download/win](https://git-scm.com/download/win) — the **64-bit standalone installer**. Click through with the defaults; none of the options matter here. |
| UsbDk Runtime Libraries | 1.0.22 x64 | [github.com/daynix/UsbDk/releases](https://github.com/daynix/UsbDk/releases) — download `UsbDk_1.0.22_x64.msi`. This is what lets mtkclient claim the BROM USB endpoint. |
| MTKClient source | 2.1.4 or later | [github.com/bkerler/mtkclient](https://github.com/bkerler/mtkclient) — nothing to download by hand; you clone it in [Step 4](#step-4--clone--install). The official Windows notes live in [README-WINDOWS.md](https://github.com/bkerler/mtkclient/blob/main/README-WINDOWS.md). |

Every command in this guide runs in **Command Prompt** — that is what the **Windows CMD** tag on each block means. There is nothing to install; it ships with Windows (`WIN+R` → `cmd` → Enter). **Do not substitute PowerShell.** Windows PowerShell writes redirected output as UTF-16, so the `echo ... > gui.bat` trick in [Step 7](#step-7--one-click-launcher) would produce a batch file that cmd cannot run — and the failure looks like nonsense on screen rather than a clear error.

> [!TIP]
> **Python 3.14 is fine.** Verified on 3.14.0 (64-bit): every dependency — PySide6, unicorn, capstone, keystone-engine — has a prebuilt wheel, so nothing has to compile and no Visual Studio build tools are needed. If a future Python release outruns the wheels, install 3.12 alongside and run mtkclient with `py -3.12`.

### 1.2 — Hardware (for an ECarX E02)

| Item | Notes |
|---|---|
| USB A-to-A cable (male-to-male) | Must be a **data** cable. Charge-only cables enumerate nothing and look identical. |
| Micro JST GH 6-pin cable | 1.25 mm pitch, single connector, bare ends. Used for the two shorts in [Step 8](#step-8--enter-brom). |
| A USB 2.0 port | The black ones. BROM handshake is unreliable on USB 3.0 ports on several laptops — if you have a choice, take USB 2.0. |

![Micro JST GH 6-pin cable with the white connector on the right and bare tinned wire ends](../images/jst-6pin-cable-connector.jpg)

*Micro JST GH 6-pin cable, single connector. The connector plugs into the IHU; the bare ends are what you short in [Step 8](#step-8--enter-brom). GH series is 1.25 mm pitch — a 6-pin cable from any other JST series will not fit the port.*

## Step 2 — Python & Git

`Windows · cmd`

Open Command Prompt — `WIN+R`, type `cmd`, Enter — and check what you already have:

**Windows CMD** — Check for Python and Git
```bat
python --version
git --version
```

Three outcomes, and they mean different things:

| What you see | Meaning | Do this |
|---|---|---|
| `Python 3.x.x` | Installed and on PATH. | Skip to [Step 4](#step-4--clone--install). |
| `Python was not found; run without arguments to install from the Microsoft Store` | This is **not** "Python is missing". It is Windows' alias stub answering. Python may well be installed. | Go to [Step 3](#step-3--fix-the-path-trap). |
| `'git' is not recognized` | Git really is missing. | Install from [git-scm.com/download/win](https://git-scm.com/download/win), next-next-finish. |

> [!WARNING]
> **Settle the question first.** Before reinstalling anything, run this: **Windows CMD**Ask the Python Launcher insteadCopy py --version The `py` launcher does not depend on PATH. If `py --version` prints a version while `python --version` does not, Python is healthy and only PATH is broken — do [Step 3](#step-3--fix-the-path-trap), do not reinstall from scratch.

If Python genuinely is not installed, get it from [python.org/downloads](https://www.python.org/downloads/) and **tick "Add python.exe to PATH" on the very first installer screen**. That single checkbox is the whole of Step 3. Miss it and you will be back here.

## Step 3 — Fix the PATH Trap

`Common Wall #1`

Two separate things conspire here, which is why the error message is so misleading.

- **PATH was never set.** The installer's "Add python.exe to PATH" box is unticked by default. Python installs correctly into `%LOCALAPPDATA%\Programs\Python\Python3xx` and the command prompt has no idea it exists.
- **Windows ships a decoy.** There is a fake `python.exe` in the `WindowsApps` folder whose only job is to redirect you to the Microsoft Store. It sits early on PATH, so `python` finds *it* instead of finding nothing — and prints a message about installing Python even when Python is already there.

### 3.1 — Repair the install

1. **Settings → Apps → Installed apps**
2. Find **Python 3.x.x (64-bit)** → the `...` button → **Modify**
3. On **Optional Features**: tick **py launcher**, leave "for all users" unticked. Click **Next**.
4. On **Advanced Options**: tick **Add Python to environment variables**. Leave everything else alone — do not change the install location.
5. **Install**, and wait for it to finish.

> [!CAUTION]
> **Close every open Command Prompt and open a new one.** A running shell keeps the PATH it started with. Testing in the same window that failed before will fail again and send you chasing a problem you have already fixed.

**Windows CMD** — In a NEW cmd window
```bat
python --version
pip --version
```

Both should answer. `pip` should report a path inside your Python folder, e.g. `...\Python314\Lib\site-packages\pip`.

### 3.2 — If it still redirects to the Store

The decoy is winning. Turn it off:

1. **Settings → Apps → Advanced app settings → App execution aliases**
2. Find `python.exe` and `python3.exe`
3. Toggle both **Off**
4. New cmd window, test again

## Step 4 — Clone & Install

`Windows · cmd`

Pick a folder with **no spaces in the path**, outside any OneDrive-synced folder. Partition dumps run to tens of gigabytes and you do not want a cloud client trying to sync them.

**Option A — `C:\mtkclient`** (tidy, needs an Administrator cmd because it writes to the drive root):

**Windows CMD · Admin** — Clone and install dependencies
```bat
cd /d C:\
git clone https://github.com/bkerler/mtkclient
cd mtkclient
pip install -r requirements.txt
```

**Option B — your user folder** (no Administrator needed):

**Windows CMD** — Clone into your own profile instead
```bat
cd /d %USERPROFILE%
git clone https://github.com/bkerler/mtkclient
cd mtkclient
pip install -r requirements.txt
```

The rest of this guide writes `C:\mtkclient`. If you chose Option B, substitute your own path everywhere.

The install takes a few minutes. PySide6 alone is about 245 MB. You are done when you see a long `Successfully installed ...` line.

> [!WARNING]
> **Don't panic at the package list.** You will watch pip download Flask, SQLAlchemy, `oslo.*`, pysaml2 and a pile of other things that have nothing to do with flashing phones. That is an upstream typo: `requirements.txt` lists `keystone`, and on PyPI that name belongs to **OpenStack Keystone**, an identity service. The package mtkclient actually needs is `keystone-engine` (the assembler), which is already listed two lines earlier. The extra packages are harmless — a few hundred megabytes of disk, nothing more. Leave them.

## Step 5 — USB Driver

`UsbDk`

mtkclient talks to the BROM endpoint through **UsbDk**. Without it the tool starts but never sees a device.

Check whether you already have it: **Settings → Apps → Installed apps**, search `usbdk`. You are looking for **UsbDk Runtime Libraries** (publisher: Red Hat).

If it is missing, download `UsbDk_1.0.22_x64.msi` from the [daynix/UsbDk releases page](https://github.com/daynix/UsbDk/releases) on GitHub and install it. Reboot if the installer asks.

> [!TIP]
> If you have ever run a packaged MTKClient build (the prebuilt GUI bundles that circulate in the community), UsbDk is almost certainly already installed — those bundles ship it.

> [!WARNING]
> **One tool at a time.** Two MTKClient instances cannot share one USB device. If you keep a packaged build around, close it completely — and check Task Manager for stray `python.exe` processes — before running this one. The GUI's "Error initialising. Did you install the drivers?" line often means nothing more than "another process already holds UsbDk".

## Step 6 — Patch the Double-Init Bug

`Common Wall #2`

This is the step that is in no README, and the reason this guide exists.

### 6.1 — The symptom

The GUI connects, reads your chip perfectly, and then falls apart:

**Output** — What the broken run looks like
```text
Preloader - Detected regular mode !
Preloader -     CPU:            MT6771/MT8385/MT8183/MT8666(Helio P60/P70/G80)
Preloader - HW code:            0x788
Preloader - Get Target info
Preloader - BROM mode detected.
Preloader - ME_ID:             8C692D75...
Preloader - SOC_ID:            34E1753D...
Preloader - Status: Waiting for PreLoader VCOM, please reconnect mobile/iot device to brom mode
Preloader - [LIB]: Status: Handshake failed, retrying...
Preloader - [LIB]: Status: Handshake failed, retrying...
Preloader - [LIB]: Status: Handshake failed, retrying...
```

> [!CAUTION]
> **Read that log carefully before you touch your wiring.** It got the HW code, the ME_ID and the SOC_ID. Those come out of a completed BROM handshake. Your shorts are right, your cable is right, your driver is right, your unit is in BROM. Nothing physical is wrong. People rewire rigs for hours over this.

### 6.2 — The cause

In `mtk_gui.py`, the function `getDevInfo()` initialises the preloader — and then hands off to `da_handler.connect()`, which initialises it **again**:

**Reference** — mtk_gui.py — the duplicate call
```python
if not mtk_class.port.cdc.connect():
    mtk_class.preloader.init()          # first init  — succeeds
...
mtk_class = da_handler.connect(mtk_class)   # calls preloader.init() again — cannot succeed
```

The MediaTek BROM accepts its handshake **exactly once per power-on**. After that it is in command mode and will not answer a handshake again. So the second init can never succeed — it just retries until you give up.

Most phones survive this by accident: their USB port re-enumerates between the two calls, so the second init meets a fresh BROM. The ECarX E02 does not re-enumerate, so the bug is fully exposed. That is also why older 2.0-based builds connect to the same unit on the same wiring without complaint.

### 6.3 — The fix

Back up first:

**Windows CMD** — Back up before editing
```bat
copy C:\mtkclient\mtk_gui.py C:\mtkclient\mtk_gui.py.bak
```

Open `C:\mtkclient\mtk_gui.py` in any plain-text editor — Notepad does the job, though VS Code or Notepad++ make the indentation far easier to see — and search for `mtk_class.preloader.init()`. There is exactly one match, around line 182, inside `getDevInfo()`:

**Before** — mtk_gui.py — as shipped
```python
    try:
        if not mtk_class.port.cdc.connect():
            mtk_class.preloader.init()
        else:
            with lock:
                phone_info['cdcInit'] = True
```

Replace that one line with `pass`:

**After** — mtk_gui.py — patched
```python
    try:
        if not mtk_class.port.cdc.connect():
            pass
        else:
            with lock:
                phone_info['cdcInit'] = True
```

> [!CAUTION]
> **Indentation is load-bearing.** Python counts spaces. `pass` must start in exactly the column where `mtk_class.preloader.init()` started — one level deeper than `if`, level with the `with lock:` below. In VS Code the clean way is: click on the line, press **End**, press **Shift+Home** (this selects the code and leaves the leading spaces alone), then type `pass`.

Save. Keep a copy of the patched file, because `git pull` will overwrite it:

**Windows CMD** — Preserve the patched file across updates
```bat
copy C:\mtkclient\mtk_gui.py C:\mtkclient\mtk_gui.py.patched
```

> [!TIP]
> **Why this is safe.** You are not disabling initialisation — you are removing a duplicate. `da_handler.connect()` still calls `preloader.init()`, so the device is initialised exactly once, which is what the BROM expects. The only thing lost is the chipset name appearing a second or two earlier in the GUI header.

> [!WARNING]
> **Things that look like the fix but aren't.** Supplying a preloader binary — the GUI's blue **Preloader** button, or `--preloader path\to\preloader.bin` on the CLI — does **not** help. It was tested and ruled out. The handshake never gets far enough for the preloader to matter.

## Step 7 — One-Click Launcher

`Optional`

mtkclient needs Administrator for USB access, and it must run from its own folder. A two-line batch file saves you typing that every session.

**Windows CMD** — Create gui.bat from cmd
```bat
cd /d C:\mtkclient
echo cd /d C:\mtkclient> gui.bat
echo python mtk_gui.py>> gui.bat
type gui.bat
```

One `>` creates the file with the first line; two `>>` append the second. `type gui.bat` should echo both lines back.

From then on: right-click `gui.bat` → **Run as administrator**. For a desktop shortcut, right-click it → **Show more options** → **Send to** → **Desktop (create shortcut)**.

> [!WARNING]
> If you create the file in Notepad instead, set **Save as type** to **All Files** and put quotes around the name — `"gui.bat"` — or you will silently get `gui.bat.txt`.

## Step 8 — Enter BROM

`ECarX E02`

The E02 is not a phone: there is no test point and no volume-button combination. Everything happens on one small connector at the side of the chassis.

### 8.1 — Find the port

![Side panel of the ECarX E02 chassis with the Micro JST GH port low down, next to a red TAP marking](../images/jst-port-location.jpg)

*Where to look: the port sits low on the side panel of the chassis. The red **TAP** marking here is hand-written — your unit will not have it.*

![Close-up of the Micro JST GH port showing six gold pins inside a white plastic housing](../images/jst-port-closeup.jpg)

*The same port close up — six pins in a white housing. Count them against the table below before you push the connector in.*

### 8.2 — Pinout

| Pin | Colour | Function | Role in this guide |
|---|---|---|---|
| 1 | White | GND | Short to blue |
| 2 | Blue | Recovery | Short to white (GND) — this is what enters BROM |
| 3 | Green | USB | Short to red (3.3V) — puts the USB port into device mode |
| 4 | Black | UART RX | Not used here |
| 5 | Yellow | UART TX | Not used here |
| 6 | Red | 3.3V | Short to green |

![Micro JST GH 6-pin cable with the wires fanned out, showing white, blue, yellow, green, black and red](../images/jst-6pin-cable-wires.jpg)

*The six wire colours, matching the table above: white, blue, green, black, yellow, red.*

> [!TIP]
> **Four wires matter here:** white, blue, green and red. Yellow and black are the UART pair — this guide never uses them, so insulate their bare ends before you power anything up.

### 8.3 — The two shorts

Two separate shorts, doing two different jobs. You need both, at the same time, for the whole session.

| Short | Purpose | When to release |
|---|---|---|
| **White (GND) ↔ Blue (Recovery)** | Puts the SoC into BROM at boot instead of loading the preloader from eMMC. | Keep it in for the whole session. |
| **Green (USB) ↔ Red (3.3V)** | Switches the unit's USB port from host mode into **device** mode, so the PC can see it at all. | Keep it in for the whole session. Release it and the port instantly stops being a device. |

> [!CAUTION]
> **Red is a live 3.3 V rail whenever the unit is powered.** Red touching white (GND) is a dead short across the IHU's 3.3 V supply — the worst thing on this page. Make each short deliberately, to the one wire it belongs to, and insulate every bare end you are not actively using. Never bundle loose ends together "out of the way" — that is precisely how blue meets red.

### 8.4 — Power-up order

BROM is decided at the instant the SoC powers up, so both shorts must already be in place before power arrives. This order is not a suggestion — work down the list without jumping ahead.

- **Disconnect IHU power.** Unplug **Socket Block A — Power**, the black connector sitting lowest in the ISO stack. Pulling the socket is what guarantees a true cold boot; standby is not enough.

  ![The ISO connector block on the back of the IHU with all sockets plugged in](../images/power-socket-before.jpg)

  *The ISO connectors as they normally sit, everything still plugged in.*

  ![The same ISO connector block with a red box drawn around the black power socket at the bottom of the stack](../images/power-socket-highlighted.jpg)

  *Unplug the one in the red box: **Socket Block A — Power**, the black connector at the very bottom of the ISO stack.*

- **Make both shorts on the JST jumper.** White↔blue, and green↔red. Join them properly — twisted and tinned, or soldered. A jumper you have to pinch by hand will let go at the worst possible moment, and a short that opens mid-session drops the unit straight out of BROM.

  ![Micro JST GH cable with only four wires fitted, white joined to blue at one pair of ends and green joined to red at the other, bare tinned copper still showing](../images/jst-jumper-shorted.jpg)

  *The two joins made: white to blue, green to red. Yellow and black are left off the connector entirely — this guide never uses UART, so removing them removes any chance of a stray short.*

  ![The same jumper with each shorted pair sealed inside its own piece of black heat shrink tubing, no copper visible](../images/jst-jumper-shorted-insulated.jpg)

  *The same jumper finished. Each join sits inside **its own** piece of heat shrink, with no copper showing anywhere. This is what it should look like before it goes near a powered unit — PVC tape works too if you have no heat gun.*

  > [!CAUTION]
  > **Two ways to get this wrong, and both cost you hardware.**
  >
  > - **Wrong pair.** Red is a live 3.3 V rail whenever the unit is powered. Red touching white is a dead short straight across the IHU's 3.3 V supply. There are exactly two joins on this jumper — **white↔blue** and **green↔red** — and nothing else may touch. Check the colours twice before the tube goes on, because once it is shrunk you cannot see what is underneath.
  > - **Bare copper left showing.** A join you tinned but never covered will find the other pair the first time the cable shifts — and it shifts every session. Cover each join completely, past the tip, not just over the middle.
  >
  > Sleeve the two joins **separately**. Bundling both pairs into one lump of tape or one length of tube is precisely how white↔blue ends up touching green↔red.

- **Plug the JST jumper into the IHU port** — the one you located in [8.1](#81--find-the-port).
- **Start the GUI.** Right-click `gui.bat` → **Run as administrator**, and let it sit at "Waiting for connection" before you go any further. The tool must be listening before the unit boots, not after.
- **Plug the POWER socket back in.**
- **Immediately plug the USB A-to-A cable**: IHU USB port → PC USB 2.0 port.

  ![A laptop connected by a USB A-to-A cable to the car's centre-console USB socket, with the gear selector in P](../images/usb-a-to-a-laptop-to-ihu.jpg)

  *The A-to-A cable running from the laptop to the car's centre-console USB socket. This is the **only** socket wired to the IHU. Every other USB port in the car is charge-only and will never enumerate, whatever cable you use.*

> [!WARNING]
> Plug the USB cable into an already-booted unit and you will catch the preloader for the couple of seconds it is alive during boot, then lose it. The log will read `Detected regular mode !` followed by the handshake loop — which looks exactly like the [Step 6](#step-6--patch-the-double-init-bug) bug but isn't. Power-cycle and follow the order above.

> [!TIP]
> **Verify the shorts with a multimeter** if you are unsure — continuity mode, probe white against blue with the jumper fitted. JST GH is 1.25 mm pitch; joints that look fine frequently aren't.

## Step 9 — Verify

`Done When…`

A successful connection walks through the preloader info, uploads the Download Agent, and lands on the partition list.

**Output** — A good run, ECarX E02 / MT6771
```text
Preloader - Detected regular mode !
Preloader -     CPU:            MT6771/MT8385/MT8183/MT8666(Helio P60/P70/G80)
Preloader - Disabling Watchdog...
Preloader - HW code:            0x788
Preloader - Target config:      0xe5
Preloader -     SBC enabled:    True
Preloader -     SLA enabled:    False
Preloader -     DAA enabled:    True
Preloader - Get Target info
Preloader - BROM mode detected.
Preloader - ME_ID:             8C692D75...
Preloader - SOC_ID:            34E1753D...
Preloader - Jumping to 0x200000
Preloader - Jumping to 0x200000: ok.
```

In the GUI, the **Read partition(s)** tab should now list the unit's partitions with sizes — `boot_para`, `recovery`, `nvdata`, `metadata` and the rest. That list comes off the device's own GPT, so seeing it means the DA is running and the connection is fully established.

![MTKClient 2.1.4 connected to an ECarX E02: the console log ends with Jumping to 0x200000 ok, and the Read partition(s) tab lists the partitions with sizes](../images/mtkclient-connected-partition-list.png)

*A finished connection. The console ends on `Jumping to 0x200000: ok.` and the **Read partition(s)** tab is populated straight from the unit's own GPT.*

> [!TIP]
> **Worth recording.** Your unit's `ME_ID` and `SOC_ID` are printed here and are specific to your hardware. Keep them with your firmware backups.

> [!CAUTION]
> **Stop here.** The tool is installed and connected — that is all this guide promised. Erasing, unlocking the bootloader and writing partitions are destructive and belong to the [sideload guide](./sideload.md) — which starts by backing up every partition, and that backup is your only way home. Unlocking wipes userdata.

## Fix Fast

`Troubleshooting`

Symptoms in the order you are likely to meet them.

| Symptom | Cause | Fix |
|---|---|---|
| `Python was not found... Microsoft Store` | PATH unset, and the WindowsApps alias stub is answering. | [Step 3](#step-3--fix-the-path-trap). Run `py --version` first to confirm Python itself is fine. |
| Fixed PATH but cmd still fails | The open shell still holds the old PATH. | Close every cmd window and open a new one. PATH is read at launch. |
| `error: externally-managed-environment` | You are in WSL or Linux, not Windows. Ubuntu 24.04 blocks pip from writing to the system Python. | This guide is for native Windows. If you meant to use Linux, create a venv: `python3 -m venv venv && source venv/bin/activate`. |
| `could not create work tree dir` on clone | Writing to `C:\` root without Administrator. | Use an Administrator cmd, or clone into your user folder (Option B in [Step 4](#step-4--clone--install)). |
| pip pulls Flask, SQLAlchemy, oslo.* | Upstream typo: `keystone` in requirements.txt resolves to OpenStack Keystone. | Nothing to fix. Harmless, just disk space. |
| Chip info reads OK, then `Handshake failed, retrying` forever | The double-init bug. Not your wiring. | [Step 6](#step-6--patch-the-double-init-bug). |
| `Error initialising. Did you install the drivers?` | Usually another MTKClient instance or a stray `python.exe` holding UsbDk. | Close all other instances, clear stray processes in Task Manager, relaunch. |
| Nothing detected at all | Green↔red short missing, so the USB port is still in host mode. Or a charge-only cable. | Check both shorts ([Step 8](#step-8--enter-brom)) and swap to a known data cable. |
| Detected, but handshake retries on a USB 3.0 port | BROM handshake timing is unreliable on some USB 3.0 controllers. | Move to a USB 2.0 (black) port. |
| Patch applied, now `IndentationError` | `pass` is in the wrong column. | Restore and retry: `copy C:\mtkclient\mtk_gui.py.bak C:\mtkclient\mtk_gui.py` |
| Worked before, broken after `git pull` | The update overwrote your patch. | Reapply [Step 6](#step-6--patch-the-double-init-bug), or restore `mtk_gui.py.patched`. |

## Project Notes

`Background`

### 1 — Why the BROM only handshakes once

The MediaTek boot ROM starts in a listening state, waiting for a specific byte sequence on the USB endpoint. Complete that exchange and it transitions into command mode, where it accepts the actual protocol — read register, get target config, jump to address. There is no path back. The handshake state is entered on power-up and left exactly once.

So a second handshake attempt is not slow or flaky — it is structurally impossible. The retry loop will run until you close the tool, and no amount of re-plugging, cable swapping or port changing will help, because the device is not broken and not gone. It is sitting there in command mode, waiting for commands nobody is sending.

### 2 — Why phones don't hit this

Most phones re-enumerate on the USB bus between the two init calls: the port drops and comes back, Windows re-attaches, and the second `preloader.init()` meets what is effectively a fresh connection. The bug is there, it just never surfaces. Hardware that keeps a stable USB presence — the E02 among it — makes it visible every single time. That is why the bug survived upstream: on the devices most people test with, it is invisible.

### 3 — Reading the log correctly

Two lines in the log are easy to misread:

- `Detected regular mode !` does **not** mean "not in BROM". In `mtk_preloader.py` it distinguishes *regular* from *iot* mode — it is about the chip family, not the boot state.
- `BROM mode detected.`, a few lines further down, is the line that actually tells you the unit is in BROM. It is printed by `get_blver()` when the bootloader-version command comes back the way only a boot ROM answers.

If you see `BROM mode detected.`, your hardware setup is correct, whatever happens afterwards.

### 4 — What was ruled out

Before the duplicate call was found, these were tested against the same unit and none of them were the cause: re-seating and verifying both JST shorts with a multimeter; every USB port and multiple data cables; the full power-off-first sequence; supplying the device's own extracted preloader via both the GUI's **Preloader** button and the CLI's `--preloader` flag; running as Administrator; closing competing instances. The decisive evidence was that an older 2.0-based build connected to the identical rig, wiring and sequence without any trouble — which pointed at the software, not the bench.

### 5 — Version note

Diagnosed against mtkclient **2.1.4** on Windows 11 with Python 3.14.0, connected to a Proton ECarX E02 (MT6771, HW code `0x788`). If a future release removes the duplicate `preloader.init()` from `getDevInfo()`, Step 6 becomes unnecessary — check whether the line is still there before patching. The fix is worth reporting upstream; any device that does not re-enumerate is affected.

### 6 — Keeping the patch through updates

The clean way to survive `git pull` is to keep the change as a commit on a local branch rather than as an untracked edit:

**Windows CMD** — Optional — track the patch in git
```bat
cd /d C:\mtkclient
git checkout -b e02-fix
git add mtk_gui.py
git commit -m "Remove duplicate preloader.init() in getDevInfo"
```

Then updating becomes `git fetch origin && git rebase origin/main`, and git will tell you if upstream has changed that region — including if they have fixed it themselves.
