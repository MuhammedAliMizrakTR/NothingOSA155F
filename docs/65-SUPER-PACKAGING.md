# 65 — Odin AP packaging for a GSI: `system.img` vs `super.img`

This answers one question: **what exactly should the AP TAR contain on an SM-A155F
so that a Nothing GSI can boot and the Samsung/MTK vendor survives?**

The owner's current package puts the GSI content in as **`super.img`**. That is
only safe in one of the three shapes below, and the difference is not cosmetic —
it decides whether `vendor`/`odm` still exist after the flash.

## What "super" actually is on this device

`super` is one *physical* partition that holds several *logical* partitions —
`system`, `system_ext`, `product`, `vendor`, `odm`, `vendor_dlkm`, `odm_dlkm`, …
Their names, sizes and group limits live in liblp metadata at the start of the
image. Measured facts for the pinned firmware (`A155FXXS7CYG4`):

| Item | Value | Source |
|---|---|---|
| `super.img.lz4` in stock AP | 5,865,008,566 B | `phase1-report.txt` (tar listing) |
| `super` decompressed | 9,352,091,512 B | `phase2-report.txt` |
| logical partitions | not yet parsed — run `tools/super_inspect.py` | — |

**Odin writes a member named `super.img` to the whole physical super partition.**
Everything logical inside it is replaced: if the new image does not itself contain
`vendor` and `odm`, the device has no MTK RIL, display, camera or audio HALs left.

## Three shapes, three risk levels

| | AP TAR member | Odin target | vendor/odm | Risk |
|---|---|---|---|---|
| **A** | `system.img` only | logical `system` inside super | untouched (Samsung) | **lowest** — the usual Samsung-GSI shape |
| **B** | `super.img` built with `lpmake`, containing GSI `system` **plus** Samsung `vendor`/`odm`/`vendor_dlkm`/`odm_dlkm` | whole super | preserved (re-packed) | medium — exact size and group limits must match |
| **C** | `super.img` that is the GSI image itself, a GSI-only super, or a renamed `system.img` | whole super | **destroyed** | **critical** — will not boot; only a full stock Odin flash brings it back |

Shape C is the trap. A 2 GB `system.img` renamed to `super.img` is *not* a super:
it has no liblp metadata and no `vendor`, so Odin happily wipes the partition that
holds them. The file will look like a perfectly valid TAR; only its contents give
it away.

## Audit the package you already built (read-only, no device)

```bash
python3 tools/odin_audit.py /path/to/AP_whatever.tar
```

It reports, from the bytes only:

- plain TAR / any LZ4 member / appended MD5 fingerprint,
- each member's real container (`android-sparse`, `ext4`, `erofs`, `liblp`),
- for a super member: the liblp partition table, and **whether `vendor`/`odm`
  exist**,
- a verdict: `clean` (0), `warnings` (1), `critical` (2).

Critical findings and what they mean:

| Finding | Meaning |
|---|---|
| `super-not-lp` | the "super" is a raw/sparse filesystem, not a liblp image → shape C |
| `super-missing-vendor` | valid super but no `vendor`/`odm` → no Samsung HALs |
| `lz4-member` | Odin AP members must be raw images |
| `md5-footer` | violates the plain-TAR packaging rule (not fatal to Odin, fatal to our manifest policy) |

Run it with `--json` to keep the output next to the artifact; the SHA-256 it prints
is what goes into `docs/30-BUILD-LOG.md`.

## Note: the ported pipeline builds shape B on purpose

`rom/repack-super.sh` + `rom/lp_plan.py` (from the owner's GrapheneOS port) build a
**hybrid super**: the GSI becomes `system`, while `vendor`/`product`/`odm`/… are
carried over byte-identical from the stock firmware, and the stock geometry is
preserved. That is shape B below, and it is the sanctioned path in this repo — see
`docs/70-BUILD-RECIPE.md`. Shape C is what `tools/odin_audit.py` refuses.

## Recommended path

1. **Build shape A first**: extract `system.img` from the GSI and tar *only* that.

   ```bash
   python3 tools/gsi_inspect.py <gsi>.zip                    # md5 + expanded size
   python3 tools/gsi_inspect.py <gsi>.zip --extract /content/work/gsi --only system.img
   python3 tools/odin_pack.py --out /content/out/AP_nothing_asteroids16_system.tar \
     --manifest /content/out/AP_nothing_asteroids16_system.manifest.json \
     /content/work/gsi/system.img
   python3 tools/odin_audit.py /content/out/AP_nothing_asteroids16_system.tar
   ```

2. **Only if the device rejects shape A** (or if the proven method needs it), build
   shape B with `lpmake`: unpack the *stock* super (`lpunpack`), keep Samsung
   `vendor`/`odm`/`vendor_dlkm`/`odm_dlkm`, swap `system` for the GSI's, and size
   groups to the values read from the stock metadata (`super_inspect.py --json`).
   Output size must be 9,352,091,512 B.

3. **Never** ship shape C. If `odin_audit.py` says `critical`, rebuild — do not
   "fix" the archive by renaming members.

## What this does and does not claim

- Shape A matches the packaging shape most Samsung-GSI guides use. Whether *this*
  Odin version and *this* bootloader accept it is unproven here — the owner's own
  working GSI flash (RestlessOS 17, owner-reported) is the reference to copy.
- None of this is validated on a device by this repository. `odin_audit.py` proves
  packaging properties, not bootability.
