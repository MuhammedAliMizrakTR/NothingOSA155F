# SIDE QUEST — PixelOSA155F

**Bu dosya, ayrı bir chat/branch'e yapıştırılacak prompttur.** Ana hat (PixelOSA155F)
bundan etkilenmez: burada yalnızca *aynı cihaz, aynı kernel, aynı paketleme hattı*,
ama `system` bölümüne **PixelOS GSI** konur.

Okuma kolaylığı için: bölüm 1–3 Türkçe özet, bölüm 4'ten sonrası ajana verilecek
İngilizce spesifikasyon.

---

## 1. Tek cümlelik iş

SM-A155F (MT6789, GKI 5.10.226) için, PixelOSA155F'de zaten çalışan
`rom/` hattıyla **PixelOS GSI → düz Odin AP TAR** üret; cihaza flash yok.

## 2. Neden bu hat

PixelOSA155F'de GSI kapısı (MD5), kernel staging, stok AP üye sırası, `super.img`
yeniden kurulumu, `vbmeta --flags 3`, düz TAR paketleme ve `odin_audit.py` kapısı
uçtan uca çalıştı; 7/8'deki `lz4` PATH hatası da düzeltildi. PixelOS için tek
değişen şey donör `system.img` ve isimlendirme. Yani sıfırdan ROM portu değil,
**donör değişimi**.

## 3. Owner'ın cevaplaması gerekenler (açık kalan)

1. PixelOS GSI'yı hangi klasöre koyacaksın? (öneri: Drive `PixelOSA155F`)
2. GitHub repo adı `PixelOSA155F` mi, boş mu açtın, yoksa bu paketteki dosyaları
   mı itelim?
3. Android sürüm hedefi: PixelOS A15 (vendor ile uyumlu, boot ihtimali yüksek)
   yoksa A16/A17 (daha yeni, boot riski yüksek)?

---

## 4. Spec (English — paste this part to the agent)

### Mission

Build a **lawful, evidence-gated** Odin AP TAR for the **Samsung Galaxy A15 4G,
`SM-A155F` only** (MediaTek MT6789 / Helio G99, GKI 5.10.226), taking the `system`
partition from an **unofficial PixelOS GSI** and keeping the stock `vendor` /
`odm` / `product` bytes. No firmware port, no proprietary redistribution, **no
flashing by the agent**.

This is the same pipeline already proven in the repository `PixelOSA155F`
(same author, same device). Only the donor GSI and the naming change.

### Hard device facts (do not re-derive, verify if cheap)

| Item | Value |
|---|---|
| Device | `SM-A155F`, MT6789, GKI Linux 5.10.226 |
| Stock firmware | `SAMFW.COM_SM-A155F_XSG_A155FXXS7CYG4_fac.zip`, 6,904,157,493 B |
| `super` (raw, stock) | 9,352,091,512 B |
| Stock AP members (order is the Odin contract) | `boot.img.lz4` 21,020,551 · `vendor_boot.img.lz4` 8,580,297 · `dtbo.img.lz4` 98,045 · `super.img.lz4` 5,865,008,566 · `vbmeta.img.lz4` 3,515 · `vbmeta_system.img.lz4` 2,819 |
| Kernel candidates (each 67,112,960 B, `boot.img` only) | `bakasu_35262_susfs_v2.4.0_A155FXXS7CYG4_A15_GKI.tar` (default), `kernelsunext_33548_…`, `stock_optimized_5.10.226_…` |

### Inputs and pinning (rule)

* PixelOS GSI zip: arm64 **AB**, unofficial "PixelOS"-flavoured GSI. Candidate
  source: SourceForge project *Mystic GSI Updates*, `/Generic/` (it lists
  `Pixel-raven-17`-style builds; `raven` = Pixel 6 Pro signature, Android 17 era)
  — check the folder listing and the project RSS for **exact byte size + MD5**:
  `https://sourceforge.net/projects/mystic-gsi-updates/rss?path=/Generic`.
