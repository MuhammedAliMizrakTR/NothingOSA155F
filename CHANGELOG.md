# Changelog

## [Unreleased] — 2026-11-22

### Added
- `docs/00-FEASIBILITY.md`: verdict (true Nothing OS 5 port not feasible), feasibility
  matrix, firmware/rollback and licensing blockers, missing-evidence list.
- `docs/10-INPUTS.md`: observed Drive inventory (`/GrapheneOS`, `/HyperOSA155F`) and
  the pinned-input policy.
- `docs/20-FIRST-BUILD.md`: Build A (kernel/boot bundle) plan with gates G0–G4 and an
  explicit no-flash boundary.
- `docs/30-BUILD-LOG.md`: append-only observation log.
- `inputs/inputs.lock.json`: Drive ids, exact sizes and Drive-reported MD5s for every
  input the project may read.
- `tools/verify_inputs.py`, `tools/tar_inspect.py`, `tools/odin_pack.py`.
- `tests/test_tools.py`: 11 synthetic self-tests (plain-TAR enforcement, LZ4 rejection,
  MD5-footer detection, overwrite guard, reproducibility, chunk join, input verification).

- `docs/40-ROM-LINE.md`: donor/target triage plan, R0–R4 gates, and why the earlier
  phase-2 "empty partition table" result was a missing-tooling artefact, not evidence.
- `tools/super_inspect.py`: liblp geometry/header/table reader with checksum
  verification and sparse-prefix decoding (no `lpdump`/`lpunpack` required).
- `tests/test_super_inspect.py`: 4 synthetic liblp/sparse fixtures, 15 tool tests total.

### Added (second revision, same day)
- `docs/50-GSI-LINE.md`: GSI route as the primary path — why it removes the
  cross-vendor HAL problem, candidate builds with MD5s, version ladder (A15
  vendor-matched fallback before A16), known risks including the public
  `SM-A235F` bootloop report, packaging pipeline and gates G0–G4.
- `tools/gsi_inspect.py` + `tests/test_gsi_inspect.py`: inspect a GSI zip without
  commiting to a flash (members, sparse/ext4/EROFS classification, expanded size,
  `--extract` that refuses to overwrite); 19 tool tests total.
- `inputs/inputs.lock.json`: four MysticGSI Nothing OS builds pinned (SourceForge
  URL + RSS MD5 + rounded size), plus the source URLs.
- `docs/00-FEASIBILITY.md`: superseding section — the failed-verdict applies to the
  *firmware port* route; the GSI route is feasible to attempt but unproven here.

### Added (sixth revision, same day)
- `tools/make_single_file.sh`: reproducible builder for the one-file Colab
  deliverable — refuses a header that already contains a bare payload marker, zips
  exactly the 42 needed sources with a fixed mtime, appends marker + 76-column
  base64, writes `NothingOSA155F-colab.sh`. Toolchains are not embedded; the file
  provisions them from `rom/tools.sh` on first run.
- `docs/70-BUILD-RECIPE.md`: "The single file" section — how it is produced, the
  env overrides, and the verified end-to-end synthetic run (rc=0, 52 s, single TAR,
  `VERDICT: clean`).
- `rom/README.md`: re-run warning — `extract-ap.sh` deletes the firmware zip and
  `repack-super.sh` wipes `work/parts` + `work/ap/super.raw`, so partial re-runs
  need a re-stage.

### Added (tenth revision, same day — first real AP TAR)
- `docs/30-BUILD-LOG.md`: the real build, with the full member/size/container table,
  the rebuilt super layout, the sha256 and the one audit finding.
- `docs/70-BUILD-RECIPE.md`: "The real build" section (the capacity worry was
  unfounded — the rebuilt super expands to exactly the stock 11,744,051,200 B) and
  the pre-flash observations (`userdata.img` is a member → flashing wipes data;
  stock `recovery.img`; boot unmeasured).
- `README.md`: the state table now says an AP TAR exists, and that device
  validation is still none.

### Added (thirteenth revision, same day — side quest packaging)
- `tools/mk_synthetic_inputs.sh`: one command builds a full synthetic input set
  (real `lpmake` super, sparse `system.img` inside a GSI zip, 128 MB `boot.img`
  kernel TAR, plain AP TAR inside a fake firmware zip, plus `inputs.lock.json`)
  with Drive-copy-style file names; `GSI_NAME=` switches the fixture between the
  NothingOS and PixelOS lines.
- `sidequest/build_sidequest_package.sh` + `sidequest/PixelOSA155F/`: reproducible
  builder for the **PixelOSA155F** side-quest kit (`PROMPT.md`, `MASTERPROMPT.md`,
  `CHECKLIST.md`, `README.md`, current `rom/`+`tools/`+`tests/` rebranded to
  PixelOS) and `PixelOSA155F-sidequest.zip`. The code is copied from this repo on
  every run, so the side quest cannot drift from the fixes made here.
