# 40 — ROM line: donor/target feasibility (deferred, tooling now unblocked)

Build A (kernel/boot bundle) is the first artifact. The ROM line runs in parallel
only as *analysis* until the gates below pass. Nothing here authorises a flash.

## Why phase 2 produced nothing

`phase2-report.txt` shows empty donor **and** target partition tables with the
note "no requested donor logical partitions matched metadata names". The Colab
image had no `lpdump`/`lpunpack`, so neither `super.img` was ever parsed. Every
conclusion drawn from that run is therefore void — not "incompatible", just
*unmeasured*.

`tools/super_inspect.py` fixes that without installing anything: it reads liblp
geometry + metadata header directly and decodes **sparse** images by expanding
only the metadata prefix, so a 7 GB sparse `super` is inspected in seconds.

```bash
# donor (extract images/super.img from Emerald.tgz first)
python3 tools/super_inspect.py /content/work/emerald/images/super.img

# target (super.img.lz4 must be decompressed once; keep the original)
python3 tools/super_inspect.py /content/work/a155f/super.img
```

Output: groups (max/used/free), partitions with computed sizes, physical block
device list, and an explicit `PROBLEM` line if the geometry/header checksum does
not validate. Table bodies are not individually checksummed by liblp, so names
and sizes must be cross-checked against the AP member listing.

## The three candidate combinations

| # | system/product | vendor/odm | boot/kernel | Reality |
|---|---|---|---|---|
| R-a | Emerald (Motorola, A16) | Emerald | Emerald | won't boot: different board, PMIC, panel, touch, TEE |
| R-b | Emerald (A16) | **A155F (A15)** | A155F | only theoretical option; crux = **vendor API level** and HAL ABI |
| R-c | A155F stock (A15) | A155F | A155F + Nothing-inspired UI layer | the only low-risk "Nothing-like" path, still not Nothing OS |

R-b is what a cross-port means. Its blocker is not the SoC (both MT6789) but the
framework/vendor contract:

- the Android 16 framework requires a minimum **vendor API level**; the Samsung
  A15 vendor partition reports an Android 15 level (`ro.vendor.api_level`,
  `ro.board.api_level`, `ro.vendor.build.version.sdk`),
- Motorola's framework links against Motorola vendor HALs (`vendor.motorola.*`,
  `vendor.qti.*` remnants, moto sensors/display features) that do not exist in
  the Samsung vendor image,
- SELinux policy, `vendor_boot` modules and the Samsung AVB/Knox chain are built
  for the Samsung stack only.

Consequence: R-b realistically requires patching the framework to drop Motorola
dependencies and to accept a lower vendor API level — a source-level AOSP task,
not an image swap. **Not started, not promised.**

## Staged plan with gates

**R0 — measure (tooling ready).**
Run `super_inspect.py` on both supers; record group/partition tables and free
space in `docs/30-BUILD-LOG.md`.
*Gate:* both reports show `container: liblp`, geometry + header checksums OK.
If not, the archives are not what the filenames claim — stop and investigate.

**R1 — name/size reconciliation.**
Diff donor vs target partition names, sector sizes and group limits; check whether
`system`, `system_ext`, `product`, `vendor`, `odm`, `my_*` (Samsung) map at all,
and whether the donor's total logical size fits the target's group limits
(donor super ≈ 7.13 GB vs target logical ≈ 9.35 GB before resize).
*Gate:* a written table of matching / missing / oversized partitions.

**R2 — ABI/API triage (read-only, on the images).**
Compare, from the images: `ro.vendor.api_level`, `ro.board.api_level`,
`ro.vendor.build.version.sdk`, `ro.product.*`, and the HAL list in
`vendor/etc/vintf/manifest.xml` on both sides.
*Gate:* the concrete list of missing HALs is short enough to enumerate. If it is
not, R-b is rejected and only R-c remains.

**R3 — packaging plan (no artifact built yet).**
Only if R2 passes: plan the super rebuild (lpmake or a reviewed extent walker),
AVB/vbmeta strategy, and how rollback works. Any plan that needs "disable
verification" is documented as *device-state-changing* and gated on the owner's
explicit decision plus a reconciled `SW REV` reading.

**R4 — device validation.**
Observation-only record: boots / bootloop / recovery only / no display, with
build strings and timestamps. No extrapolation.

## Order of work

1. Build A artifact (kernel/boot bundle) — see `docs/20-FIRST-BUILD.md`.
2. R0/R1 analysis on the images (no device involvement).
3. Nothing OS 5 decision: once the owner supplies a package with device + build
   identity, re-run the same R0/R1 triage against it. A Qualcomm-targeted Nothing
   build on MT6789 remains infeasible regardless of what the triage shows
   (`docs/00-FEASIBILITY.md`).
4. R-c (Nothing-inspired layer) only after a stable base exists on the device, and
   only with independently created or owner-supplied assets.
