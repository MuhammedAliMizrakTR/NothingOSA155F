# 50 — GSI line (primary route as of 2026-11-22, second revision)

**What changed:** the owner found an existing unofficial Nothing OS GSI build
family (`Mystic GSI Updates`, SourceForge, by *romashkagene*). This does not
make a Nothing OS *port from firmware* possible — but it does replace the entire
"transplant a vendor framework" problem with the supported **GSI** mechanism.
`docs/00-FEASIBILITY.md` keeps its original verdict for the firmware-port route
and points here for the superseding route.

## Why a GSI is a different (and viable) problem

A GSI replaces **only the `system` image**. Everything that made the earlier plan
impossible stays untouched:

| Layer | Firmware port (rejected) | GSI (this route) |
|---|---|---|
| bootloader / AVB / Knox | must be defeated and rebuilt | untouched (just unlocked + verification off) |
| kernel / `boot` / `vendor_boot` | Motorola kernel on a Samsung board — impossible | **Samsung's own, unchanged** |
| `vendor` / `odm` (MTK HALs, RIL, camera) | would have to be Motorola's | **Samsung's own, unchanged** |
| framework / system apps | Nothing framework bolted onto Samsung vendor by hand | **shipped inside the GSI** by the GSI author |
| licensing | redistribute Nothing framework ourselves | we redistribute **nothing**; owner downloads it |

So: nothing official Nothing OS, still an unofficial third-party GSI — but the
engineering risk drops from "unbounded" to "does this GSI match this vendor".

## Candidate builds (pinned in `inputs/inputs.lock.json`)

| # | File | Android | Size | MD5 (SourceForge RSS) | Role |
|---|---|---|---|---|---|
| 1 | `Nothing-Asteroids-16-2511181551-AB-20260111-MysticGSI.zip` | 16 | 2.3 GB | `152a92ab392e1cab111f7e7474cec33c` | owner's preferred, newest |
| 2 | `Nothing-Asteroids-15-2504171222-AB-20250508-MysticGSI.zip` | 15 | 2.0 GB | `08b085d4facad07b00556d566a9fe2cb` | **fallback #1** — same Phone (3a) donor, vendor-matched |
| 3 | `Nothing-Metroid-15-2507112047-AB-20250727-MysticGSI.zip` | 15 | 3.0 GB | `2e846c0273d95103e777c1b42804f5b1` | fallback #2 — Phone (3) flagship donor, heaviest |
| 4 | `Nothing-Spacewar-14-2407051617-AB-20240904-MysticGSI.zip` | 14 | 1.6 GB | `282f3a70738921eac535ce756c7fc610` | if "Nothing OS 14" was meant |

Download root: `https://sourceforge.net/projects/mystic-gsi-updates/files/Nothing/`.
Sizes are the listing's rounded figures; the MD5s come from the project's RSS
feed and are **not** verified by a download here. Verify before use — that is what
`tools/gsi_inspect.py` and the MD5 in the lock file are for.

### Which one to try first

The device's `vendor` is Android **15** (One UI 7-era, `A155FXXS7CYG4`). A GSI
must satisfy the vendor API level, and HAL drift grows with the gap:

- **A16 GSI (#1)** asks an Android 15 Samsung/MTK vendor to serve an Android 16
  framework — the combination with the most HAL drift.
- **A15 GSI (#2)** is the vendor-matched generation and the same Phone (3a) donor
  device, i.e. the highest probability of booting.

Both go through the same packaging pipeline (`odin_pack.py`), so preparing both
costs one extra run. Recommended order: **package both, attempt what the owner
prefers first, keep the other as the fallback**, and record each attempt as its own
observation. Nothing about donor *performance* argues against #1: see
`docs/60-NOTHING-OS-MAP.md` §4 — the donor's "strength" barely moves the load, and
the Phone (3a) donor is the mid-range one that fits Helio G99 best.

## Kernel: not touched

A GSI replaces `system` only. `boot`/`vendor_boot`/kernel and `vendor`/`odm` stay
exactly as they are, so no kernel work is needed for the Nothing GSI — the
`bakasu` kernel can stay. Root (KernelSU/SusFS) is a separate optional layer.

Owner-reported evidence (single device, not independently verified): the `bakasu`
kernel already booted a *RestlessOS 17* GSI (Android 17 / GrapheneOS-fork based).
If it holds, that demonstrates two things on this exact device: the GSI flashing
path already works, and the A155F vendor tolerates a framework *newer* than its own
Android 15 vendor. It also means the **already-proven method should be reused
verbatim** — reproducing it is the missing piece of this pipeline, so the owner
should describe it (Odin AP tar contents? separate `vbmeta`? recovery/fastbootd?).

## Known risks (evidence, not speculation)

1. **A bootloop report on a Samsung MTK sibling.** A public review of this project
   says *"bootloops, i tried on a235f, BOOTLOOP"* (`SM-A235F`, Samsung, MediaTek
   Dimensity 700, dynamic partitions). A155F is also Samsung + MediaTek. Treat
   "GSI on Samsung MTK" as *unproven*, not as "supported".
2. **Vendor API level / HAL surface.** Samsung's vendor ships Samsung-specific
   HALs (`vendor.samsung*`, Knox services, sec_* properties). AOSP-framework GSIs
   generally lose: fingerprint/biometrics, some camera modes, VoLTE/VoWiFi,
   Samsung audio routing quirks, secure folder/Knox features (permanently, once the
   warranty bit is tripped).
3. **AB naming vs Samsung slots.** These builds are named `AB`. Samsung
   dynamic-partition devices are not A/B in the update sense; AB-named GSIs are
   commonly flashed to `system` on Samsung anyway. Whether *this* build boots is
   unknown and must be measured.
4. **AVB.** Flashing a non-Samsung `system` requires verification/verity to be off
   (the usual `vbmeta` route) and an unlocked bootloader. This repository does not
   generate or fake AVB images; use your own established vbmeta workflow and treat
   it as device-state-changing.
5. **Size.** The GSI `system.img` must fit the target's `system` logical partition
   inside `super` (total logical ≈ 9.35 GB, per partition TBD with
   `tools/super_inspect.py`). `gsi_inspect.py` reports the expanded size so this is
   checked before a flash, not after.

## Pipeline (build, not flash)

> Packaging shape matters: tar **only `system.img`** unless you deliberately build a
> hybrid `super.img` that still contains Samsung `vendor`/`odm`. A member named
> `super.img` is written to the whole physical partition — see
> `docs/65-SUPER-PACKAGING.md` and check every package with
> `python3 tools/odin_audit.py <AP>.tar` before it goes anywhere near Odin.

```bash
# 0. verify what you downloaded
python3 tools/gsi_inspect.py Nothing-Asteroids-16-...-MysticGSI.zip          # md5, members, container, expanded size

# 1. extract exactly one member, no overwrite
python3 tools/gsi_inspect.py Nothing-Asteroids-16-...-MysticGSI.zip \
    --extract /content/work/gsi16 --only system.img

# 2. package as a plain Odin AP TAR (no md5 footer, no lz4, reproducible)
python3 tools/odin_pack.py \
  --out /content/out/AP_nothing_asteroids16_system.tar \
  --manifest /content/out/AP_nothing_asteroids16_system.manifest.json \
  /content/work/gsi16/system.img

# 3. verify the artifact bytes
python3 tools/odin_pack.py --out /content/out/AP_nothing_asteroids16_system.tar \
  --manifest /content/out/AP_nothing_asteroids16_system.manifest.json --verify
```

Repeat for the A15 fallback into a *different* filename — never overwrite.

Optional but recommended before step 2, so the fit question is answered:

```bash
python3 tools/super_inspect.py /content/work/a155f/super.img   # system partition size
```

## Gates

| Gate | Requirement |
|---|---|
| G0 | archive MD5 matches the lock file; `gsi_inspect.py` reports a `system.img` member |
| G1 | GSI `system.img` expanded size ≤ target `system` partition size |
| G2 | AP TAR built with `odin_pack.py`, `--verify` OK, plain TAR, one `.img` member |
| G3 | stock `A155FXXS7CYG4` package hashed and on hand; device fused revision read and reconciled (the `Fused 7 > Binary 8` line is still unexplained) |
| G4 | bootloader unlock + AVB decision taken **by the owner**, with warranty/Knox consequences written down |
| G5 | the packaging matches the owner's *already-working* GSI method (tar members, vbmeta handling), confirmed in writing |

Until G0–G4 the artifact stays labelled `built, unflashed, unvalidated`.

## Licensing / attribution

- Do **not** re-upload the GSI zip, nor a derived `system.img`/AP TAR, to this
  repository or any release. It contains Nothing and third-party proprietary
  content that this project has no right to redistribute.
- Credit *Mystic GSI Updates / romashkagene* wherever the work is described, and
  keep the original archive unmodified for inspection.
- "Nothing" is a trademark of Nothing Technology Limited. This is an unofficial,
  community-only experiment, not an official Nothing OS build.
