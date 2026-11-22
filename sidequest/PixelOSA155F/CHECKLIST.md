# PixelOSA155F — yeni branch'te yapılacaklar (kontrol listesi)

Bu paket, PixelOSA155F hattının **çalışan** kopyasıdır; `ROM_NAME` varsayılanı
`PixelOS`, GSI otomatik araması `*-MysticGSI.zip*`. Aşağıdaki sırayı izle.

## 0. Yeni ortam (5 dk)

```bash
# repo'yu aç (bu paketteki code/ içeriği repo köküne)
mkdir -p ~/PixelOSA155F && cd ~/PixelOSA155F
# code/rom, code/tools, code/tests, code/inputs, code/colab_build.sh  ->  repo kökü
bash rom/tools.sh                        # lpmake/lpunpack/lpdumps, lz4, e2fsprogs, avbtool (apt yok)
python3 -m unittest discover -s tests    # 27 test OK olmalı
```

Colab'da Drive bağlamayı unutma:
```python
from google.colab import drive; drive.mount('/content/drive')
```

## 1. Donör GSI'yı seç ve pinle (G0)

1. PixelOS GSI'yı Drive klasörüne koy: **`PixelOSA155F`** (klasör yoksa oluştur).
2. Aday kaynak: SourceForge *Mystic GSI Updates* → `/Generic/` (ör. `Pixel-raven-17-…`).
   Kesin boyut + MD5 için RSS: `https://sourceforge.net/projects/mystic-gsi-updates/rss?path=/Generic`
3. İndirdiğin dosyanın boyut/MD5'ini RSS ile **çapraz doğrula**, sonra pinle:

```bash
INPUTS_DIR=/content/drive/MyDrive/PixelOSA155F
F=$(ls "$INPUTS_DIR"/*-MysticGSI.zip* | head -1)
echo "name : $(basename "$F")"; echo "size : $(stat -c%s "$F")"; echo "md5  : $(md5sum "$F" | cut -d' ' -f1)"
```

Bu üç satırı `inputs/inputs.lock.json` içindeki `donor-gsi-primary` girdisine yaz
(`inputs.lock.example.json` şablon). Kernel ve stok firmware girdilerini de
boyut + MD5 ile doldur.

> Kural: pin yoksa ya da hash tutmazsa build **durur**. Uyarıyla devam etmez.

## 2. Sentetik uçtan uca (gerçek GSI'ya dokunmadan)

Hattı kendi ortamında ispatla — 60–90 saniye sürer, hiçbir gerçek dosyayı kullanmaz:

```bash
bash tools/mk_synthetic_inputs.sh /tmp/pixelinputs
INPUTS_DIR=/tmp/pixelinputs INPUTS_LOCK=/tmp/pixelinputs/inputs.lock.json bash rom/gsi-build.sh
```

Beklenen: `out/AP_SM-A155F_PixelOS-Demo-A17_bakasu_A155FXXS7CYG4.tar`,
`VERDICT: clean`, rc=0. Bu adım geçmiyorsa gerçek GSI'ya hiç geçme.

## 3. Gerçek build

```bash
INPUTS_DIR=/content/drive/MyDrive/PixelOSA155F \
KERNEL_VARIANT=bakasu ROM_NAME=PixelOS \
bash rom/gsi-build.sh 2>&1 | tee build.log
```

Adımlar: 1/8 araç → 2/8 GSI+kernel+firmware → 3/8 stok AP üyeleri → 4/8 (opsiyonel
ekstralar, varsayılan kapalı) → 5/8 super yeniden kurulum → 6/8 vbmeta → 7/8 düz
TAR paketleme → 8/8 audit.

Bir adım düşerse **baştan başlama**; `work/` duruyor, sadece o adımı tekrar çalıştır:

```bash
bash rom/pack-ap.sh                          # ör. 7/8 tekrar
python3 tools/odin_audit.py out/AP_*.tar | tee out/AP_audit.txt
```
(`work/build.env` `KERNEL_VARIANT`/`FW_VERSION`/`ROM_NAME` taşır; isim şaşmaz.)

## 4. Teslim ve yayın

| Ne | Nereye | Not |
|---|---|---|
| Kod + dokümanlar | GitHub repo `PixelOSA155F` | metin dosyaları commit edilir |
| Üretilen `AP_*.tar` (≈ 5,8 GB+) | **GitHub Release asset** | repo'ya commit **edilmez**; 2 GB/asset sınırı için 1900 MB'lık `.tar.00`, `.01` … parçaları + `sha256` manifest |
| Tek dosya runner | Drive klasörü | `bash tools/make_single_file.sh` ile üret, her repo değişikliğinden sonra yeniden üret |

Parçalar `.NN` uzantılıdır, tek başına flash edilmez; birleştirme komutu manifestte.

## 5. İsimlendirme kontrolü

```bash
grep -rn "Nothing" rom/ tools/ tests/ colab_build.sh   # 0 sonuç beklenir (yorumlar hariç)
grep -rn "ROM_NAME:-" rom/                              # PixelOS olmalı
```

AP adı: `AP_SM-A155F_PixelOS-<TAG>_<kernel>_<FW_VERSION>.tar`

## 6. Değişmez kurallar

- **Flash yok**, ajan flash etmez; `SW REV CHECK FAIL [super] Fused 7 > Binary 8`
  çelişkisi (owner: binary 7 / `A155FXXS7CYG4`) çözülmeden flash tavsiyesi de yok.
- Tescilli kod/blob/uygulama/anahtar dağıtımı yok; attestation atlatma yok.
- AP **düz** `.tar`: MD5 eki yok, LZ4 üye yok. (`lz4` aracı yine gerekli — stok
  `dtbo`/`vendor_boot` üyelerini açmak için.)
- Var olan artifact silinmez, üzerine yazılmaz; sürümler eklemeli.
- Kanıt yoksa "boot eder" denmez; cihazda doğrulanana kadar "unmeasured".

## 7. Bu hatta bilinen tuzaklar (koddaki düzeltmeleri geri alma)

1. Drive kopya eki (`… adlı dosyanın kopyası`) → `resolve_input()` çözer.
2. `bash rom/tools.sh` alt kabuktur → PATH her aşamada kendiliğinden eklenir
   (eksikse 7/8'de `lz4: command not found`).
3. `set -o pipefail` + erken çıkan okuyucu (`| head -1`, `| grep -q`) → SIGPIPE;
   `sed -n '1p'` / `case` kullan (belirti: `rc=141`, `lpdumps FAIL`).
4. `extract-ap.sh` firmware zip'ini, `repack-super.sh` `work/parts`'ı siler.
5. GSI `system.img` sparse olabilir → `rom/simg2img.py` şart.
6. liblp: header 12288'de, yedek geometry 8192'de; v1.x tablo ofsetleri
   `header_size`'a göre. `tools/super_inspect.py` iki düzeni de bilir.
7. 4 GiB üstü `system.img` normaldir → `NOTE`, hata değil.
