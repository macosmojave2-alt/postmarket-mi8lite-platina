# Próximos pasos — Port downstream Mi 8 Lite (qcacld) — PROMPT DE CONTINUACIÓN

> Pega este archivo (o léelo) al retomar. Es el punto exacto donde quedó el trabajo.

## CONTEXTO DE UNA LÍNEA
Estamos portando pmOS sobre el kernel downstream **LineageOS 4.19** (`linux-xiaomi-platina`)
con **qcacld** para que el WiFi funcione (el mainline ath10k quedó bloqueado por el firmware).
Estamos en el **Paso 2: hacer que el kernel COMPILE**. El primer build falló por `compiler-gcc.h`
y YA se aplicó el fix (`REPLACE_GCCH=0`). Falta re-buildear y seguir iterando errores.

## LO PRIMERO AL RETOMAR (revisar esto)
1. Confirmar que el fix sigue en el APKBUILD:
   `grep REPLACE_GCCH /home/arch/.local/var/pmbootstrap/cache_git/pmaports/device/testing/linux-xiaomi-platina/APKBUILD`
   → debe aparecer `REPLACE_GCCH=0 . downstreamkernel_prepare` en `prepare()`.
2. Leer `ESTADO-PROYECTO.md` (estado global) y `SESION-2026-06-11.md` (qué se hizo).

## TAREA 1 — Re-buildear el kernel (iterar hasta que compile)
El usuario corre los comandos con sudo (sudo laptop = `C3s4rd4vid`):
```
cd /home/arch/postmarket
pmbootstrap build linux-xiaomi-platina
```
- Si vuelve a fallar, pedir al usuario las últimas ~30-40 líneas del error (o `pmbootstrap log`).
- Iterar fixes en el APKBUILD (`prepare()`) o como patches. Errores esperados en kernel 4.19
  downstream con GCC moderno / qcacld:
  - Más choques de headers → ya cubierto por REPLACE_GCCH=0; si aparecen otros, evaluar patch.
  - qcacld `-Werror` → el helper ya quita -Werror de Makefiles; si qcacld trae su propio
    `-Werror` en `Kbuild`/`*.mk`, añadir sed/patch (ver referencia
    `linux-samsung-a5y17lte/disable_wlan_werror.qcapatch`).
  - Símbolos/funciones GCC: pueden requerir patches tipo
    `gcc8-fix-put-user.patch`, `gcc10-extern_YYLOC...` (ver el mismo dir de referencia).
  - Elegir versión de GCC si no arranca/compila (el de a5y17lte usa gcc6; 4.19 normalmente
    compila con GCC reciente, pero tenerlo presente).
- Meta: `linux-xiaomi-platina-4.19.325-r0.apk` generado (RC=0).

## TAREA 2 — Ajustar config para pmOS (tras compilar)
- `pmbootstrap kconfigcheck linux-xiaomi-platina` → habilitar lo que pmOS exija
  (DEVTMPFS, cgroups, etc.) editando el `.config` (regenerar `config-xiaomi-platina.aarch64`
  con `pmbootstrap kconfig edit linux-xiaomi-platina`).
- Re-checksum: `pmbootstrap checksum linux-xiaomi-platina`.

## TAREA 3 — device pkg downstream (NO romper el mainline)
- Crear un device pkg que dependa de `linux-xiaomi-platina` (paquete separado, p.ej.
  `device-xiaomi-platina-downstream`, o subpaquete kernel seleccionable). NO modificar el
  `device-xiaomi-platina` mainline funcional.
- deviceinfo: `flash_method=fastboot`, `deviceinfo_append_dtb="true"` (config trae
  `BUILD_ARM64_APPENDED_DTB_IMAGE=y`), `deviceinfo_dtb` → el DTB es `sdm660-mtp-platina`.
  Tomar offsets de fastboot del boot.img Lineage (`strings` del boot.img) o del deviceinfo actual.
- Mantener `iw`, `wpa_supplicant` en depends.

## TAREA 4 — Primer arranque (sin WiFi)
```
pmbootstrap install --split   # genera rootfs con kernel+módulos coherentes (NO solo flash_kernel)
# teléfono en fastboot:
pmbootstrap flasher flash_kernel
pmbootstrap flasher --partition userdata flash_rootfs
```
- Verificar boot hasta SSH (USB-RNDIS 172.16.42.1) o consola/pantalla. Capturar dmesg.
- Si no arranca: revisar DTB anexado, cmdline (comparar con boot.img Lineage), pstore
  (`CONFIG_PSTORE_RAM=y` ya activo → /sys/fs/pstore tras un panic).

## TAREA 5 — Habilitar WiFi con qcacld
- `modprobe wlan` (qcacld se compila como `wlan.ko`). Confirmar que está en /lib/modules.
- Firmware qcacld: rutas distintas a ath10k. Usa `/lib/firmware/wlan/` + `WCNSS_qcom_cfg.ini`
  + `wlanmdsp.mbn` (ya extraído). COPIAR config/rutas de **lavender**:
  `ubuntu-touch-lavender/android_device_xiaomi_lavender` (halium-9.0) — referencia clave.
- WCN3990 usa `icnss`/`cnss2` (ya en config). Verificar en dmesg.
- `doas iw dev wlan0 scan` → debe LISTAR redes SIN `EX:wlan_process`/`PC=b00c75b8`.
- Conectar con wpa_supplicant.

## CRITERIO DE ÉXITO FINAL
`wlan0` con qcacld + `iw scan` lista redes + conexión wpa_supplicant, SIN el crash b00c75b8.
Capturar dmesg como evidencia. Documentar y subir al repo
`macosmojave2-alt/postmarket-mi8lite-platina` (sin firmware propietario).

## NOTAS / RECORDATORIOS
- El árbol del kernel 4.4 oficial Xiaomi es SOLO referencia (DTS/config del fabricante), no se compila.
- El plan completo está en `/home/arch/.claude/plans/serialized-meandering-acorn.md`.
- Memoria del proyecto: `mi8lite-wifi-estado` (estado), `s9-wifi-investigacion`, `portafolio-dispositivos-pmos`.
