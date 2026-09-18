# ECarX E02 Sideload Research

Independent research and documentation on the ECarX E02 in-head unit (IHU) — the infotainment platform used in the Proton X50 RC, S70 and X90.

This repository documents **methods**: how the platform is built, how to get a shell, how the boot chain and the system partition work, and how apps can be installed. It is here so anyone can read and check this work, instead of it being kept private.

---

## ⚠️ Read this before anything else

**This work can permanently damage your head unit.**

Flashing firmware, patching the bootloader and changing the system partition can all brick the unit. Getting it back may need hardware work, and sometimes there is no way back at all.

- Everything here is **for learning and research only**.
- You are **solely responsible** for whatever you do to your own hardware.
- This will likely **void your manufacturer warranty**.
- Nothing here is tested or approved by any vehicle manufacturer.
- **No warranty of any kind.** If it breaks, you own both pieces.

**Back up every partition before you change anything.** That dump is the only thing between a failed experiment and a dead unit.

If you are not comfortable reading a UART console, recovering from a failed flash, and working things out on your own, this repository is not for you.

---

## Does this apply to your unit?

Check both numbers before you start. The software version alone is not enough. The same model can ship with more than one hardware revision, and a method that works on one is not automatically safe on the other.

| Model | IHU software versions | Hardware version |
|---|---|---|
| **Proton S70** Flagship & Flagship X | v333, v300, v209, v202 | `HW0SS110506M0101` |
| **Proton X50 RC** | v144, v115 | `HW0SX110506M0101` or `HW0SX110506H0101` |
| **Proton X90** Flagship | v735, v722, v694, v651, v647, v638 | `HW0VX110506H0101` |

All of them run **Android 9** on the ECarX E02 platform.

If your unit is not on this list, nothing here is known to work on it. Post your model, software version and hardware version in [Discussions](../../discussions) — that is how the list grows.

---

## The guides

Grouped by what they do. The guides under **Live Deploy — UART** build on each other. Everything under **Apps & Tweaks** needs a unit that has already been through them.

### Live Deploy — UART

Root and sideload on the running system. Flash two small files once, then do everything else over UART. Read these in order.

| # | Guide | What it covers |
|---|---|---|
| 1 | **[Install MTKClient from Source on Windows](docs/mtkclient-windows-install.md)** | Getting the flashing tool working, including a bug in the upstream GUI that makes it loop forever on this hardware. Everything else needs this first. |
| 2 | **[Build services.jar for ECarX E02 Android 9](docs/build-services-jar.md)** | Turning the stock `services.vdex` from your own unit into a `services.jar` that allows sideloading. You build it from your own firmware — nothing is handed out here. |
| 3 | **[Sideload — Live Deploy over UART](docs/sideload.md)** | Back up every partition, flash `lk.bin` and `boot.bin` once, then deploy the jar on the running system over UART. |

Guide 2 needs only a UART console, so you can do it before or after guide 1. Guide 3 needs both.

### Apps & Tweaks

Changes for a unit that already has root and Magisk from guide 3. Each one stands alone, so take any of them, in any order.

| Guide | Tested on | What it does |
|---|---|---|
| **[Steering Wheel Button Remap](docs/steering-button-remap.md)** | S70 · V333 | Short press on Hi Proton changes the drive mode, holding the call button opens the 360 camera. The apps are hooked while they run, so no system file is changed. Builder script in [`scripts/`](scripts/build-steering-mod.sh). |

---

## How this project works

This is a **part-time research project**, run by a few people who have full-time jobs. That shapes what you can expect here.

**There is no personal support.** Private messages are not answered, on any platform. Everything happens in [Discussions](../../discussions), in the open, where the answer stays there for the next person with the same question.

The **Issues** tab is switched off on purpose. It is not a mistake — Discussions is the whole of it.

**Discussions has two halves, and they work differently:**

| Category | Who answers |
|---|---|
| **Research & Findings** | Maintainers join in — this is the part of the project we are actually interested in |
| **Help & Questions** | The community answers each other. We read it, but we do not work through it |

Replies take days, not hours. Sometimes longer, and weekends more often than weekdays. Nothing here is guaranteed a reply.

If you are stuck on something the documentation already covers, read it again. If the documentation is not clear, say so — that is a useful report, and we would rather fix the guide than answer the same question twice.

---

## Scope

**In scope**

- Methods, steps and technical explanation
- Partition layout, offsets, and where the patches go
- Tools, commands and workflows
- What works, and what does not, across models and firmware versions

**Out of scope**

- Firmware images, binaries or partition dumps that belong to the vendor
- Paid installation services
- Requests to do the work for someone

Model names and firmware versions appear here only to say which hardware a method applies to.

---

## Status

Early. Documentation goes up bit by bit, as it is written and checked.

| Target | Android | Status |
|---|---|---|
| ECarX E02 | 9 | Documented |
| Newer platforms (dynamic partitions, `super.bin`) | 10 | Research — no hardware available |

This repository may be archived or left alone at any point, without notice. The licence lets anyone fork it and carry on.

---

## Contributing

What really helps here:

- Telling us a documented method worked — or did not — on your unit. **Include both your IHU software version and your hardware version string.** Without them, a result cannot be matched against anyone else's.
- Reports from versions that are not covered yet
- Corrections and clearer wording for the documentation
- `getprop` and `dmesg` output from platforms not covered yet
- Findings of your own, even partial ones

Post findings in **Research & Findings**. Open a **Pull Request** for changes to the documentation itself.

Please do not attach vendor firmware or partition dumps to anything you send.

If you worked out something this repository gets wrong, say so directly. Being corrected is the point of publishing.

---

## Legal

This is independent interoperability research, on hardware the researchers own. It is not affiliated with, authorised by, or endorsed by any vehicle manufacturer or infotainment supplier. All trademarks belong to their respective owners.

Documentation licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
