# 70 — Build recipe: Nothing GSI → Odin AP, exactly like the GrapheneOS port

The owner's GrapheneOS/RestlessOS port already established the working recipe on
SM-A155F. That pipeline is now ported into `rom/` here (see `rom/README.md` for
provenance: source repo `MuhammedAliMizrakTR/GrapheneOS-SM-A155-`, commit
`46b586a5`, Apache-2.0), with only the AP filename made configurable.

So the answer to "package it the way GrapheneOS was packaged" is: **the same
shape**, with the Nothing GSI substituted for RestlessOS as the `system`
partition.

## The shape (unchanged from the GrapheneOS build)

```
AP_SM-A155F_NothingOS-<TAG>_<kernel>_<A155FXXS7CYG4>.tar   ← plain TAR, flashed as-is
├── boot.img            raw kernel from the owner's kernel TAR (bakasu by default)
├── super.img           rebuilt sparse super:  system = Nothing GSI
│                                              vendor/product/odm/system_ext/… = stock bytes
└── vbmeta*.img         avbtool --flags 3 (verification + verity disabled)
```

That `super.img` is the **hybrid super (shape B)** from
`docs/65-SUPER-PACKAGING.md` — legitimate, because `rom/lp_plan.py` carries the
stock vendor stack into the new super instead of dropping it. This is precisely
why the owner's `super.img` instinct was right and my earlier "renamed system
image" warning does not apply to *this* pipeline: `odin_audit.py` will now show
`vendor`/`odm` present.

## Inputs (all pinned)

| Input | Where | Verification |
|---|---|---|
| `Nothing-Asteroids-16-2511181551-AB-20260111-MysticGSI.zip` | Drive `NothingOSA155F` (`1shSCd0l5P…`) | MD5 `152a92ab…c33c`, Drive value == SourceForge value, 2,333,520,539 B |
| `bakasu_35262_susfs_v2.4.0_A155FXXS7CYG4_A15_GKI.tar` | Drive `/GrapheneOS` | MD5 `39800312…8054`; `boot.img` extracted |
| `SAMFW.COM_SM-A155F_XSG_A155FXXS7CYG4_fac.zip` | Drive `/GrapheneOS` | MD5 `bea1131d…9b57` |

## Run it (Colab or any Linux box with the Drive mount)

```bash
# 1. one-shot: toolchain → inputs → extract → super → vbmeta → AP → audit
INPUTS_DIR="/content/drive/MyDrive/NothingOSA155F" \
KERNEL_VARIANT=bakasu ROM_NAME=NothingOS \
bash rom/gsi-build.sh
```

Or stage by stage:

```bash
bash rom/tools.sh                                             # lpmake/lpunpack/lpdumps, lz4, e2fsprogs, avbtool
bash rom/gsi-inputs.sh                                        # MD5 gate + unsparse + boot.img + firmware
bash rom/extract-ap.sh                                        # stock member list/order + super + small members
bash rom/repack-super.sh                                      # lpdump → lpunpack → lp_plan → lpmake
bash rom/make-vbmeta.sh                                       # flags=3 for every vbmeta* member
bash rom/pack-ap.sh                                           # plain TAR + SHA256SUMS + transport parts
python3 tools/odin_audit.py out/AP_SM-A155F_NothingOS-*.tar    # hard gate
```

Notes from the port:

- `gsi-inputs.sh` unsparses the GSI's `system.img` first (`rom/simg2img.py`)
  because `lpmake --image` needs raw bytes. Passing a sparse image would silently
  produce a wrong-sized partition.
- Optional: `SKIP_GSI_EXTRAS=0` embeds `/system/etc/a155f-extras/` (the owner's
  RILFix module + A155F presets) into the GSI before repacking.
- `pack-ap.sh` splits the TAR into 1900 MB transport parts and writes a SHA-256
  manifest; parts are not flashable, the TAR is.

## What was verified here (synthetic, not the real build)

A full synthetic dry run was executed in this repository — synthetic stock AP
(`super.img` built with real `lpmake`), synthetic GSI zip, synthetic kernel TAR,
the owner's scripts unmodified — and it produced:

```
AP_SM-A155F_NothingOS-Demo-A16_bakasu_A155FXXS7CYG4.tar   138,700,800 B
  boot.img   raw 134,217,728 B  android-boot
  super.img  liblp partitions: system(4194304), vendor(3145728), odm(2097152), product(2097152)
  vbmeta.img / vbmeta_system.img  flags=3
VERDICT: clean   (plain TAR, no MD5 footer, no LZ4 members)
```

