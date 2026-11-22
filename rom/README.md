# rom/ — build pipeline (ported from the owner's GrapheneOS/RestlessOS port)

These scripts implement the **same packaging recipe** the owner already proved on
this device for GrapheneOS/RestlessOS: one plain Odin AP TAR containing a raw
`boot.img`, a rebuilt sparse `super.img` (GSI `system` + byte-identical stock
`vendor`/`product`/`odm`), and verification-disabled `vbmeta*.img`.

## Provenance

| | |
|---|---|
| Source repository | `https://github.com/MuhammedAliMizrakTR/GrapheneOS-SM-A155-` |
| Source commit | `46b586a506796abe61a3c33a072681390ec62f0d` |
| License | Apache-2.0 (source repo `LICENSE`) |
| Files copied verbatim | `tools.sh`, `simg2img.py`, `lp_plan.py`, `extract-ap.sh`, `repack-super.sh`, `make-vbmeta.sh`, `pack-ap.sh`, `build-rilfix-module.sh`, `modify-gsi.sh`, `render-notes.sh`, `simfix/` |
| Files added here | `gsi-inputs.sh`, `gsi-build.sh`, this README |

Kept byte-identical except the single documented patch below, so behaviour stays
the one that is already known to work on SM-A155F.

## Local modifications (three, all minimal)

| File | Change | Why |
|---|---|---|
| `pack-ap.sh` | `APBASE="AP_SM-A155F_${ROM_NAME:-RestlessOS}-..."` | the Nothing build must not be named `RestlessOS` |
| `pack-ap.sh` | super line echoes `${ROM_NAME:-RestlessOS}` instead of hard-coded `RestlessOS` | same reason, log only |
| `tools.sh` | `debugfs -V 2>&1 \| sed -n '1p'` instead of `\| head -1` | `head` closes the pipe, `debugfs` takes SIGPIPE and `set -o pipefail` aborts the whole build (observed: rc=141 at step 1/8) |
| `pack-ap.sh`, `make-vbmeta.sh`, `gsi-build.sh` | PATH bootstrap for `tools/lptools`, `tools/lz4`, `tools/e2fsprogs/*` (the same loop `repack-super.sh` always had) | `bash rom/tools.sh` runs in a subshell, so its `export PATH` never reached step 7/8: `lz4: command not found` after everything else had succeeded (observed, rc=127) |
| `tools.sh`, `gsi-inputs.sh` | `echo \| grep -q` and `tar \| grep -q` replaced by `case` / on-disk checks | `grep -q` exits early, the writer takes SIGPIPE, `pipefail` reports a *passing* check as `lpdumps FAIL` (observed at random) |
| `gsi-inputs.sh`, `pack-ap.sh` | `work/build.env` records `KERNEL_VARIANT`/`FW_VERSION`/`ROM_NAME`; `pack-ap.sh` reads it back | a lone `bash rom/pack-ap.sh` after a failure must reproduce the same AP name without the operator re-typing the env |

`gsi-inputs.sh` (added here, not copied) also tolerates the names Google Drive
produces when a file is *copied* into a folder:

```
bakasu_35262_susfs_v2.4.0_A155FXXS7CYG4_A15_GKI.tar adlı dosyanın kopyası
SAMFW.COM_SM-A155F_XSG_A155FXXS7CYG4_fac.zip adlı dosyanın kopyası adlı dosyanın kopyası
```

It resolves each expected base name by exact match first, then `<name>*` (largest
match wins), stages the firmware under the canonical `work/fw/<FW_VERSION>_fac.zip`,
and lets the MD5 pin match on the longest pinned prefix. Renaming the Drive files
is therefore optional, not required.

## Stage order (identical to the GrapheneOS port)

