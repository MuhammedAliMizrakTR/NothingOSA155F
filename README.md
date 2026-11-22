# NothingOSA155F

Working repository for a **lawful, evidence-gated** attempt to build something
Nothing-like for the **Samsung Galaxy A15 4G — `SM-A155F` only**
(MediaTek MT6789 / Helio G99, GKI 5.10.226).

This is an **unofficial community effort**. It is not a Nothing Technology
product, not GrapheneOS, and not a security-equivalent substitute for either.

## Current state (2026-11-22)

| Item | State |
|---|---|
| Nothing OS *firmware* package | **not available** — a Drive-wide search returned 0 hits |
| Porting Nothing OS from firmware | **not feasible** (no package, Qualcomm↔MediaTek HAL gap, proprietary framework, Samsung fused boot chain) — `docs/00-FEASIBILITY.md` |
| Nothing OS via **GSI** (unofficial, 3rd party) | **viable route** — MysticGSI builds pinned; untested on SM-A155F; see `docs/50-GSI-LINE.md` |
| Built | **AP TAR exists** (2026-11-22, owner's Colab): `AP_SM-A155F_NothingOS-Asteroids-A16_bakasu_A155FXXS7CYG4.tar`, 10,904,903,680 B, plain TAR, audit clean — see `docs/30-BUILD-LOG.md` |
| Device validation | **partial, owner-reported** (2026-11-22): AP flashed, booted past the Samsung logo, **system UI never came up** (~15 min) — packaging accepted by the bootloader, ROM not working; see `docs/30-BUILD-LOG.md` |
| Release | none. ROM `1.1` stays withdrawn and **DO NOT FLASH** |

## Layout

```
docs/00-FEASIBILITY.md   verdict, feasibility matrix, blockers, missing evidence
docs/10-INPUTS.md        Drive inventory and the pinned-input policy
docs/20-FIRST-BUILD.md   the Build A plan: inspect -> repack -> verify -> gates
docs/40-ROM-LINE.md      firmware-port line: donor/target triage (deferred)
docs/50-GSI-LINE.md      GSI line: candidates, packaging pipeline, risks, gates
docs/65-SUPER-PACKAGING.md  system.img vs super.img AP shapes, and how to audit one
docs/70-BUILD-RECIPE.md  GSI -> Odin AP pipeline ported from the GrapheneOS port (rom/)
docs/60-NOTHING-OS-MAP.md Nothing OS <-> Android <-> codename map, donor-load analysis
docs/30-BUILD-LOG.md     append-only record of what was actually observed
inputs/inputs.lock.json  Drive ids, exact sizes, MD5s for every allowed input
tools/verify_inputs.py   re-hash local copies; refuses mismatched inputs
tools/tar_inspect.py     read-only TAR report (members, magic, LZ4, MD5 footer)
tools/odin_pack.py       reproducible plain-TAR packer + SHA-256 manifest
tools/super_inspect.py   liblp super metadata reader (raw + sparse), no lpdump needed
tools/gsi_inspect.py     GSI zip inspector: members, container, expanded size, safe extract
tools/odin_audit.py      audit a built AP TAR: plain? LZ4? real liblp super? vendor present?
rom/                     the owner's proven build pipeline (tools, lpdump/lpunpack/lpmake,
                         vbmeta, AP packing) + gsi-inputs.sh / gsi-build.sh for the GSI line
tests/test_tools.py      synthetic self-tests for the packaging tools
tests/test_super_inspect.py  synthetic liblp/sparse fixtures for super_inspect
tests/test_gsi_inspect.py    synthetic GSI-zip fixtures (sparse/ext4 classification)
tests/test_odin_audit.py     synthetic AP TARs: full super, vendor-less super, renamed system
```

## Rules this repository enforces in code

- Plain TAR only for Odin AP artifacts: no `MD5<hex>` fingerprint, no LZ4 members.
- Reproducible output (sorted members, fixed owner/mtime) with a SHA-256 manifest.
- Never overwrite, delete or rename an existing artifact; build outputs get unique
  names, and releases are additive.
- Every build input is pinned by Drive id + exact size + MD5 and re-verified.
- 100 MB+ transport splitting uses `.00`, `.01`, … chunks plus a join + hash
  command — chunks are never flash files.

## Quick start

```bash
python3 -m unittest discover -s tests -v        # tool self-tests (synthetic)
python3 tools/verify_inputs.py --dir <dir-with-inputs> --quick
python3 tools/tar_inspect.py <artifact>.tar
python3 tools/super_inspect.py <super.img>       # works on sparse images too
python3 tools/gsi_inspect.py <gsi>.zip           # md5, members, expanded size
python3 tools/odin_audit.py <AP>.tar             # is this package safe to flash?
INPUTS_DIR=<drive-folder> bash rom/gsi-build.sh  # build the AP the GrapheneOS way
```

## One file (Colab)

`NothingOSA155F-colab.sh` is the whole project in a single self-extracting file
(~121 KB: header + base64 source zip). In Colab:

```python
from google.colab import drive; drive.mount('/content/drive')
!bash "/content/drive/MyDrive/NothingOSA155F/NothingOSA155F-colab.sh"
```

It unpacks itself, provisions the toolchain (clones/builds `lpmake`/`lz4`/
`e2fsprogs`/`avbtool` — no apt), runs the unit tests, MD5-gates the GSI, builds the
AP, audits it and leaves a single `out/AP_*.tar` (transport parts removed). After
any repo edit regenerate the file with `bash tools/make_single_file.sh` — never
hand-edit it. Recipe and the verified synthetic run: `docs/70-BUILD-RECIPE.md`.

## Non-goals

Bundling or redistributing Nothing/Samsung proprietary code, apps or blobs;
defeating licensing or attestation; recommending known-bootloop modules
(NoMount/HybridMount-style mounts, YukiZygisk, ZygiskNext, VectorLSP) as
compatible; and claiming any build is "working", "safe" or "verified" without
device evidence.