That run also caught two real parser bugs in `tools/super_inspect.py` that the
synthetic fixtures had missed, because they only appear with genuine `lpmake`
output:

1. **backup geometry** — the metadata header starts at 12288, not 8192 (liblp
   keeps a second geometry block);
2. **v1.x table layout** — `tables_size` + `tables_checksum` live at header
   offsets 44/48 and the descriptors start at 80, with offsets relative to the
   table payload. The payload checksum is now verified, so a corrupted table body
   is reported instead of mis-parsed.

Both are fixed, with regression tests (sparse FILL/DONT_CARE chunk resync, mixed
chunk order, table-payload checksum).

## Real-input failure modes already fixed (from the 2026-11-22 Colab run)

The first run against the owner's actual Drive folder got as far as the GSI and
then died at the kernel step. Four fixes came out of it, all in the repo now:

1. **Drive copy suffix.** Copying a file into a Drive folder renames it locally to
   `…_GKI.tar adlı dosyanın kopyası`, `…zip (1)`, `… - copy`. `gsi-inputs.sh` used
   exact paths and reported `FATAL: kernel tar not found`. It now resolves each
   expected base name exactly first and then as `<name>*` (largest match wins),
   prints which file it used, and stages the firmware as the canonical
   `work/fw/<FW_VERSION>_fac.zip` so spaces never reach later steps. The MD5 pin
   also matches on the longest pinned prefix, so a renamed GSI zip still gates.
2. **A "PROBLEM" that was not one.** `tools/gsi_inspect.py` flagged any
   `system.img` over 4 GiB as a problem; the real GSI is 4,876,709,888 B, which is
   normal. It is now a `NOTE:` saying the rebuilt super must reserve that much for
   `system` (and that `lp_plan.py` fails loudly if it cannot).
3. **`head` + `pipefail` race in `rom/tools.sh`.** `debugfs -V | head -1` made
   `debugfs` take SIGPIPE, and `set -o pipefail` aborted the build at step 1/8 with
   rc=141 — intermittently, which is why earlier runs passed. Now `sed -n '1p'`.
4. **Misleading label** in `pack-ap.sh`: the super line said `RestlessOS` for a
   Nothing build; it now prints `${ROM_NAME}`.

Re-verified after the fixes, on synthetic inputs named *exactly* like the owner's
Drive copies (`…tar adlı dosyanın kopyası`, doubled firmware suffix, an unrelated
`NothingOSA155F-src.zip` in the folder): the whole `rom/gsi-build.sh` chain ran to
`VERDICT: clean`, rc=0, 7 s, producing the same 138,690,560 B AP shape.

## The real build (2026-11-22, owner's Colab, real inputs)

Done — the worry about `system` fitting was unfounded. `lp_plan.py` takes the
device size from the stock super geometry, and the rebuilt super expands to
**11,744,051,200 B**, exactly the stock partition size:

```
out/AP_SM-A155F_NothingOS-Asteroids-A16_bakasu_A155FXXS7CYG4.tar
  10,904,903,680 B   sha256 a141847c…329b34
  plain tar, no MD5 footer, no LZ4 member
  super.img: system 4,876,709,888 | product 1,837,219,840 | vendor 1,184,497,664
             system_ext 525,639,680 | vendor_dlkm 36,745,216 | odm 1,650,688
```

Full member/size table: `docs/30-BUILD-LOG.md`. The single audit finding was
`member 'meta-data' is not a regular file`, which is a stock Samsung directory
entry — now a `NOTE`, so this package audits `clean`.

Observations that matter before any flash:

* `userdata.img` (stock, 1.42 GB sparse → 17.2 GiB) is still a member, so flashing
  this AP wipes user data like a stock AP does;
* `recovery.img` is the stock one — no custom recovery;
* boot is **unmeasured**; A16 GSI on an A15 vendor stack is the known risk.

## If the next build is blocked somewhere

Only the gates in `docs/50-GSI-LINE.md` apply. A group-capacity `FATAL` from
`lp_plan.py` would mean the A15 build (smaller, vendor-matched) is the next lever,
not shrinking the A16 image.

## The single file (what the owner actually runs)

Everything above is packaged into **one file** — no zip, no repo clone, no extra
download:

```
NothingOSA155F-colab.sh    ~121 KB    header (colab_build.sh) + marker + base64(source zip)
```

In Colab, one cell:

```python
from google.colab import drive; drive.mount('/content/drive')
!bash "/content/drive/MyDrive/NothingOSA155F/NothingOSA155F-colab.sh"
```

