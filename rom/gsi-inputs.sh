#!/usr/bin/env bash
# Stages the ROM inputs for the Nothing-GSI line, from a local folder (Drive mount):
#   <Nothing-*-MysticGSI.zip>   GSI, MD5-gated against inputs/inputs.lock.json
#   <kernel>.tar                owner kernel artifact (default: bakasu), boot.img only
#   <*_fac.zip> or AP_*.tar*    stock firmware for the vendor/odm bytes + member order
#
# Produces:
#   work/gsi/gsi.img   raw (unsparse) system image, ready for lpmake --image
#   work/gsi/TAG       short build tag used in the AP filename
#   work/kernel/boot.img
#   work/fw/*.zip  or  work/ap/AP_*.tar*
set -euo pipefail
cd "$(dirname "$0")/.."

: "${INPUTS_DIR:?FATAL: set INPUTS_DIR to the folder holding the GSI zip, kernel tar and firmware zip}"
KERNEL_VARIANT="${KERNEL_VARIANT:-bakasu}"
FW_VERSION="${FW_VERSION:-A155FXXS7CYG4}"
mkdir -p work/gsi work/kernel work/fw work/ap

DF() { df -h . | tail -1; }
say() { printf '\n=== %s\n' "$*"; }

# Google Drive appends a localized suffix when a file is copied into a folder:
#   "bakasu_..._GKI.tar adlı dosyanın kopyası", "... (1)", "... - copy"
# so an exact-name lookup is not enough. resolve_input() takes the expected base
# name and returns the matching file (exact name first, then "<name>*"), picking
# the largest match when there are several, because every candidate is the same
# artifact. Prints nothing and returns 1 when nothing matches.
resolve_input() {
  local want="$1" f
  local matches=()
  if [ -f "$INPUTS_DIR/$want" ]; then printf '%s\n' "$INPUTS_DIR/$want"; return 0; fi
  for f in "$INPUTS_DIR/$want"*; do [ -f "$f" ] && matches+=("$f"); done
  [ "${#matches[@]}" -gt 0 ] || return 1
  if [ "${#matches[@]}" -gt 1 ]; then
    echo "note: ${#matches[@]} files match '$want*'; using the largest:" >&2
    printf '  %s\n' "${matches[@]}" >&2
  fi
  for f in "${matches[@]}"; do printf '%s\t%s\n' "$(stat -c%s "$f")" "$f"; done \
    | sort -rn | head -1 | cut -f2-
}

say "inputs: $INPUTS_DIR"
[ -d "$INPUTS_DIR" ] || { echo "FATAL: $INPUTS_DIR is not a directory"; exit 1; }
DF

# ---------------------------------------------------------------- GSI (MD5 gate)
GSI_ZIP="${GSI_ZIP:-}"
if [ -z "$GSI_ZIP" ]; then
  mapfile -t CANDS < <(find "$INPUTS_DIR" -maxdepth 1 -type f -name 'Nothing-*.zip*' ! -name '*src*' | sort)
  [ "${#CANDS[@]}" -gt 0 ] || { echo "FATAL: no Nothing-*.zip in $INPUTS_DIR"; exit 1; }
  GSI_ZIP="${CANDS[0]}"
  [ "${#CANDS[@]}" -gt 1 ] && echo "note: multiple GSI zips found, using $(basename "$GSI_ZIP") (set GSI_ZIP to override)"
fi
[ -f "$GSI_ZIP" ] || { echo "FATAL: GSI zip not found: $GSI_ZIP"; exit 1; }
say "GSI: $(basename "$GSI_ZIP")"
LOCK="${INPUTS_LOCK:-inputs/inputs.lock.json}"
python3 - "$GSI_ZIP" "$LOCK" <<'PY'
import hashlib, json, os, sys
path, lock_path = sys.argv[1], sys.argv[2]
name = os.path.basename(path)
with open(lock_path, encoding="utf-8") as fh:
    lock = json.load(fh)