| # | Script | Purpose |
|---|---|---|
| 1 | `tools.sh` | provisions lpmake/lpunpack/lpdumps (static), lz4, e2fsprogs, avbtool — no apt |
| 2 | `gsi-inputs.sh` *(new)* | stages the Nothing GSI (MD5-gated), unsparses `system.img`, stages kernel `boot.img` + stock firmware |
| 3 | `extract-ap.sh` | pulls `AP_*.tar.md5` out of the firmware zip, records member list **and order**, extracts small members + `super.img.lz4` |
| 4 | `build-rilfix-module.sh` + `modify-gsi.sh` | optional (default skipped): embed `/system/etc/a155f-extras/` (RILFix module + presets) |
| 5 | `repack-super.sh` + `lp_plan.py` | decompress/unsparse stock super, `lpdump` layout, `lpunpack`, then `lpmake` a new sparse super with the GSI as `system` |
| 6 | `make-vbmeta.sh` | `avbtool make_vbmeta_image --flags 3` for every `vbmeta*` member |
| 7 | `pack-ap.sh` | one plain `.tar`, members in stock order, no MD5 trailer, no LZ4; SHA-256 manifest; 1900 MB transport parts |

## Entry points

```bash
# full pipeline, Nothing GSI from a Drive mount
INPUTS_DIR="/content/drive/MyDrive/NothingOSA155F" KERNEL_VARIANT=bakasu \
  bash rom/gsi-build.sh

# the packaged one-file Colab runner (repo root): unpack/tests/build/audit
bash colab_build.sh                 # from the repo
bash NothingOSA155F-colab.sh        # from the single file (embeds this repo)

# stage inputs only (no super rebuild)
INPUTS_DIR=/content/drive/MyDrive/NothingOSA155F bash rom/gsi-inputs.sh
```

Environment: `INPUTS_DIR` (required), `KERNEL_VARIANT` (`bakasu` default),
`FW_VERSION` (`A155FXXS7CYG4`), `GSI_ZIP` (override auto-detect),
`ROM_NAME` (default `NothingOS`), `SKIP_GSI_EXTRAS` (`1` default).

## Re-running a stage (important)

Two stages are **destructive by design**, so a second run needs a re-stage:

- `extract-ap.sh` deletes the firmware zip after extracting `AP_*.tar.md5` from it.
  Put the stock `SAMFW.COM_SM-A155F_XSG_…_fac.zip` back before re-running.
- `repack-super.sh` removes `work/parts/` and `work/ap/super.raw` when it is done,
  so `lpunpack` input is gone. Re-run `gsi-inputs.sh` + `extract-ap.sh` first, or
  start over with a clean `work/`.

Running the whole `gsi-build.sh` from the top handles both; only partial re-runs
are affected.

## Resuming after a failure instead of starting over

Every stage is runnable on its own and `work/` is the state. If a stage dies, fix
and re-run **that** stage; the earlier work is not thrown away:

```bash
cd /content/NothingOSA155F
# 7/8 failed -> re-run only packing, then the audit
KERNEL_VARIANT=bakasu FW_VERSION=A155FXXS7CYG4 ROM_NAME=NothingOS bash rom/pack-ap.sh
python3 tools/odin_audit.py out/AP_*.tar | tee out/AP_audit.txt
```

`pack-ap.sh` finds `lz4` itself now (PATH bootstrap), so no manual `export PATH`
is needed; the three env vars only matter for a `work/` staged by an older
`gsi-inputs.sh` (new ones record them in `work/build.env`).

## Outputs

```
out/AP_SM-A155F_NothingOS-<TAG>_<kernel>_<fw>.tar        plain TAR (flashed as-is)
out/dist/...SHA256SUMS.txt                               whole-TAR + per-part hashes
out/dist/....tar.00 / .01 ...                            transport parts only (join to restore)
```

`out/dist/<APBASE>.JOIN.txt` explains how to restore the TAR from the `.tar.NN`
transport parts; `tools/odin_audit.py` runs at the end and must report `clean` (0) or at worst
`warnings` (1). A `critical` verdict means the super lost `vendor`/`odm` or a
member is LZ4 — do not flash that artifact.

## What is *not* claimed

Copying a working recipe does not prove it works for a different GSI. The
Nothing GSI is a different `system`; `vendor`/`odm`/`boot` handling is identical
to the proven build, but boot success on this device remains unmeasured.
