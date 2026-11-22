# 00 — Feasibility assessment (SM-A155F)

**Status: draft, evidence-gated.** This document separates what is *observed* from
what is *assumed* and never upgrades a build result into a device-verified claim.

## Target

| Field | Value | Evidence |
|---|---|---|
| Device | Samsung Galaxy A15 4G, `SM-A155F` (single target; not `SM-A156x`) | owner instruction |
| SoC | MediaTek MT6789 / Helio G99 | owner instruction, firmware donor scatter file |
| Kernel line | GKI 5.10.226 (per pinned artifact name) | Drive filename only |
| Firmware baseline | `A155FXXS7CYG4`, region XSG, `A155FOJM7CYG4` CSC | Drive filename + `_FirmwareInfo_Samfw.com.txt` (SAMFW) |
| Rolling/`SW REV` | disputed: Odin reported `Fused 7 > Binary 8`, owner reported binary 7 | owner report; **unreconciled** |
| Android version of baseline | Android 15 / One UI 7-era vendor stack (`_OS15` in AP name) | Drive filename |

## Verdict on "Nothing OS 5 port"

**Not feasible as a true Nothing OS port. Confidence: high.** Reasons, in order of
weight:

1. **No Nothing OS 5 image exists in the reachable Drive scope.** A Drive-wide
   search on 2026-11-22 for `name contains 'Nothing'` returned 0 results, and the
   `/GrapheneOS` folder contains only the SM-A155F stock firmware plus three
   prebuilt boot TARs. There is nothing to port *from*.
2. **Different silicon, different HAL universe.** Nothing OS ships for
   Nothing/CMF devices (Qualcomm platforms). MT6789 uses MediaTek's
   vendor/HAL/modem stack. A framework transplant would have to supply every
   MediaTek HAL, the MTK modem/RIL, Samsung's AVB/Knox chain and the Samsung
   bootloader contract at once — that is a multi-month bring-up, not a port.
3. **Licensing.** Nothing OS framework code, apps and resource overlays are
   proprietary and may not be extracted, redistributed or embedded without a
   documented lawful source and permission. Bundling them in a community
   artifact is out of scope for this project.
4. **Boot chain.** Samsung's fused rollback protection (`SW REV`) and Knox
   attestation mean an unsigned, differently-signed system image does not simply
   boot. Rollback/fuse state is currently contradictory (see table).

**Feasible alternative (clearly labelled):** an *unofficial, Nothing-inspired*
experience built from the owner's own or independently created resources on top
of a working A155F base. It must never be described as official Nothing OS.

## Update 2026-11-22 (second revision) — the GSI route supersedes the verdict above

The verdict above is about **porting Nothing OS from a firmware/system dump**. It
stands for that route: there is still no Nothing firmware image, and a
Qualcomm-targeted framework cannot be transplanted onto a MediaTek/Samsung vendor
stack by hand.

What changes the practical answer is that an **unofficial Nothing OS GSI family
already exists** (Mystic GSI Updates, SourceForge). A GSI replaces only the
`system` image and keeps the Samsung `boot`/`vendor`/`odm` and the kernel, which
removes the entire cross-vendor HAL transplant from the problem. See
`docs/50-GSI-LINE.md`.

| Item | Firmware port | GSI route |
|---|---|---|
| Nothing framework source | absent (blocker) | shipped inside the third-party GSI |
| MTK HAL / RIL / camera | would break | Samsung vendor kept |
| Kernel | would need a Motorola kernel on a Samsung board | unchanged |
| AVB / Knox | must be rebuilt | bootloader unlock + verification off only |
| Redistribution by this project | would be required | not required **if** artifacts stay local |
| Feasibility | not feasible | **feasible to attempt**, unproven on this device |
| Device evidence on Samsung MTK | — | a public review reports a bootloop on `SM-A235F` |

So the honest statement is now: *a true official Nothing OS port remains
impossible; an unofficial Nothing-derived GSI is the realistic path, and it is
untested on SM-A155F.*

## Feasibility matrix

