# PixelOSA155F — side-quest paketi

SM-A155F için **PixelOS GSI → düz Odin AP TAR** hattı. PixelOSA155F'de çalışan
`rom/` hattının, tüm gerçek-koşu düzeltmeleri dahil, PixelOS'a yeniden
markalanmış kopyası. Ana hat etkilenmez.

## Başla

1. `PROMPT.md` → yeni chat/branch'e yapıştırılacak metin (Türkçe özet + İngilizce spec).
2. `CHECKLIST.md` → sırayla yapılacaklar (pinning, sentetik test, gerçek build, yayın).
3. `code/` → repo köküne kopyalanacak hat:
   ```
   rom/        derleme aşamaları (tools, gsi-inputs, extract-ap, repack-super,
               make-vbmeta, pack-ap, gsi-build) + simfix/ + rom/README.md
   tools/      gsi_inspect, super_inspect, odin_audit, odin_pack, tar_inspect,
               verify_inputs, make_single_file.sh, mk_synthetic_inputs.sh
   tests/      27 sentetik birim testi
   inputs/     inputs.lock.example.json (pin şablonu)
   colab_build.sh   tek dosya Colab runner'ının başlığı
   ```

## Doğrulama (bu paketle yapıldı)

- `python3 -m unittest discover -s tests` → 27 test OK.
- `bash tools/mk_synthetic_inputs.sh /tmp/pxinputs` + `INPUTS_DIR=/tmp/pxinputs
  INPUTS_LOCK=/tmp/pxinputs/inputs.lock.json bash rom/gsi-build.sh` → rc=0,
  `AP_SM-A155F_PixelOS-Demo-A17_bakasu_A155FXXS7CYG4.tar`, `VERDICT: clean`.

Gerçek PixelOS GSI ile boot **ölçülmedi**; paketleme doğruluğu boot garantisi değildir.
