# Estado del proyecto — Mi 8 Lite (xiaomi-platina, SDM660) en postmarketOS

**Última actualización:** 2026-06-11

## Objetivo
WiFi funcional (Qualcomm WCN3990) en postmarketOS para el Xiaomi Mi 8 Lite.

## Dos vías exploradas

### Vía A — MAINLINE (ath10k, kernel 6.17.4) — ⛔ BLOQUEADA por firmware
Estado: **bringup 100% resuelto, pero el WiFi NO funciona por límite del firmware propietario.**
- ✅ Modem MSS estable (rmtfs → diag-router → tqftpserv).
- ✅ wlan0 sube, QMI bringup completo (chip_id 0x140, board_id 0xff, BDF OK, fw ready).
- ✅ Crash de `set psmode` resuelto (patch 0012, verificado: 0 crashes en bringup).
- ⛔ **El scan crashea el firmware en `PC=b00c75b8`** (misma rutina interna del firmware
  WLAN.HL.1.0.1.c6 que toca tanto psmode como scan). Sin fix posible desde driver mainline.
- Paquete: `linux-postmarketos-qcom-sdm660` pkgrel=21, patches 0001-0012 (0010 archivado).
- Detalle completo: `INVESTIGACION-WIFI-SDM660.md`.
- **Decisión:** se conserva como referencia/fallback, NO se sigue desarrollando para WiFi.

### Vía B — DOWNSTREAM (kernel LineageOS 4.19 + qcacld) — 🔄 EN CURSO
Estado: **Paso 1 hecho (paquete creado), Paso 2 en curso (haciendo que compile).**
qcacld es el driver propietario que SÍ maneja este firmware (confirmado por UBports/lavender,
mismo SoC). qcacld no entra en mainline → se porta pmOS sobre kernel Android 4.19.

| Paso | Estado |
|------|--------|
| 1. Crear paquete `linux-xiaomi-platina` (APKBUILD + config 4.19) | ✅ HECHO |
| 2. Hacer que el kernel COMPILE | ✅ HECHO (apk r1, wlan.ko 12MB incluido) |
| 3. device pkg downstream (separado del mainline) | 🔄 SIGUIENTE |
| 4. Primer arranque hasta SSH (sin WiFi) | ⬜ pendiente |
| 5. WiFi con qcacld (modprobe wlan, firmware, iw scan) | ⬜ pendiente |

### Paso 2 completado (2026-06-11) — kernel + qcacld compilan
APK: `linux-xiaomi-platina-4.19.325-r1.apk` (16.8 MB). kernel.release `4.19.325-cip132-st16`.
- `vmlinuz` con DTB de platina ANEXADO (Image.gz-dtb, magic d00dfeed verificado).
- **`wlan.ko` (qcacld) compilado**: ELF ARM aarch64, 12.3 MB, en
  `/lib/modules/4.19.325-cip132-st16/kernel/drivers/staging/qcacld-3.0/wlan.ko`.
- icnss/cnss builtin (=y). 14 módulos en total.
Fixes aplicados en el APKBUILD/config (ver device/testing/linux-xiaomi-platina/):
1. `REPLACE_GCCH=0` en prepare() (compiler-gcc.h choca en 4.19).
2. `CONFIG_IKHEADERS` off (kheaders_data.tar.xz fallaba).
3. patch 0001: `-I$(src)` para clk-debug (trace.h out-of-tree).
4. cámara MSM off (`MSMB_CAMERA`/`MSM_CAMERA`, header faltante).
5. IPA off (`CONFIG_IPA/IPA3/RMNET_IPA`, fortify __bad_copy_to).
6. `CONFIG_FAULT_INJECTION` off (WRITE_ONCE macro).
7. patch 0002: stubs DTS (pm660_coincell, sensor_information15).
8. `CONFIG_ANDROID_VENDOR_HOOKS=y` (tracepoints android_vh_*).
9. `CONFIG_MSM_AVTIMER` off + patch 0003 (guard msm_isp_set_avtimer_fptr sin cámara).
10. `build()`+`package()`: `make modules` + `modules_install` (instalar wlan.ko).

## Recursos en disco (rutas absolutas)
- **Kernel 4.19 (base de trabajo):**
  `/home/arch/postmarket-xiaomi-lmi/mi8lite-platina/lineageos-sdm660-419/`
  (LineageOS lineage-21, commit 0eaf76b319b586a7974036cbcdd1c1e8f35364bd, qcacld in-tree)
- **Kernel 4.4 (referencia oficial Xiaomi):**
  `/home/arch/postmarket-xiaomi-lmi/mi8lite-platina/xiaomi-downstream-kernel/`
  (MiCode nitrogen-q-oss; tiene platina_user_defconfig y DTS original del fabricante)
- **Paquete pmaports:**
  `/home/arch/.local/var/pmbootstrap/cache_git/pmaports/device/testing/linux-xiaomi-platina/`
- **Backup particiones Android (referencia):** `/home/arch/mi8lite-backup/` (boot/vendor/system/modem/dtbo)
- **boot.img Lineage 21 (4.19.318):** `/home/arch/Descargas/lineage-21.0-20240812-UNOFFICIAL-platina/boot.img`
- **Firmware extraído del teléfono:** `/home/arch/postmarket/Mi8Lite/mi8lite-firmware-dump/`
  (wlanmdsp.mbn, bdwlan.*) y `.../mi8lite-modem-fw/` (mba.mbn, modem.*)
- **APKBUILD downstream de referencia (qcacld):**
  `/home/arch/Descargas/pmaports-nikroks-alioth/device/testing/linux-samsung-a5y17lte/`

## Repos GitHub
- **Mi 8 Lite (este):** `macosmojave2-alt/postmarket-mi8lite-platina` (privado) — solo platina.
- Poco F2 Pro + S9+ (separados): `macosmojave2-alt/postmarket-xiaomi-lmi`.

## Datos operativos
- Teléfono: SSH `user@172.16.42.1` pass `147147`; doas `147147` SOLO por tty (pty-python + sshpass -tt).
  Laptop USB: 172.16.42.2, interfaz enp0s20f0u4. eMMC=mmcblk1.
- sudo laptop = `C3s4rd4vid` (el usuario corre los comandos sudo: build/install/flash).
- Firmware propietario NUNCA va a GitHub (ya blindado en .gitignore).
- GOTCHA: `flash_kernel` NO actualiza los .ko del rootfs → usar `pmbootstrap install --split`
  cuando hay módulos (qcacld = wlan.ko es módulo).
