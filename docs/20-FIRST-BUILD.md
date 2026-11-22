# 20 — First build: kernel/boot bundle (Build A)

This is the shortest honest path to a first *build artifact* with the material
that actually exists in `/GrapheneOS`. It compiles nothing, redistributes
nothing, and is fully reversible. It produces a clean, hashed AP TAR from the
owner's preferred `bakasu` boot artifact.

> **Nothing here authorises flashing.** Gates G0–G4 must pass first, and the
> `SW REV` / fused-revision contradiction must be reconciled on the device before
> any Odin action is even discussed. A build artifact is not a device result.

## Why this and not a ROM

| Candidate | Effort | Evidence today | Verdict |
|---|---|---|---|
| Nothing OS 5 port | unbounded | no Nothing package in Drive; different SoC vendor; proprietary framework | **not buildable** |
| `emerald` (Motorola, MT6789) cross-port | weeks–months | partition tables not even parsed yet (`lpdump`/`lpunpack` absent) | deferred |
| Kernel/boot bundle from pinned TARs | hours | inputs pinned with sizes + MD5 | **start here** |

## Tooling in this repo

| Tool | Purpose |
|---|---|
| `tools/verify_inputs.py` | re-hash local copies against `inputs/inputs.lock.json`; refuses mismatches |
| `tools/tar_inspect.py` | read-only TAR report: members, container magic, LZ4 members, MD5 footer |
| `tools/odin_pack.py` | reproducible plain-TAR packer with manifest, overwrite guard, optional `.00/.01` transport chunks |
| `tests/test_tools.py` | synthetic self-tests (`python3 -m unittest discover -s tests -v`) |

Packaging rules enforced in code: plain TAR, **no** `MD5<hex>` fingerprint, **no**
LZ4 members, sorted members, fixed owner/mtime (byte-reproducible output),
unique filenames, refuse to clobber existing artifacts, SHA-256 manifest beside
every artifact.

## Stage 0 — verify inputs (no writes)

Run where the Drive files are already mounted (e.g. Colab):

```bash
python3 tools/verify_inputs.py --dir "/content/drive/MyDrive/GrapheneOS" --quick
```

`--quick` skips re-hashing the 6.9 GB zip; sizes must still match exactly. Run
without `--quick` for the three 64 MiB kernel TARs at minimum:

```bash
mkdir -p /content/inputs
cp "/content/drive/MyDrive/GrapheneOS/"*_A15_GKI.tar /content/inputs/
python3 tools/verify_inputs.py --dir /content/inputs   # MD5 re-hash, all three
```

**Gate G0:** all pinned inputs `md5-ok`. Anything else stops the run.

## Stage 1 — inspect the chosen TAR (read-only)

```bash
python3 tools/tar_inspect.py \
  "/content/drive/MyDrive/GrapheneOS/bakasu_35262_susfs_v2.4.0_A155FXXS7CYG4_A15_GKI.tar"
```

Expected observations to record *before* repacking:

- member list (usually a single `boot.img`, possibly `vendor_boot.img`, `dtbo.img`)
- per-member `container`: should be `android-boot` (`ANDROID!`) or `mtk-header`
- `md5_footer`: the owner's TARs may be `.tar.md5`-style; ours must not be
- whether any member is `lz4-frame` (report only – do not "fix" silently)

Record the printed SHA-256 in `docs/30-BUILD-LOG.md`.

**Gate G1:** TAR is readable and members are identified. If a member is LZ4-
compressed, stop: decide explicitly (decompress once, keep the original) rather
than letting the packer guess.

## Stage 2 — extract to scratch, then repack

```bash
mkdir -p /content/work/bakasu /content/out
tar -xf "/content/drive/MyDrive/GrapheneOS/bakasu_35262_susfs_v2.4.0_A155FXXS7CYG4_A15_GKI.tar" \
    -C /content/work/bakasu
ls -l /content/work/bakasu

python3 tools/odin_pack.py \
  --out /content/out/AP_bakasu_susfs_v2.4.0_A155FXXS7CYG4_A15_GKI.tar \
  --manifest /content/out/AP_bakasu_susfs_v2.4.0_A155FXXS7CYG4_A15_GKI.manifest.json \
  /content/work/bakasu
```

The packer prints size / SHA-256 / MD5 / member list and writes a manifest that
records members, hashes, `plain_tar: true`, `md5_footer: false` and a fixed
mtime. Re-running the same command with the same inputs yields the same SHA-256.

Verify the artifact independently:

```bash
python3 tools/odin_pack.py --out /content/out/AP_bakasu_....tar \
  --manifest /content/out/AP_bakasu_....manifest.json --verify
tar -tvf /content/out/AP_bakasu_....tar
```

**Gate G2:** `--verify` returns OK, `tar -tvf` lists only plain `*.img` members,
and the SHA-256 in the manifest matches what will be published/kept.

## Stage 3 — documented rollback package (no flashing)

Before any artifact may leave "scratch" status, the rollback path must exist as
verified bytes:

1. Pin the stock `A155FXXS7CYG4` AP/BL/CP/CSC (already pinned by MD5) in a
   location that is independent of this repo.
2. Record the *device's* current build number and fused revision (download-mode
   screen) in `docs/30-BUILD-LOG.md`.
3. Reconcile the historical Odin line `SW REV CHECK FAIL [super] Fused 7 >
   Binary 8` against that reading. Archive-format fixes do not bypass rollback
   protection.

**Gate G3:** rollback bytes hashed *and* fused revision reconciled in writing.

## Stage 4 — device validation (owner, later)

Only after G0–G3: the owner decides whether to flash, on their own device, with
Odin, with the stock package on hand. After a boot attempt the log must state
what is *actually observed* (boots / boots to recovery / bootloop / no display),
with timestamps, kernel version string and Selinux mode. No extrapolation from
one successful boot to "working ROM".

**Gate G4:** an observation record exists. Until then the artifact stays labelled
`built, unflashed, unvalidated`.

## Out of scope for the first build

- Nothing OS assets of any kind (no lawful source, nothing to port from).
- Compiled kernel: needs source trees that are not in Drive.
- Magisk/YukiZygisk/NoMount/HybridMount class modules, ZygiskNext, VectorLSP —
  owner-reported bootloops; never bundled or recommended as compatible.
- Any release tag or "flashable" claim.
