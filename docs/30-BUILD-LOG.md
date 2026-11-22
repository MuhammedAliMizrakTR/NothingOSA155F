# 30 — Build log (append-only, newest last)

This log records what was **observed**. Nothing here is a device result unless it
says so explicitly. Never delete an entry; correct it with a new one.

## 2026-11-22 — repository + Drive audit (no build executed)

- Repo `NothingOSA155F` at `4cf3f43` ("Initial commit") contained only a 30-byte
  README. No source, no scripts, no release assets.
- Drive search `name contains 'Nothing'` (whole account, shared drives included):
  **0 results**. No Nothing OS 5 package is reachable.
- `/GrapheneOS` (`14cSvc-xj7tAciNzr8dJmNJj-8Avw3SsN`) inventory recorded in
  `inputs/inputs.lock.json`: stock `A155FXXS7CYG4` XSG zip (6,904,157,493 B, MD5
  `bea1131d…9b57`) + one byte-identical duplicate, and three 67,112,960 B kernel
  boot TARs (`bakasu` MD5 `39800312…8054`, `kernelsunext` `472a59d4…0cd65`,
  `stock_optimized` `161fe2db…9342`).
- `/HyperOSA155F` holds the Motorola `emerald` Android 16 donor (`Emerald.tgz`,
  7,664,845,630 B) and prior Colab reports. `phase2-report.txt` shows donor/target
  logical-partition tables were **empty** (no `lpdump`/`lpunpack` in that image),
  so partition compatibility is unproven.
- Added tooling: `tools/verify_inputs.py`, `tools/tar_inspect.py`,
  `tools/odin_pack.py`, and synthetic tests. `python3 -m unittest discover -s tests`
  → 11 tests OK. **Synthetic fixtures only** — these prove the scripts, not any
  firmware or kernel artifact.
- Not done, pending owner data: TAR inspection of the real kernel artifacts,
  Build A repack, any device action.

- Added `tools/super_inspect.py` (+4 synthetic tests, 15 total) so the ROM line can be
  measured without `lpdump`/`lpunpack`. Not yet run on the real donor or target super:
  both need extraction from the 6.9 GB / 7.7 GB archives first.
- Owner decision recorded: first build = kernel/boot bundle **and** ROM line in
  parallel; the Nothing OS 5 package will be supplied as a link/name by the owner
  (it is not in the reachable Drive scope).

### Open questions at this point

1. Where is Nothing OS 5, and for which device/build?
2. Does "ilk build" mean the kernel/boot bundle (Build A) or a full ROM?
3. Device fused revision / build number / unlock state.
4. Are kernel *sources* (GKI common 5.10.226 + A155F device tree) available?

## 2026-11-22 — GSI route opened (analysis + tooling only)

- Owner supplied the GSI source: `sourceforge.net/projects/mystic-gsi-updates/files/Nothing/`
  (Mystic GSI Updates, owner *romashkagene*, Telegram `t.me/mysticgsi`). 23 files,
  40.6 GB total in that folder.
- Pinned four candidates with MD5s taken from the project RSS feed (sizes rounded
  by the listing page): Asteroids-16 (2.3 GB, `152a92ab…c33c`), Metroid-15
  (3.0 GB, `2e846c02…f5b1`), Asteroids-15 (2.0 GB, `08b085d4…e2cb`), Spacewar-14
  (1.6 GB, `282f3a70…c610`).
- Evidence against optimism: a public review of the same project reports
  "bootloops, i tried on a235f, BOOTLOOP" — `SM-A235F` is Samsung + MediaTek like
  A155F. This is one report on a different device, not a verdict on A155F.
- No file downloaded, no zip inspected, no AP TAR built, no device action.
  Next step is owner-side: download one candidate, run `tools/gsi_inspect.py`,
  record the real MD5 and expanded `system.img` size here.

### 2026-11-22 — version map + owner-reported kernel/GSI evidence