- Verified: extracted zip → 28 tests OK → `mk_synthetic_inputs.sh` → full
  `rom/gsi-build.sh` → `AP_SM-A155F_PixelOS-Demo-A17_bakasu_A155FXXF7CYG4.tar`,
  `VERDICT: clean`, rc=0.

### Recorded (twelfth revision, same day — device evidence)
- `docs/30-BUILD-LOG.md` + `README.md`: the owner flashed the AP. Boot chain works
  (past the Samsung logo, Odin accepted the package) but the **system UI never
  appeared within ~15 minutes**, so packaging is hardware-accepted while booting
  remains unproven. Nothing is called "working".
- `docs/50-GSI-LINE.md` ladder stands: vendor-matched **A15** build first, A16 only
  with logcat evidence.

### Added (eleventh revision, same day)
- `rom/pack-ap.sh` writes `out/dist/<APBASE>.JOIN.txt`: which file is the flashable
  AP, why the `.tar.NN` parts exist, the exact `cat` command to restore the TAR and
  the `sha256sum -c` check. Verified by joining a synthetic build and `cmp`-ing it
  against the original TAR (identical).

### Fixed (tenth revision)
- `tools/odin_audit.py`: an explicit **directory** member in a TAR (Samsung's AP
  carries `meta-data/` next to `meta-data/fota.zip`) was a `warning`, so a perfectly
  good package reported `VERDICT: warnings`. Directories are now a `[NOTE]`;
  symlinks/device nodes stay warnings. New regression test
  (`test_directory_entry_is_only_a_note`), 28 tests total.

### Fixed (ninth revision, same day — pipefail flakes)
- `rom/tools.sh`: the toolchain check used `echo "$out" | grep -q …`. `grep -q`
  exits at the first match, `echo` takes SIGPIPE, and `set -o pipefail` turns a
  *passing* check into `lpdumps FAIL` / `lpmake FAIL` at random (observed on a
  freshly cloned, working toolchain). Now a `case` match, no pipe at all.
- `rom/gsi-inputs.sh`: same class — `tar -tf … | grep -qx 'boot.img'` became
  `tar -tf … > work/kernel/members.txt` + `grep -qx` on the file.

### Fixed (eighth revision, same day — the 7/8 failure)
- **`lz4: command not found` at `pack-ap.sh`.** `bash rom/tools.sh` is a subshell,
  so its `export PATH` never reached the later stages; `repack-super.sh` had always
  bootstrapped its own PATH, `pack-ap.sh` and `make-vbmeta.sh` had not. All three
  now prepend `tools/lptools/linux_glibc_x86_64`, `tools/lz4` and the e2fsprogs
  dirs, `gsi-build.sh` exports that PATH once for every child and hard-checks
  `lpmake`/`lpdumps`/`lz4`/`debugfs`, and `pack-ap.sh` fails with an actionable
  message if `lz4` is really absent.
- `work/build.env`: `gsi-inputs.sh` records `KERNEL_VARIANT`, `FW_VERSION`,
  `ROM_NAME`; `pack-ap.sh` reads them back (explicit env wins), so a lone
  `bash rom/pack-ap.sh` after a failed 7/8 produces the same AP name instead of
  dying on an unbound variable.
- `rom/README.md`: "Resuming after a failure instead of starting over" + the
  patch table now lists every local change.

### Added (seventh revision, same day — from the first real Colab run)
- `rom/gsi-inputs.sh`: Google Drive copy-suffix resolution. `resolve_input()` tries
  the exact base name, then `<name>*` (largest match), so
  `bakasu_…_GKI.tar adlı dosyanın kopyası` and
  `SAMFW.COM_…_fac.zip adlı dosyanın kopyası adlı dosyanın kopyası` both work; the
  firmware is staged as the canonical `work/fw/<FW_VERSION>_fac.zip`; the GSI MD5
  pin now matches the longest pinned prefix, and a missing kernel prints the files
  that *are* present instead of just the path it wanted.
- `tools/gsi_inspect.py`: a `notes` channel + `NOTE:` lines. A `system.img` over
  4 GiB is no longer reported as a problem (the real GSI is 4,876,709,888 B); the
  note says the rebuilt super must reserve that much for `system`.
- `docs/70-BUILD-RECIPE.md`: "Real-input failure modes already fixed" and the
  remaining unknown (4.54 GiB `system` vs 9.35 GB super; A15 build as the fallback
  lever).
- `docs/30-BUILD-LOG.md`: the observed first real run, including the passed G0 gate.