| Component | Source / provenance | Compatibility | Legal | Evidence | Blocker |
|---|---|---|---|---|---|
| Nothing OS 5 system image | none found in Drive | unknown / none | cannot redistribute | Drive search = 0 hits | **no source package** |
| Nothing OS kernel | n/a (Nothing ships its own device kernels) | no | — | — | wrong SoC, no source |
| A155F stock firmware `A155FXXS7CYG4` (XSG) | SAMFW, pinned by Drive MD5 | target-native | vendor firmware, owner-supplied | 6,904,157,493 B, MD5 `bea1131d…9b57` | none for rollback use |
| `bakasu_35262_susfs_v2.4.0` boot TAR | owner's Drive | unknown; contents unverified | owner artifact; SusFS is GPL-derived, keep notices | 67,112,960 B, MD5 `39800312…8054` | contents not yet inspected |
| `kernelsunext_33548_susfs_v2.4.0` boot TAR | owner's Drive | unknown | same as above | 67,112,960 B, MD5 `472a59d4…0cd65` | contents not inspected |
| `stock_optimized_5.10.226` boot TAR | owner's Drive | reference / rollback | owner artifact | 67,112,960 B, MD5 `161fe2db…9342` | contents not inspected |
| Kernel **source** tree (GKI 5.10 + A155F device tree) | **absent** | — | GPLv2 obligations once built | none in Drive | **cannot compile a kernel today** |
| Motorola `emerald` OS3.0.303.0 / Android 16 donor | Drive `Emerald.tgz` (7,664,845,630 B) | same SoC family, different vendor | redistribution restricted | `emerald-contents.txt` | cross-vendor port, super 7.13 GB → 9.35 GB target resize, phase-2 tooling gaps |
| Recovery / rollback path | stock AP + BL/CP/CSC of `A155FXXS7CYG4` | target-native | — | archive listing pinned | fuse/`SW REV` reconciled? **no** |
| Device validation (boot, RIL, sensors, camera) | none for any candidate | — | — | — | **no device evidence** |

## Firmware / rollback blockers

1. `SW REV CHECK FAIL [super] Fused 7 > Binary 8` contradicts the owner-reported
   binary 7 / `A155FXXS7CYG4`. Until the exact current fused revision is read
   from the device (Odin/download mode screen) and written down, no flash
   recommendation is defensible — and archive-format fixes never bypass rollback
   protection.
2. Rollback depends on a verified, hashed copy of the stock AP/BL/CP/CSC for the
   *exact* fused revision. The pinned `A155FXXS7CYG4` archive is the only such
   copy in scope.
3. ROM `1.1` remains withdrawn and **DO NOT FLASH**; it is kept only as
   historical investigation material. Nothing in this repository re-packages it.

## What can be built *today* with the material in scope

Ranked by distance to a first artifact:

1. **Build A — kernel/boot bundle (recommended).** Inspect the three pinned boot
   TARs, then repack the owner-preferred `bakasu` artifact into a clean, plain,
   reproducible Odin AP TAR with a SHA-256 manifest. No compilation needed, fully
   verifiable, reversible, no donor licensing exposure. See
   `docs/20-FIRST-BUILD.md`.
2. **Build B — Nothing-inspired systemless layer.** Only after a stable rooted
   base exists on the device; must use independently created or owner-supplied
   assets. Not a ROM, and not part of the first build.
3. **Build C — `emerald` cross-vendor port.** Largest effort, lowest probability,
   blocked on `lpdump`/`lpunpack` tooling, partition-name reconciliation and
   super-partition resize planning; and it would still not be Nothing OS.

## Missing evidence (owner input required)

- Nothing OS 5 package identity: exact device, build number, archive name, and
  where it actually lives (it is not in the Drive scope this account can see).
- Current device state: fused/`SW REV` value from download mode, build number in
  Settings, bootloader unlock state.
- Whether "ilk build" means a kernel/boot bundle (Build A) or a full ROM.
- Any kernel **sources** (GKI common tree, A155F device tree) if a real kernel
  compile is wanted.