* Every input must be pinned in `inputs/inputs.lock.json` by **Drive id (or URL) +
  exact size + MD5**, and re-verified before use (gate **G0**). A mismatched hash
  aborts the build.
* Firmware zip and kernel tars are the same files as the NothingOS line (the owner
  already has them; do not re-download from third-party mirrors).

### Pipeline (reuse, do not rewrite)

`code/` in this package is the NothingOS build pipeline, already carrying all the
fixes found on real runs. Copy it into the new repo and keep it working:

```
rom/tools.sh              lpmake/lpunpack/lpdumps (static), lz4, e2fsprogs, avbtool — no apt
rom/gsi-inputs.sh         GSI MD5 gate + unsparse system.img + kernel boot.img + firmware
rom/extract-ap.sh         stock AP member list/order, super + small members
rom/repack-super.sh       lpdump -> lpunpack -> lp_plan -> lpmake (GSI as system)
rom/make-vbmeta.sh        avbtool make_vbmeta_image --flags 3
rom/pack-ap.sh            plain TAR, stock member order, no MD5 footer, no LZ4 members
rom/gsi-build.sh          orchestrates 1/8 … 8/8 and ends with the audit gate
tools/*.py                gsi_inspect / super_inspect / odin_audit / odin_pack / tar_inspect / verify_inputs
tests/                    27 synthetic unit tests — keep them green
colab_build.sh            one-file Colab runner (payload-less)
tools/make_single_file.sh turns colab_build.sh into the self-extracting single file
```

`rom/` is ported verbatim from the owner's GrapheneOS/RestlessOS port
(`MuhammedAliMizrakTR/GrapheneOS-SM-A155-` @ `46b586a`, Apache-2.0), plus the local
patches listed in `code/rom/README.md`. Keep that provenance note.

### Naming and artifacts

```
AP_SM-A155F_PixelOS-<TAG>_<kernel>_<FW_VERSION>.tar     plain TAR, flashed as-is
```

`<TAG>` comes from the GSI zip name (e.g. `Pixel-raven-17-…` → `raven-A17`),
`<kernel>` ∈ `bakasu|kernelsunext|stock`, `FW_VERSION=A155FXXS7CYG4`,
`ROM_NAME=PixelOS`. Outputs: `out/AP_*.tar`, `out/dist/*.SHA256SUMS.txt`, plus
1900 MB transport parts that are **not** flash files.

### Gates (all must pass, in order)

* **G0** — GSI MD5 + size match the lock; firmware/kernel present and hashed.
* **G1** — stock AP member list and order recorded before repacking.
* **G2** — rebuilt super is **real liblp** and still contains `vendor`, `odm`,
  `product`; `system` is the GSI; total fits the 9,352,091,512 B super or the
  build aborts loudly.
* **G3** — AP TAR: plain TAR (no `MD5<hex>` footer), no LZ4 members, member order
  equal to the stock order, `vbmeta*` rebuilt with `--flags 3`.
* **G4** — `tools/odin_audit.py` verdict `clean`. `warnings` needs a written
  justification; `critical` means do not ship.

### Red lines

* Never flash, never advise flashing before the open
  `SW REV CHECK FAIL [super] Fused 7 > Binary 8` contradiction (owner reported
  binary 7 / `A155FXXS7CYG4`) is reconciled, and never without the stock package
  on hand.
* No proprietary Nothing/Samsung/Pixel code, blobs, apps or keys are redistributed;
  no attestation bypass; no unverified claims (NoMount/HybridMount, YukiZygisk,
  ZygiskNext, VectorLSP, camera/flash behaviour).
* Artifacts are additive: never overwrite, rename or delete an existing one, no
  releases without the owner asking.
* AP is a **plain** `.tar`: no MD5 footer, no LZ4 members. (`lz4` the *tool* is
  still required — see traps.)

### Known traps, already fixed in `code/` — do not "simplify" them away

