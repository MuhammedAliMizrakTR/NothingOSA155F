# 60 — Nothing OS ↔ Android ↔ device map, and what that means for A155F

Facts below are cross-checked against the Nothing device catalogue and the
Nothing OS release history (Wikipedia *Nothing OS*; `spike0en/nothing_archive`;
`nothingota` codename matrix; Android Authority / Android Central rollout
coverage). Where a statement is an inference it says so.

## 1. Nothing OS version ≠ Android version

| Nothing OS | Android base |
|---|---|
| 1.0 – 1.5 | Android 12 → 13 |
| 2.0 | Android 13 |
| 2.5 / 2.6 | Android 14 |
| 3.0 – 3.2 | Android 15 |
| **4.0** | **Android 16** (stable from 2025-11-21, Phone (3) first) |

**There is no "Nothing OS 14".** The `14` in a MysticGSI filename is the
**Android** version, not the Nothing OS version. `Nothing-Spacewar-14` = Phone (1)
framework on Android 14 = Nothing OS 2.6 — three generations old, not "OS 14".

## 2. Codename → device → factory OS

| Codename | Device | Model | Factory firmware | Gets |
|---|---|---|---|---|
| Spacewar / Abra | Phone (1) | A063 | NOS 1.0 (A12) | ended at NOS 3.2 (A15) |
| Pong / Alakazam | Phone (2) | A065 | NOS 2.0 (A13) | NOS 4.0 beta (A16) |
| Pacman / Aerodactyl | Phone (2a) | A142 | NOS 2.5 (A14) | NOS 4.0 beta (A16) |
| PacmanPro | Phone (2a) Plus | A142P | NOS 2.6 (A14) | NOS 4.0 beta (A16) |
| **Asteroids / Arcanine** | **Phone (3a) / (3a) Pro** | A059 / A059P | **NOS 3.0 (A15)** | **NOS 4.0 (A16)** |
| **Metroid / Arbok** | **Phone (3)** | A024 | **NOS 3.5 (A15)** | **NOS 4.0 (A16)** — first device |
| Galaxian | Phone (3a) Lite | A001T | NOS 3.5 (A15) | NOS 4.0 in early 2026 |
| Tetris / Beedrill | CMF Phone 1 | A015 | NOS 2.6 (A14) | NOS 3.2 (A15) |
| Galaga | CMF Phone 2 Pro | A001 | NOS 3.2 (A15) | NOS 4.0 |

Hardware reality of the two donors that matter here:

| Donor | SoC | RAM tiers | Target A155F |
|---|---|---|---|
| Asteroids = Phone (3a) | Snapdragon 7s Gen 3 | 8 / 12 GB | Helio G99, 4–8 GB |
| Metroid = Phone (3) | Snapdragon 8s Gen 4 (flagship) | 12 / 16 GB | same |

## 3. Decoding the MysticGSI filenames

Pattern: `<device>-<android major>-<build stamp>-AB-<release date>-MysticGSI.zip`

| File | Means | Nothing OS generation |
|---|---|---|
| `Nothing-Asteroids-16-…-20260111` | Phone (3a) framework, **Android 16** | **Nothing OS 4.x** |
| `Nothing-Metroid-15-…-20250727` | Phone (3) framework, Android 15 | Nothing OS 3.5 |
| `Nothing-Asteroids-15-…-20250508` | Phone (3a) framework, Android 15 | Nothing OS 3.0–3.2 |
| `Nothing-Galaga-15-…` | CMF Phone 2 Pro, Android 15 | Nothing OS 3.2 |
| `Nothing-Spacewar-14-…` | Phone (1), Android 14 | Nothing OS 2.6 |

So: **"Nothing OS 4" = `Nothing-Asteroids-16`.** It is the only OS 4 build in the
folder; there is no `Metroid-16`.

## 4. "Will the heavier donor load my phone more?" — the honest mechanics

The owner's intuition ("a flagship-based build is built for stronger hardware")
is reasonable but it is **not the dominant variable**. What actually costs:

1. **Android base.** A16 framework + ART is measurably larger and hungrier than
   A15 on a 4–8 GB device. This is the single biggest factor.
2. **Nothing's own additions in OS 4.** AI-generated widgets, expanded Glyph
   integrations, new Pop-up View — these add services and callouts. On a device
   with no Glyph hardware and no Nothing AI backend entitlement, they either idle
   or fail/timeout. Cost is real but mostly idle-time, not a constant tax.
3. **Spoofed product props.** A GSI carries the donor's `ro.product.*`. Those props
   gate features; they do **not** change CPU frequency, RAM allocation or zram
   (those come from the Samsung `vendor`, which we keep). So "pretending to be a
   flagship" does not itself make the device slower.
4. **Donor RAM tier.** This is where a flagship donor can hurt: configs and
   default thresholds tuned for 12–16 GB (`hwui`, cached-app limits, background
   limits) are not automatically relaxed just because the real device has 4–8 GB.

Conclusion: **same donor device (Asteroids = 3a), newer Android (16) is the
heavier of the pair; but it is still lighter than a flagship donor.** So the OS 4
build is *both* the newest and a sane choice — the owner's preference and the
engineering preference agree, for once. The A15 counterpart of the same donor
(`Asteroids-15`) remains the safer first attempt because it matches the A155F
vendor generation, not because it is "weaker".

## 5. Kernel: untouched, and the owner's own evidence

A GSI changes only `system`; `boot`/`vendor_boot`/kernel and `vendor`/`odm` stay
Samsung. So for the Nothing GSI **no kernel work is needed** — the `bakasu` kernel
can stay exactly as it is. Root (KernelSU/SusFS) is a separate, optional layer.

Owner-reported evidence worth recording (single device, not independently
verified): the `bakasu` kernel booted a *RestlessOS 17* GSI (an Android 17 /
GrapheneOS-fork-based GSI). If true, that is strong evidence that:
- the bootloader/AVB path for GSIs already works on this device,
- the A155F vendor tolerates frameworks **newer** than its own Android 15 vendor,

which weakens (does not remove) the "A16 over A15 vendor" risk. It also means the
existing, already-proven flashing method should be reused verbatim rather than
invented here — **that method is the missing piece of the pipeline**, see
`docs/50-GSI-LINE.md`.

## 6. Decision for this project

| Priority | Artifact | Why |
|---|---|---|
| 1 | `Nothing-Asteroids-16-…-20260111` (OS 4 / A16) | owner's target; mid-range donor matches Helio G99; only OS 4 build available |
| 2 | `Nothing-Asteroids-15-…-20250508` (OS 3.x / A15) | same donor, vendor-matched generation → highest boot probability if #1 loops |
| 3 | `Nothing-Metroid-15-…-20250727` (OS 3.5 / A15) | flagship donor, heaviest of the three; only if the others misbehave |
| — | `Nothing-Spacewar-14-…` | only if "OS 14" was literally meant; Phone (1), three generations old |
