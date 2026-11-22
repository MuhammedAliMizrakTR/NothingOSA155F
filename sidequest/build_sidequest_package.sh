#!/usr/bin/env bash
# ============================================================================
# Builds the PixelOSA155F side-quest package:
#   sidequest/PixelOSA155F/{PROMPT,MASTERPROMPT,CHECKLIST,README}.md + code/
#   PixelOSA155F-sidequest.zip  (repo root)
#
# The pipeline is copied from THIS repo (so it always carries the current fixes)
# and then rebranded NothingOS -> PixelOS. Never hand-edit sidequest/PixelOSA155F/
# code: re-run this script instead.
#
#   bash sidequest/build_sidequest_package.sh
# ============================================================================
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."
ROOT=$(pwd)
PKG="sidequest/PixelOSA155F"
ZIP="PixelOSA155F-sidequest.zip"

[ -d "$PKG" ] || { echo "missing $PKG"; exit 1; }

# ---- 1. refresh the code tree from the live pipeline ----------------------
rm -rf "$PKG/code"
mkdir -p "$PKG/code"/{rom,tools,tests,inputs}
cp -a rom/. "$PKG/code/rom/"
rm -rf "$PKG/code/rom/__pycache__"
cp -a tools/*.py "$PKG/code/tools/"
cp -a tools/make_single_file.sh tools/mk_synthetic_inputs.sh "$PKG/code/tools/" 2>/dev/null || true
cp -a tests/*.py "$PKG/code/tests/"
cp -a colab_build.sh "$PKG/code/"
cp -a inputs/inputs.lock.json "$PKG/code/inputs/inputs.lock.example.json"

# ---- 2. rebrand NothingOS -> PixelOS -------------------------------------
python3 - "$PKG" <<'PY'
import json, os, sys
pkg = sys.argv[1]
PROTECT = "matches `*-MysticGSI.zip*` instead of `Nothing-*.zip*`"

for dirpath, dirnames, filenames in os.walk(pkg):
    dirnames[:] = [d for d in dirnames if d != "__pycache__"]
    for f in filenames:
        if not f.endswith((".sh", ".md", ".py", ".json")):
            continue
        path = os.path.join(dirpath, f)
        s = open(path, encoding="utf-8").read()
        orig = s
        s = s.replace(PROTECT, "\x00PROTECT\x00")
        s = s.replace("NothingOSA155F", "PixelOSA155F")
        s = s.replace("${ROM_NAME:-NothingOS}", "${ROM_NAME:-PixelOS}")
        s = s.replace("Nothing-GSI line", "PixelOS-GSI line")
        s = s.replace("Nothing GSI", "PixelOS GSI")
        s = s.replace("(default `NothingOS`)", "(default `PixelOS`)")
        s = s.replace("AP_SM-A155F_NothingOS-", "AP_SM-A155F_PixelOS-")
        s = s.replace("NothingOS-<TAG>", "PixelOS-<TAG>")
        s = s.replace("NothingOS $RTAG", "PixelOS $RTAG")
        s = s.replace("the Nothing build must not be named", "the PixelOS build must not be named")
        s = s.replace("\x00PROTECT\x00", PROTECT)
        if s != orig:
            open(path, "w", encoding="utf-8").write(s)

# GSI auto-detect: every Mystic GSI build ends with "-MysticGSI.zip"
p = os.path.join(pkg, "code/rom/gsi-inputs.sh")
s = open(p, encoding="utf-8").read()
old = """  mapfile -t CANDS < <(find "$INPUTS_DIR" -maxdepth 1 -type f -name 'Nothing-*.zip*' ! -name '*src*' | sort)"""
new = """  # Every Mystic GSI Updates build ends with "-MysticGSI.zip"; that token works
  # for Pixel-*, Nothing-* and Generic builds alike.
  mapfile -t CANDS < <(find "$INPUTS_DIR" -maxdepth 1 -type f -name '*-MysticGSI.zip*' ! -name '*src*' | sort)"""
if old in s:
    s = s.replace(old, new, 1)
    s = s.replace('echo "FATAL: no Nothing-*.zip in $INPUTS_DIR"',
                  'echo "FATAL: no *-MysticGSI.zip in $INPUTS_DIR"')
    open(p, "w", encoding="utf-8").write(s)

# a small, PixelOS-shaped pin template
template = {
    "schema": "pixelosa155f.inputs/1",
    "note": ("Pin EVERY input by exact size + MD5 before the build reads it (gate G0). "
             "Fill from the real files: size = stat -c%s, md5 = md5sum. A missing or "
             "mismatched pin must abort the build, never warn."),
    "inputs": [
        {"role": "donor-gsi-primary",
         "name": "REPLACE-ME-Pixel-raven-17-...-MysticGSI.zip",
         "source": "https://sourceforge.net/projects/mystic-gsi-updates/files/Generic/",
         "drive_folder": "PixelOSA155F", "size": None, "md5": None,
         "md5_source": "sourceforge-rss + uploaded-file (cross-check both)",
         "use": "arm64 AB PixelOS-family GSI; becomes the 'system' partition"},
        {"role": "kernel-boot",
         "name": "bakasu_35262_susfs_v2.4.0_A155FXXS7CYG4_A15_GKI.tar",
         "drive_folder": "PixelOSA155F", "size": 67112960, "md5": None,
         "use": "boot.img only; same file the owner already flashed on this device"},
        {"role": "stock-firmware",
         "name": "SAMFW.COM_SM-A155F_XSG_A155FXXS7CYG4_fac.zip",
         "drive_folder": "PixelOSA155F", "size": 6904157493, "md5": "bea1131d...9b57",
         "use": "vendor/odm/product bytes + AP member order; needed for rollback"},
    ],
}
with open(os.path.join(pkg, "code/inputs/inputs.lock.example.json"), "w", encoding="utf-8") as fh:
    json.dump(template, fh, indent=2, ensure_ascii=False)
    fh.write("\n")

# README note at the top of rom/
p = os.path.join(pkg, "code/rom/README.md")
s = open(p, encoding="utf-8").read()
note = ("**PixelOSA155F package note:** identical to the NothingOSA155F pipeline "
        "(every local patch included) except that `ROM_NAME` defaults to `PixelOS` and the "
        "GSI auto-detect matches `*-MysticGSI.zip*` instead of `Nothing-*.zip*`.\n\n")
if "package note" not in s:
    s = s.replace("# rom/ — build pipeline", note + "# rom/ — build pipeline", 1)
open(p, "w", encoding="utf-8").write(s)
print("rebranded", pkg)
PY

chmod +x "$PKG/code/tools/mk_synthetic_inputs.sh"

# ---- 3. sanity: no leftovers that would confuse the next agent ------------
BAD=$(grep -rn "ROM_NAME:-NothingOS" "$PKG/code" || true)
if [ -n "$BAD" ]; then echo "ERROR: leftover NothingOS default:"; echo "$BAD"; exit 1; fi

# ---- 4. zip ---------------------------------------------------------------
rm -f "$ZIP"
python3 - "$PKG" "$ZIP" <<'PY'
import os, sys, zipfile
pkg, out = sys.argv[1], sys.argv[2]
n = 0
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
    for dirpath, dirnames, filenames in os.walk(pkg):
        dirnames[:] = sorted(d for d in dirnames if d != "__pycache__")
        for f in sorted(filenames):
            full = os.path.join(dirpath, f)
            rel = os.path.relpath(full, pkg)
            if rel.endswith((".pyc", ".pyo")):
                continue
            zf.write(full, "PixelOSA155F-sidequest/" + rel)
            n += 1
print("zip:", out, os.path.getsize(out), "bytes,", n, "files")
PY
echo "done: $ZIP"
