# 10 — Pinned inputs and Drive inventory

Everything a build may read is pinned in `inputs/inputs.lock.json` (Drive file
id, exact byte size, Drive-reported MD5). `tools/verify_inputs.py` refuses to
pass when a local copy does not match.

## Drive scope searched

| Folder | Drive id |
|---|---|
| `/GrapheneOS` | `14cSvc-xj7tAciNzr8dJmNJj-8Avw3SsN` |
| `/HyperOSA155F` | `1bwiwO8EmnQdSyXSwfo7zSdBhBOXkRZ9f` |

A Drive-wide search for `Nothing` on 2026-11-22 returned **0 files**. No shared
drives exist on the account. So: *Nothing OS 5 is not in the Drive scope this
session can reach* — it must be uploaded, or the claim corrected.

## `/GrapheneOS` contents (observed 2026-11-22)

| Name | Size (B) | Drive MD5 | Role |
|---|---|---|---|
| `SAMFW.COM_SM-A155F_XSG_A155FXXS7CYG4_fac.zip` | 6,904,157,493 | `bea1131d9bddabc5630411a982059b57` | target stock firmware (rollback source) |
| `SAMFW.COM_SM-A155F_XSG_A155FXXS7CYG4_fac.zip adlı dosyanın kopyası` | 6,904,157,493 | `bea1131d9bddabc5630411a982059b57` | byte-identical duplicate |
| `bakasu_35262_susfs_v2.4.0_A155FXXS7CYG4_A15_GKI.tar` | 67,112,960 | `39800312d85035ff2c8f94bdf5f38054` | kernel artifact — **owner's first choice** |
| `kernelsunext_33548_susfs_v2.4.0_A155FXXS7CYG4_A15_GKI.tar` | 67,112,960 | `472a59d49fcc94c4a66ff4186210cd65` | kernel artifact — fallback |
| `stock_optimized_5.10.226_A155FXXS7CYG4_A15_GKI.tar` | 67,112,960 | `161fe2dbb5cfc5420727fd7f89ed9342` | kernel artifact — reference/rollback |

Observations, marked as such:

- All three kernel files are **exactly** the same size (67,112,960 B = 65,540 KiB).
  Arithmetic check: one 67,108,864 B (64 MiB) member + 512 B header, padded to a
  10,240 B tar record = 67,112,960 B — exactly the observed size. A synthetic TAR
  built with `tools/odin_pack.py` from a single 64 MiB image produced the identical
  byte count. So the most likely shape is *one plain 64 MiB image member, no MD5
  footer*, i.e. an Odin AP-style boot TAR keyed to `A155FXXS7CYG4`.
  **This is arithmetic consistency, not proof** — run `tools/tar_inspect.py` on the
  real files before relying on it.
- Names end in `_A15_GKI`, i.e. Android 15 / GKI. They are **prebuilt boot
  artifacts**, not kernel source trees. Nothing in Drive is a compilable kernel.

## `/HyperOSA155F` contents

| Name | Size (B) | Role |
|---|---|---|
| `Emerald.tgz` | 7,664,845,630 | Motorola `emerald` full-ROM donor (`emerald_id_global_images_OS3.0.303.0.WNFIDXM_16.0`, MT6789, Android 16) |
| `SAMFW.COM_SM-A155F_XSG_A155FXXS7CYG4_fac.zip` | 6,904,157,493 | second copy of target firmware |
| `stock_optimized_…_GKI.tar`, `kernelsunext_…_GKI.tar`, `bakasu_…_GKI.tar` | 67,112,960 each | copies of the kernel artifacts |
| `phase1-report.txt`, `phase2-report.txt`, `emerald-contents.txt`, `a155f-contents.txt` | ≤ 4 KB | prior Colab experiments (read-only history) |

The prior `phase2` run reported *empty* donor and target logical-partition
tables and "no requested donor logical partitions matched metadata names" — the
Colab image had no `lpdump`/`lpunpack`, so **nothing about partition
compatibility is established**. Treat `emerald` as unproven.

## Target AP members (from `phase1-report.txt`, donor archive listing)

```
boot.img.lz4         21020551
vendor_boot.img.lz4   8580297
dtbo.img.lz4           98045
super.img.lz4     5865008566
vbmeta.img.lz4          3515
vbmeta_system.img.lz4   2819
```

Stock AP members are **LZ4-compressed**, which is normal for a stock Samsung
release but is *not* acceptable for our own repackaged AP artifact: those must be
plain TAR members (see `docs/20-FIRST-BUILD.md`).

## Still missing

- Nothing OS 5 package (any version), with device/build identity.
- Compilable kernel sources: GKI `common` 5.10.226 tree + A155F device tree +
  Samsung vendor modules, if a real kernel build is wanted.
- Device-side truth: fused `SW REV` value, current build number, unlock state.