- Clarified with sources: Nothing OS 4.0 = Android 16 (stable 2025-11-21, Phone (3)
  first); Nothing OS 3.x = Android 15; 2.5/2.6 = Android 14. Codenames: Asteroids =
  Phone (3a)/(3a) Pro, Metroid = Phone (3), Galaga = CMF Phone 2 Pro, Spacewar =
  Phone (1). "Nothing OS 14" is not a version — the `14` in filenames is Android.
- Consequence: the only Nothing OS 4 build in the MysticGSI folder is
  `Nothing-Asteroids-16` (Phone (3a) framework). Fallback ranking corrected:
  Asteroids-15 (#1 fallback, matched generation, mid-range donor) before
  Metroid-15 (#2, flagship donor, heaviest).
- Owner-reported (not independently verified): `bakasu` kernel booted a RestlessOS 17
  GSI (Android 17 / GrapheneOS-fork). Recorded as device evidence for the GSI path;
  the exact flashing method used for it is still unknown and is now gate G5.

### 2026-11-22 — owner built a `super.img`-shaped AP TAR

- Owner reports: GSI packed into the AP TAR **as `super.img`**, no LZ4, no MD5
  footer. Content unverified — `tools/odin_audit.py` was added to check it.
- Critical distinction recorded in `docs/65-SUPER-PACKAGING.md`: a member named
  `super.img` is written to the whole physical super partition, so a GSI-only or
  renamed-`system` super removes `vendor`/`odm` and cannot boot.
- Drive folder `NothingOSA155F` (`184SfXD3X5-9jBgB5YnAsvgV2Sjg4Si6W`) created by the
  owner; it held four byte-identical copies of the pinned kernel TARs plus the stock
  firmware zip at audit time (MD5s match). No GSI uploaded yet.

### 2026-11-22 — GSI uploaded, GrapheneOS pipeline ported, synthetic build green

- Drive `NothingOSA155F` now holds `Nothing-Asteroids-16-2511181551-AB-20260111-MysticGSI.zip`
  (id `1shSCd0l5PveyzzC1Q9K-fnc63on6WHp_`), **2,333,520,539 bytes**, MD5
  `152a92ab392e1cab111f7e7474cec33c`. Drive's own MD5 equals the SourceForge RSS
  value, so the G0 gate is met without a download.
- Owner's GrapheneOS/RestlessOS packaging recipe reviewed from
  `github.com/MuhammedAliMizrakTR/GrapheneOS-SM-A155-` @ `46b586a5`: plain AP TAR with
  raw `boot.img`, a **hybrid sparse super** (GSI `system` + stock vendor stack via
  `lpdump`/`lpunpack`/`lpmake`), and `avbtool --flags 3` vbmeta images. Ported into
  `rom/` verbatim (one filename patch) plus `gsi-inputs.sh` / `gsi-build.sh`.
- Synthetic end-to-end dry run **passed**: real `lpmake` super, synthetic GSI zip and
  kernel TAR, full `extract-ap → repack-super → make-vbmeta → pack-ap` chain, final
  `odin_audit.py` verdict `clean`, super exposing `system/vendor/odm/product`.
- The dry run caught two real `tools/super_inspect.py` bugs (backup geometry offset,
  v1.x table layout with `tables_checksum`); both fixed with regression tests.
- Still no real build and no device action: the GSI/firmware cannot be fetched in this
  sandbox, so the real run must happen in the owner's Colab.


## 2026-11-22 — single-file runner, full-chain self-test passed

Observed, in this sandbox, on a clean workspace (`/tmp/e2e5`), with synthetic
inputs only:

`INPUTS_DIR=/tmp/fakeinputs2 INPUTS_LOCK=/tmp/fakeinputs2.lock.json
WORKDIR=/tmp/e2e5 bash NothingOSA155F-colab.sh`

- the file unpacked its own base64 payload (42 files) into `WORKDIR`;
- `rom/tools.sh` cloned and built the whole toolchain from scratch
  (`lpmake`/`lpunpack`/`lpdumps` static, lz4 v1.11.2, e2fsprogs 1.47.4, avbtool) —
  nothing was pre-provisioned;
- `python3 -m unittest discover -s tests` → 27 tests OK;
- the pipeline built `out/AP_SM-A155F_NothingOS-Demo-A16_bakasu_A155FXXS7CYG4.tar`
  (138,690,560 B) and audited it: plain TAR, no MD5 footer, `super.img` real liblp
  with system/vendor/odm/product, `VERDICT: clean`;
- `SINGLE_FILE=1` left only the TAR plus `out/dist/*.SHA256SUMS.txt` (transport
  parts removed);
- exit code **0**, wall time ~50 s.

Fixed by this run: the header ended without `exit 0` (the shell then executed the
base64 payload as commands → rc=127 after an otherwise successful build), and the
audit summary was flattened with `tr '\n' ' '` into one unreadable line.

Note for the next session: `tools/lptools` and `tools/avb` (gitignored) had
disappeared from the sandbox between turns; `bash rom/tools.sh` restores them in
under a minute. Never assume they are present.

## 2026-11-22 — first real Drive run (owner, Colab) and what it broke

Owner ran `NothingOSA155F-colab.sh` against the real folder. Reached step 2/8 and
stopped:

- toolchain: built fine in Colab (lpmake static, lz4 1.11.2, e2fsprogs 1.47.4);
- 27 unit tests OK;
- GSI: `Nothing-Asteroids-16-2511181551-AB-20260111-MysticGSI.zip`,
  2,333,520,539 B, MD5 `152a92ab392e1cab111f7e7474cec33c` == pinned → **G0 gate
  passed**;
- GSI zip holds exactly one member: `system.img`, 4,876,709,888 B, ext4, not
  sparse → staged raw as-is; TAG `Asteroids-A16`;
- **kernel step failed**: the Drive files are named `…tar adlı dosyanın kopyası`,
  so the exact-path lookup missed them (`FATAL: kernel tar not found`).

Fixes applied: Drive-copy-suffix resolution (kernel, firmware, GSI pin), canonical
`work/fw/<FW_VERSION>_fac.zip` staging, GSI `system.img` >4 GiB downgraded from
`PROBLEM` to `NOTE`, `rom/tools.sh` `debugfs | head` SIGPIPE/pipefail race (rc=141),
and the `RestlessOS` label in `pack-ap.sh`. Full synthetic re-run with Drive-style
names: rc=0, `VERDICT: clean`.

## 2026-11-22 — second real Drive run: 6/8 stages good, 7/8 died on `lz4`

Owner's run got past the GSI gate, kernel staging, stock-AP extraction, super
rebuild and vbmeta generation, then:

```
########## 7/8 pack plain AP TAR
boot.img <- v1.0 kernel (bakasu), raw/uncompressed
rom/pack-ap.sh: line 43: lz4: command not found
FATAL: gsi-build.sh başarısız (rc=127)
```

Cause: `bash rom/tools.sh` is a subprocess, so its `export PATH=…tools/lz4…`
never reached the packing stage. `repack-super.sh` had always re-added those
directories itself — that is why step 5 could decompress `super.img.lz4` and step
7 could not. `lz4` is genuinely required, but only to *decompress* stock
`dtbo.img.lz4` / `vendor_boot.img.lz4` into plain members; no LZ4 ever enters the
AP, and there is still no MD5 footer anywhere.

Fixes: PATH bootstrap in `pack-ap.sh` / `make-vbmeta.sh` / once in `gsi-build.sh`
(hard-checked), `work/build.env` so a single stage can be re-run without retyping
env, and actionable messages. Verified two ways: full synthetic chain rc=0 with
`VERDICT: clean`, and a resume run under `env -i PATH=/usr/bin:/bin` with no build
variables — `pack-ap.sh` found its own `lz4`, took the name from `work/build.env`,
and produced a clean TAR.

## 2026-11-22 — FIRST REAL AP TAR BUILT (owner, Colab, real inputs)

Resume after the 7/8 `lz4` failure worked: only `pack-ap.sh` + the audit were
re-run, nothing was rebuilt. Observations, as printed by the run:

```
out/AP_SM-A155F_NothingOS-Asteroids-A16_bakasu_A155FXXS7CYG4.tar
  10,904,903,680 B   sha256 a141847c93d9b144f78012983f4bcd195241bb4451fd4fa6b36471f9f2329b34
  plain tar: True    md5 footer: False
  6 transport parts: .00-.04 at 1.9 GB, .05 at 900 MB
```

Members (stock order preserved), with sizes and containers:

| member | raw | expanded | container |
|---|---|---|---|
| `boot.img` | 67,108,864 | 67,108,864 | android-boot (bakasu) |
| `vendor_boot.img` | 67,108,864 | 67,108,864 | stock, LZ4 removed |
| `dtbo.img` | 285,040 | 285,040 | stock, LZ4 removed |
| `recovery.img` | 83,886,080 | 83,886,080 | android-boot |
| `super.img` | 8,116,998,968 | 11,744,051,200 | **liblp**, rebuilt |
| `userdata.img` | 1,418,011,288 | 17,179,869,184 | android-sparse, stock |
| `misc.bin` | 520,704 | | stock |
| `spmfw/dpm/scp/sspm/mcupm/gz/tee/tzar/pi_img-verified.img` | 15,200 … 3,215,696 | | stock |
| `vbmeta.img`, `vbmeta_system.img` | 256 each | | rebuilt, `--flags 3` |
| `meta-data/fota.zip` | 1,141,288,059 | | stock |
| `meta-data/` | directory entry | | stock |

Rebuilt super layout (from `tools/super_inspect.py`, inside the audit):

```
system 4,876,709,888 | product 1,837,219,840 | vendor 1,184,497,664
system_ext 525,639,680 | vendor_dlkm 36,745,216 | odm 1,650,688
```

Audit verdict: `warnings`, and the only finding was
`member 'meta-data' is not a regular file` — Samsung's own AP carries that
explicit directory entry, so it is a `NOTE` now, not a warning
(`tools/odin_audit.py` + regression test). Packaging is otherwise clean: plain
TAR, no MD5 footer, no LZ4 member, `vendor`/`odm`/`product` intact.

Two facts worth keeping:

* the rebuilt super expands to **11,744,051,200 B**, i.e. exactly the stock super
  partition size that `lp_plan.py` read from `lpdumps` — the 4.54 GiB `system` fits
  by construction, so the earlier capacity worry was unfounded;
* the AP still contains the stock **`userdata.img`**, so flashing it will wipe user
  data exactly like a stock AP does. That is a decision for the owner, not a bug.

**Still unmeasured: boot.** Nothing was flashed.

## 2026-11-22 — first flash attempt by the owner (reported, unverified by us)

The owner flashed the built AP on the device. What the owner reports:

* the device **booted past the Samsung logo** — boot chain and `boot`/`vendor_boot`
  are intact, and Odin accepted the package (so the shape, member list and
  `vbmeta --flags 3` were accepted by the bootloader);
* **the Nothing UI did not come up within ~15 minutes** — so this is an
  *incomplete* boot, not a working ROM: either the GSI's framework never started
  (A16 `system` on an A15 vendor stack is the prime suspect), or it is stuck
  before `zygote`/SurfaceFlinger.

Consequences for the line:

* packaging is now **hardware-accepted** (a real result, not a claim);
* **booting is still not proven**; nothing here may be described as working;
* the owner is moving to the PixelOS side quest, and the version ladder in
  `docs/50-GSI-LINE.md` still says: vendor-matched **A15** build first, A16 after
  that. Any "Nothing A16 on A15 vendor" retry needs logcat (`adb logcat`), not
  another blind flash.