1. **Drive copy suffix.** Copying a file into a Drive folder renames it locally
   (`…_GKI.tar adlı dosyanın kopyası`, `…zip (1)`, `… - copy`). `gsi-inputs.sh`
   resolves exact name first, then `<name>*`; firmware is staged as the canonical
   `work/fw/<FW_VERSION>_fac.zip`.
2. **`bash rom/tools.sh` is a subprocess.** Its `export PATH` does not reach later
   stages. `pack-ap.sh` / `make-vbmeta.sh` bootstrap PATH themselves and
   `gsi-build.sh` exports it once and hard-checks `lpmake/lpdumps/lz4/debugfs`.
   Symptom if lost: `lz4: command not found` at 7/8 after 6 successful stages.
3. **`set -o pipefail` vs early-exit readers.** `prog | head -1` and
   `echo … | grep -q` turn *passing* checks into failures (SIGPIPE). Use `sed -n
   '1p'`, `case`, or write to a file. Symptoms seen: `rc=141` at 1/8,
   `lpdumps FAIL` on a healthy toolchain.
4. **`extract-ap.sh` deletes the firmware zip** and **`repack-super.sh` wipes
   `work/parts` + `work/ap/super.raw`** — re-run the whole `gsi-build.sh`, or
   re-stage, before repeating a partial stage.
5. **`system.img` may be Android-sparse**; `lpmake --image` needs raw. Always run
   `rom/simg2img.py` first (the script checks the magic).
6. **liblp metadata** lives at offset 12288 with a backup geometry block at 8192
   (not 8192/4096); v1.x headers keep `tables_size`@44 and
   `tables_checksum`@48 with descriptor offsets relative to `header_size`.
   `tools/super_inspect.py` already handles both layouts.
7. **A GSI `system.img` over 4 GiB is normal** (the NothingOS one was
   4,876,709,888 B) — that is a `NOTE`, not a defect; what matters is whether the
   rebuilt super can reserve it.

### Resuming instead of restarting

Stages are independent and `work/` is the state. After a failure, fix the cause and
re-run only the broken stage; `work/build.env` carries `KERNEL_VARIANT` /
`FW_VERSION` / `ROM_NAME` so the artifact keeps its name:

```bash
cd /content/PixelOSA155F
bash rom/pack-ap.sh                                   # e.g. step 7/8 only
python3 tools/odin_audit.py out/AP_*.tar | tee out/AP_audit.txt
```

### Deliverables and acceptance criteria

1. Repository `PixelOSA155F` with `rom/`, `tools/`, `tests/`, `docs/`,
   `inputs/inputs.lock.json` (PixelOS GSI pinned by size+MD5), `colab_build.sh`,
   `tools/make_single_file.sh`, English README/CHANGELOG.
2. A documented one-file Colab runner (`bash tools/make_single_file.sh`), verified
   with synthetic inputs before touching the real 2.3 GB GSI / 6.9 GB firmware.
3. `python3 -m unittest discover -s tests` green (27 tests).
4. A real AP TAR + `odin_audit.py` verdict + member list, size, sha256 — or an
   honest report of exactly which gate blocked it and why.
5. No claims beyond evidence: boot success on SM-A155F is **unmeasured** until the
   owner reports it.

### First response the agent should give

State the plan in ≤10 lines, then immediately: (a) list what it needs from the
owner (PixelOS GSI file + where it lives, Drive folder name, GitHub repo name),
(b) pin the GSI, (c) run the synthetic end-to-end to prove the pipeline in this
environment, (d) only then start the real build.

---

## 5. Paket içeriği

```
PROMPT.md                 bu dosya
CHECKLIST.md              rebrand için tam dosya/satır listesi
README.md                 paketin ne olduğu, 3 satır
code/rom/*                hat (script'ler + simfix/ + rom/README.md)
code/tools/*.py           denetim araçları + make_single_file.sh
code/tests/*.py           27 sentetik test
code/colab_build.sh       tek dosya runner başlığı
code/docs/50,65,70-*.md   GSI hattı, super şekilleri, build reçetesi (referans)
code/inputs.lock.example.json  pin şablonu
```