What it does, in order: detects its embedded payload, unpacks the repo into
`WORKDIR` (default `/content/NothingOSA155F`), warns if free disk is under 25 GB,
runs the unit tests (27), checks `INPUTS_DIR` (default the mounted Drive folder),
then runs `rom/gsi-build.sh` with output tee'd to `build.log`, deletes the 1900 MB
transport parts (`SINGLE_FILE=1`), and prints AP size, sha256, manifest and the
audit verdict. Env overrides: `INPUTS_DIR`, `WORKDIR`, `KERNEL_VARIANT`,
`ROM_NAME`, `SKIP_GSI_EXTRAS`, `SINGLE_FILE`, `SKIP_BUILD`.

`colab_build.sh` in the repo root is the same header without a payload: run it
from inside the repo (`bash colab_build.sh`) for the identical flow without
unpacking.

Published copy: the file `NothingOSA155F-colab.sh` in Drive folder
`NothingOSA155F` (~125 KB) — take the current copy from the folder listing.

No fixed hash or Drive id is pinned in this repository, and deliberately so: the
lock file and these docs travel *inside* the payload, so anything that names the
artifact's own hash would change that hash. The builder prints the sha256 of the
bytes it wrote; compare that line with `sha256sum NothingOSA155F-colab.sh` after
downloading, and re-upload whenever the repo changes.

```python
from google.colab import drive; drive.mount('/content/drive')
!bash "/content/drive/MyDrive/NothingOSA155F/NothingOSA155F-colab.sh"
```

### How the single file is produced (never hand-edited)

```bash
bash tools/make_single_file.sh          # -> NothingOSA155F-colab.sh
```

The builder refuses to run if `colab_build.sh` contains a bare marker line, zips
exactly the sources the build needs (42 files: `rom/`, `tools/*.py`, `docs/`,
`tests/`, `inputs/`, `README.md`, `CHANGELOG.md`, `.gitignore`, `colab_build.sh`,
`tools/make_single_file.sh`) with a fixed mtime, and appends the marker plus a
76-column base64 payload. Toolchains (`.git`, `tools/lptools`, `tools/avb`,
`tools/lz4`, `tools/e2fsprogs`) are **not** embedded — the file provisions them
itself via `rom/tools.sh` on first run (a few minutes, no apt).

**Rebuild it after any repo edit** — otherwise the file carries stale sources.

### Verified end-to-end (synthetic inputs, real toolchain)

`INPUTS_DIR=/tmp/fakeinputs2 WORKDIR=/tmp/e2e2 bash NothingOSA155F-colab.sh` on a
clean workspace — the file unpacked itself, cloned and built the whole toolchain
from scratch, ran the tests, built and audited the AP, and exited **rc=0**:

```
=== SONUÇ
AP TAR  : out/AP_SM-A155F_NothingOS-Demo-A16_bakasu_A155FXXS7CYG4.tar
boyut   : 138690560 bayt
sha256  : 9db77445c3fdedee51fd1f2d692661fcb622d3fd99d27aead6b600148537375e
manifest: out/dist/AP_..._A155FXXS7CYG4.SHA256SUMS.txt
audit   : out/AP_...audit.txt
          plain tar: True   md5 footer: False
          members  :
            - boot.img             raw=    134217728 expanded=134217728 container=android-boot
            - super.img            raw=      4464748 expanded=100663296 container=android-sparse
            - vbmeta.img           raw=          256 expanded=256 container=unknown
            - vbmeta_system.img    raw=          256 expanded=256 container=unknown
          VERDICT: clean
```

`out/dist/` afterwards held only the `.SHA256SUMS.txt` — the transport parts were
removed, so the owner ends up with exactly one TAR. Total wall time 52 s.

Two bugs this run exposed and that are fixed in the header:

1. the header ended without `exit 0`, so once the build finished the shell fell
   through and tried to execute the base64 payload as commands (rc=127 after an
   otherwise successful build);
2. the audit summary was built with `tail -3 … | tr '\n' ' '`, which flattened
   the report into one unreadable line; it now prints the verdict line and the
   member table properly.

## What this still does not claim

- No real artefact has been built: the 2.3 GB GSI and the 6.9 GB firmware are not
  in this sandbox, and the sandbox cannot reach SourceForge.
- Booting the resulting AP is **unmeasured**. `odin_audit.py` proves packaging
  properties only.
- Flashing remains the owner's decision, gated on the reconciled `SW REV`/fused
  revision from `docs/20-FIRST-BUILD.md` (G3) and on having the stock package.
