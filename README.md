# ECarX E02 Sideload Research

Independent research and documentation on the ECarX E02 in-head unit (IHU) — the infotainment platform used in the Proton X50 RC, S70 and X90.

This repository documents **methods**: how the platform is structured, how to obtain shell access, how the boot chain and system partition work, and how applications can be installed. It exists so that this knowledge is publicly available and openly reviewable, rather than held privately.

---

## ⚠️ Read this before anything else

**This work can permanently damage your head unit.**

Flashing firmware, patching the bootloader and modifying the system partition all carry real risk of bricking the device. Recovery may require hardware-level intervention, and in some cases may not be possible at all.

- Everything here is provided **for educational and research purposes only**.
- You are **solely responsible** for anything you do to your own hardware.
- This will likely **void your manufacturer warranty**.
- Nothing here is tested or endorsed by any vehicle manufacturer.
- **No warranty of any kind.** If it breaks, you own both pieces.

**Back up every partition before you change anything.** A full dump is the only thing standing between an experiment and a dead unit.

If you are not comfortable reading a UART console, recovering from a failed flash, and troubleshooting without help, this repository is not for you.

---

## Does this apply to your unit?

Check both numbers before you start. The software version alone is not enough — the same model can ship more than one hardware revision, and a method verified on one is not automatically safe on the other.

| Model | IHU software versions | Hardware version |
|---|---|---|
| **Proton S70** Flagship & Flagship X | v333, v300, v209, v202 | `HW0SS110506M0101` |
| **Proton X50 RC** | v144, v115 | `HW0SX110506M0101` or `HW0SX110506H0101` |
| **Proton X90** Flagship | v735, v722, v694, v651, v647, v638 | `HW0VX110506H0101` |

All of the above run **Android 9** on the ECarX E02 platform.

If your unit is not on this list, nothing here is known to apply to it. Posting your model, software version and hardware version in [Discussions](../../discussions) is genuinely useful — that is how coverage grows.

---

## The guides

Read them in this order. Each one is self-contained, but later guides assume the earlier ones are done.

| # | Guide | What it covers |
|---|---|---|
| 1 | **[Install MTKClient from Source on Windows](docs/mtkclient-windows-install.md)** | Getting the flashing tool working, including a bug in the upstream GUI that makes it loop forever on this hardware. Everything else needs this first. |
| 2 | **[Build services.jar for ECarX E02 Android 9](docs/build-services-jar.md)** | Turning the stock, odexed `services.vdex` from your own unit into a patched, sideload-enabled `services.jar`. You build it from your own firmware — nothing is distributed here. |
| 3 | **[Sideload — Live Deploy over UART](docs/sideload.md)** | Back up every partition, flash `lk.bin` and `boot.bin` once, then deploy the jar on the running system over UART. |

Guide 2 needs only a UART console, so it can be done before or after guide 1. Guide 3 needs both.

---

## How this project works

This is a **part-time research project**, maintained by a few people alongside full-time jobs. That shapes what you can expect here.

**There is no personal support.** Private messages are not answered, on any platform. Everything happens in [Discussions](../../discussions), in the open, where the answer stays readable for the next person with the same question.

The **Issues** tab is deliberately switched off. It is not an oversight — Discussions is the whole of it.

**Discussions has two halves, and they work differently:**

| Category | Who answers |
|---|---|
| **Research & Findings** | Maintainers participate — this is the part of the project we are actively interested in |
| **Help & Questions** | The community answers each other. We read it, but we don't work through it |

Response time is measured in days, not hours — sometimes longer, and weekends more often than weekdays. There is no guaranteed reply to anything.

If you're stuck on something already covered in the documentation, re-read the documentation. If the documentation is unclear, say so — that's a useful report, and we'd rather fix the guide than answer the same question twice.

---

## Scope

**In scope**

- Methods, procedures and technical explanation
- Partition layout, offsets, and patch locations
- Tooling, commands and workflows
- Compatibility findings across models and firmware versions

**Out of scope**

- Proprietary firmware images, binaries or partition dumps
- Commercial installation services
- Requests to perform the work on someone's behalf

Model names and firmware version numbers appear here only to identify which hardware a given method applies to.

---

## Status

Early. Documentation is being published incrementally as it is written up and verified.

| Target | Android | Status |
|---|---|---|
| ECarX E02 | 9 | Documented |
| Newer platforms (dynamic partitions, `super.bin`) | 10 | Research — no hardware available |

This repository may be archived or left unmaintained at any point without notice. It is licensed so that anyone can fork it and continue the work.

---

## Contributing

What's genuinely useful here:

- Confirmation that a documented method worked — or didn't — on your unit. **Include both your IHU software version and your hardware version string**; a result without them can't be matched to anyone else's.
- Compatibility reports for versions not yet covered
- Corrections and clarifications to the documentation
- `getprop` and `dmesg` output from platforms not yet covered
- Findings of your own, even partial ones

Post findings in **Research & Findings**. Open a **Pull Request** for changes to the documentation itself.

Please don't attach proprietary firmware or partition dumps to anything you submit.

If you've worked out something this repository gets wrong, say so directly. Being corrected is the point of publishing.

---

## Legal

This is independent interoperability research on hardware the researchers own. It is not affiliated with, authorised by, or endorsed by any vehicle manufacturer or infotainment supplier. All trademarks belong to their respective owners.

Documentation licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