# A Drive copy suffix ("...zip adlı dosyanın kopyası", "... (1)") must not break
# the pin: accept the longest pinned name that is a prefix of the actual file.
entry = next((e for e in lock["inputs"] if e["name"] == name), None)
if entry is None:
    cands = [e for e in lock["inputs"] if e.get("name") and name.startswith(e["name"])]
    entry = max(cands, key=lambda e: len(e["name"])) if cands else None
    if entry is not None:
        print(f"  note   : matched pinned '{entry['name']}' (file name has extra suffix)")
if entry is None:
    sys.exit(f"FATAL: '{name}' is not pinned in {lock_path}")
expected = entry.get("md5")
if not expected:
    sys.exit(f"FATAL: no pinned MD5 for '{name}'")
h = hashlib.md5()
size = 0
with open(path, "rb") as fh:
    for block in iter(lambda: fh.read(1 << 20), b""):
        h.update(block)
        size += len(block)
actual = h.hexdigest()
print(f"  size   : {size} bytes")
print(f"  md5    : {actual}")
print(f"  pinned : {expected}")
if actual != expected:
    sys.exit("FATAL: GSI MD5 mismatch - re-download; G0 gate not met")
if entry.get("size") and size != entry["size"]:
    sys.exit(f"FATAL: GSI size {size} != pinned {entry['size']}")
print("  G0 gate: GSI hash verified")
PY

say "extracting system.img"
rm -rf work/gsi/zip
if ! python3 tools/gsi_inspect.py "$GSI_ZIP" --extract work/gsi/zip --only system.img >/dev/null 2>&1; then
  echo "note: gsi_inspect refused (see below); falling back to plain unzip"
  python3 tools/gsi_inspect.py "$GSI_ZIP" || true
  unzip -o -j "$GSI_ZIP" system.img -d work/gsi/zip >/dev/null
fi
[ -f work/gsi/zip/system.img ] || { echo "FATAL: no system.img inside $GSI_ZIP"; exit 1; }

if python3 -c "import sys; sys.exit(0 if open('work/gsi/zip/system.img','rb').read(4)==b'\x3a\xff\x26\xed' else 1)"; then
  echo "system.img is Android-sparse -> rom/simg2img.py (lpmake needs raw)"
  python3 rom/simg2img.py work/gsi/zip/system.img work/gsi/gsi.img
else
  mv work/gsi/zip/system.img work/gsi/gsi.img
fi
rm -rf work/gsi/zip
GSI_SIZE=$(stat -c%s work/gsi/gsi.img)
echo "raw system image: $GSI_SIZE bytes"

# ------------------------------------------------------------------------ TAG
BASE=$(basename "$GSI_ZIP" .zip)          # Nothing-Asteroids-16-2511181551-AB-20260111-MysticGSI
CODENAME=$(printf '%s' "$BASE" | cut -d- -f2)
ANDROIDV=$(printf '%s' "$BASE" | cut -d- -f3)
TAG="${CODENAME}-A${ANDROIDV}"
printf '%s\n' "$TAG" > work/gsi/TAG
echo "TAG: $TAG"
DF

# ---------------------------------------------------------------------- kernel
case "$KERNEL_VARIANT" in
  bakasu)       KTAR="bakasu_35262_susfs_v2.4.0_${FW_VERSION}_A15_GKI.tar" ;;
  kernelsunext) KTAR="kernelsunext_33548_susfs_v2.4.0_${FW_VERSION}_A15_GKI.tar" ;;
  stock|vanilla) KTAR="stock_optimized_5.10.226_${FW_VERSION}_A15_GKI.tar" ;;
  *) echo "FATAL: unknown KERNEL_VARIANT=$KERNEL_VARIANT (bakasu|kernelsunext|stock)"; exit 1 ;;