### Fixed (seventh revision)
- `rom/tools.sh`: `debugfs -V 2>&1 | head -1` → `sed -n '1p'`. `head` closed the
  pipe, `debugfs` got SIGPIPE, and `set -o pipefail` aborted the build at step 1/8
  with rc=141 (intermittent — earlier runs passed by luck).
- `rom/pack-ap.sh`: the super line echoed a hard-coded `RestlessOS` for a Nothing
  build.
- `rom/README.md`: the local-patch list is now a table of three (APBASE, the log
  label, the `debugfs` pipe) plus the Drive-suffix behaviour.

### Fixed (sixth revision)
- `colab_build.sh` (and therefore the single file) ended without `exit 0`; the
  shell then tried to execute the base64 payload as commands, so an otherwise
  successful build exited rc=127.
- `colab_build.sh` audit summary used `tail -3 … | tr '\n' ' '`, flattening the
  report into one line; it now prints the audit file name, verdict and member table.
- `README.md`: documented the single-file Colab route next to the script route.

### Fixed
- `tools/odin_pack.py` now creates the output directory instead of failing on a
  fresh `/content/out/...` path (found by an end-to-end GSI dry run); regression
  test added — 20 tool tests total.

### Added (third revision, same day)
- `docs/60-NOTHING-OS-MAP.md`: verified Nothing OS ↔ Android ↔ codename map
  (Asteroids = Phone (3a), Metroid = Phone (3)), the finding that "Nothing OS 14"
  does not exist (14/15/16 in MysticGSI names are Android versions), filename
  decoder, and why a stronger donor device does not by itself make the port heavier.
- `docs/50-GSI-LINE.md`: corrected fallback ranking — the *matched* Asteroids-15 is
  fallback #1 and the flagship Metroid-15 is #2; kernel section ("not touched"),
  owner-reported RestlessOS 17 GSI evidence, new gate G5 (match the owner's
  already-working packaging method).
- `inputs/inputs.lock.json`: GSI entries now carry `device_codename`/`device_model`
  and are ordered by intended attempt sequence.

### Added (fourth revision, same day)
- `tools/odin_audit.py` + `tests/test_odin_audit.py`: audits a built Odin AP TAR and
  returns clean/warnings/critical — catches the dangerous "super.img that is really
  a renamed system image" (no liblp, no vendor/odm) and vendor-less supers;
  26 tool tests total.
- `docs/65-SUPER-PACKAGING.md`: the three AP shapes (`system.img` / hybrid
  `super.img` / whole-super replacement), measured stock super sizes, audit table
  and the recommended path.
- `tools/super_inspect.py`: `inspect_stream()` so AP members can be parsed in place
  without extracting gigabytes to disk.
- `inputs/inputs.lock.json`: Drive folder `NothingOSA155F` (id
  `184SfXD3X5-9jBgB5YnAsvgV2Sjg4Si6W`) registered for GSI/artifact staging.

### Added (fifth revision, same day)
- `rom/`: the owner's proven build pipeline ported from
  `MuhammedAliMizrakTR/GrapheneOS-SM-A155-` @ `46b586a5` (Apache-2.0), verbatim except
  one configurable `ROM_NAME` in the AP filename — `tools.sh`, `simg2img.py`,
  `lp_plan.py`, `extract-ap.sh`, `repack-super.sh`, `make-vbmeta.sh`, `pack-ap.sh`,
  `modify-gsi.sh`, `build-rilfix-module.sh`, `render-notes.sh`, `simfix/`.
- `rom/gsi-inputs.sh` (MD5-gated GSI staging + unsparse + boot.img + firmware) and
  `rom/gsi-build.sh` (one-shot orchestrator ending in `tools/odin_audit.py`).
- `docs/70-BUILD-RECIPE.md`: the exact recipe, pinned inputs, and the synthetic
  end-to-end dry run that produced a `clean` AP TAR.
- Input pinned from Drive: Nothing-Asteroids-16 zip, 2,333,520,539 B,
  MD5 `152a92ab…c33c` — Drive value matches SourceForge, G0 gate met.

### Fixed
- `tools/super_inspect.py`: real `lpmake` output revealed two layout errors that
  synthetic fixtures missed — the metadata header sits after a **backup geometry**
  block (offset 12288), and current liblp stores `tables_size`/`tables_checksum` at
  header offsets 44/48 with descriptors at 80 (offsets relative to the table
  payload). Both layouts are now detected by validation, and the table payload
  checksum is verified. Regression tests added (27 tool tests total).

### Notes
- No build has been executed and no device action has been taken. Nothing in this
  repository is claimed to boot.
- ROM `1.1` remains withdrawn / **DO NOT FLASH**; no asset was touched.
- Nothing OS 5 was not found in the reachable Drive scope; the port stays blocked
  until an actual package with device/build identity is supplied.