esac
say "kernel: $KTAR"
KTARPATH=$(resolve_input "$KTAR" || true)
if [ -z "${KTARPATH:-}" ]; then
  echo "FATAL: kernel tar not found in $INPUTS_DIR"
  echo "  wanted: $KTAR   (or a copy whose name starts with it)"
  echo "  files present:"
  ls -1 "$INPUTS_DIR" | sed 's/^/    /' || true
  echo "  fix: rename the file to exactly '$KTAR', or pick KERNEL_VARIANT=bakasu|kernelsunext|stock"
  exit 1
fi
[ "$KTARPATH" = "$INPUTS_DIR/$KTAR" ] || echo "  using: $(basename "$KTARPATH")"
KSHA="${KERNEL_SHA:-}"
if [ -n "$KSHA" ]; then
  echo "$KSHA  $KTARPATH" | sha256sum -c - \
    || { echo "FATAL: kernel SHA-256 mismatch"; exit 1; }
else
  echo "note: KERNEL_SHA not set - recording the hash instead of enforcing it"
  sha256sum "$KTARPATH"
fi
tar -tf "$KTARPATH" > work/kernel/members.txt
grep -qx 'boot.img' work/kernel/members.txt \
  || { echo "FATAL: $(basename "$KTARPATH") has no boot.img member"; sed -n '1,20p' work/kernel/members.txt; exit 1; }
tar -xf "$KTARPATH" -C work/kernel boot.img
echo "boot.img: $(stat -c%s work/kernel/boot.img) bytes, sha256=$(sha256sum work/kernel/boot.img | cut -d' ' -f1)"

# -------------------------------------------------------------------- firmware
say "stock firmware"
FWZ=""
for f in "$INPUTS_DIR"/AP_*.tar "$INPUTS_DIR"/AP_*.tar.md5 "$INPUTS_DIR"/AP_*.tar*; do
  [ -f "$f" ] && { FWZ="$f"; break; }
done
if [ -n "$FWZ" ]; then
  cp "$FWZ" "work/ap/$(basename "$FWZ")" && echo "AP tar staged (LOCAL mode): $(basename "$FWZ")"
else
  # a Drive copy suffix ("...zip adlı dosyanın kopyası", "... (1)") is tolerated
  for pat in '*_fac.zip*' 'SAMFW*.zip*'; do
    for f in "$INPUTS_DIR"/$pat; do
      [ -f "$f" ] && { FWZ="$f"; break 2; }
    done
  done
  if [ -z "$FWZ" ]; then
    echo "FATAL: need AP_*.tar or *_fac.zip in $INPUTS_DIR"
    ls -1 "$INPUTS_DIR" | sed 's/^/    /' || true
    exit 1
  fi
  cp "$FWZ" "work/fw/${FW_VERSION}_fac.zip"
  echo "firmware zip staged: $(basename "$FWZ") ($(stat -c%s "$FWZ") bytes)"
  echo "  as: work/fw/${FW_VERSION}_fac.zip (canonical name, keeps spaces out of later steps)"
  echo "  md5: $(md5sum "$FWZ" | cut -d' ' -f1)"
fi
DF

# Record the exact parameters of this staged build so a later single stage
# (e.g. `bash rom/pack-ap.sh` after a failure) reproduces the same file names
# without the operator having to remember the env vars.
{
  echo "KERNEL_VARIANT=$KERNEL_VARIANT"
  echo "FW_VERSION=$FW_VERSION"
  echo "ROM_NAME=${ROM_NAME:-NothingOS}"
} > work/build.env
say "build parameters -> work/build.env"
cat work/build.env

say "inputs ready"
echo "  gsi   : work/gsi/gsi.img ($GSI_SIZE bytes, TAG=$(cat work/gsi/TAG))"
echo "  kernel: work/kernel/boot.img ($KERNEL_VARIANT)"
ls work/fw work/ap 2>/dev/null || true
echo "next: bash rom/extract-ap.sh"
