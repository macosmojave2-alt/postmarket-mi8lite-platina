# Mi 8 Lite (xiaomi-platina) — WiFi en postmarketOS mainline

> 📌 **RUMBO DEL PROYECTO:** ver [DECISION-DE-RUMBO.md](DECISION-DE-RUMBO.md) (2026-06-13).
> Desarrollo sobre **kernel MAINLINE**. Vía downstream (qcacld) **abandonada**.
> Orden de objetivos: **1º pantalla/UI, 2º WiFi**.

Paquetes para habilitar el WiFi (Qualcomm WCN3990) y el modem (MSS) en el
Xiaomi Mi 8 Lite (SDM660) con postmarketOS, kernel mainline
`linux-postmarketos-qcom-sdm660` (6.17.4).

## Estado actual (2026-06-10)

### Mainline (`linux-postmarketos-qcom-sdm660`, 6.17.4) — bringup resuelto, WiFi bloqueado por firmware
- ✅ **`wlan0` aparece**, bringup QMI 100% OK en boot limpio (chip_id 0x140, board_id
  0xff, BDF OK, fw ready, config OK).
- ✅ Modem MSS estable (rmtfs → diag-router → tqftpserv en orden) + patches 0008/0009.
- ✅ LED oops eliminado (`CONFIG_MAC80211_LEDS=n`).
- ✅ **Crash `set psmode` (PC=b00c75b8) RESUELTO** con patch 0012 (omitir WMI set_psmode
  en WCN3990). Verificado: 0 crashes en bringup.
- ⛔ **BLOCKER FINAL (límite del firmware):** el `wmi tlv start scan` crashea el firmware
  en el MISMO `PC=b00c75b8` (rutina interna de power-management del firmware
  WLAN.HL.1.0.1.c6, que corre en el Q6 del modem). No hay fix desde el driver mainline.
  Detalle completo en [INVESTIGACION-WIFI-SDM660.md](INVESTIGACION-WIFI-SDM660.md).

### Siguiente vía: kernel DOWNSTREAM + qcacld
El WiFi del SDM660 funciona con el driver propietario qcacld (confirmado: UBports/lavender,
mismo SoC). qcacld NO entra en mainline 6.17 (depende de API interna de kernels 4.x), así que
se portará pmOS sobre el kernel downstream **LineageOS 4.19** (`android_kernel_xiaomi_sdm660`,
rama lineage-21, con `platina.config` y qcacld in-tree). Plan en
[UBPORTS-PORT-PLAN.md](UBPORTS-PORT-PLAN.md). El port Halium 4.4 de lavender se usa como
referencia de la config de qcacld.

## Componentes

### linux-postmarketos-qcom-sdm660 + 0001-platina-wifi.patch
Patch del devicetree (`sdm660-xiaomi-platina.dts`):
- `&wifi`: status=okay + 4 regulators (vdd-0.8-cx-mx, vdd-1.8-xo, vdd-1.3-rfa, vdd-3.3-ch0).
- `&remoteproc_mss`: status=okay + `firmware-name = "postmarketos/mba.mbn", "postmarketos/modem.mdt"`.

Ambos nodos existen en `sdm630.dtsi` pero vienen `disabled`.

### firmware-xiaomi-platina
- `firmware-5.bin` — genérico, generado con ath10k-fwencoder (no propietario).
- `board-2.bin` — generado de los board files (`bdwlan.*`) del dispositivo vía `gen-board-2.py`.
- `wlanmdsp.mbn` — firmware del subsistema WiFi.
- `mba.mbn` + `modem.mdt` + `modem.b*` — firmware del modem MSS, en `/lib/firmware/postmarketos/`.

#### GOTCHA del board-2.bin (importante)
ath10k construye el nombre del board file con `qmi-board-id=%x` (**hexadecimal**).
El chip del platina reporta `qmi-board-id=ff` (OTP sin programar), así que el
board-2.bin necesita un entry `bus=snoc,qmi-board-id=ff`. Además, en `bdwlan.bXX`
el board-id es **XX** (sin la "b" inicial): `bdwlan.b33` → `qmi-board-id=33`,
`bdwlan.102` → `qmi-board-id=102`. (Verificado contra el board-2.bin de lavender,
mismo WCN3990+SDM660, que usa `33`/`102`/`ff`.)

### device-xiaomi-platina
Dependencias `soc-qcom-sdm660` + `soc-qcom-sdm660-rproc` (rmtfs/tqftpserv/diag-router).
Sin rmtfs (que con `-s` enciende el MSS) + diag-router, el WiFi WCN3990 no funciona.

## Firmware propietario (NO incluido en git)
Los board files y firmware del modem se extraen del **propio dispositivo**:
- WiFi (`bdwlan.*`, `wlanmdsp.mbn`): de `/vendor/firmware_mnt/image/` (con root, vía adb).
- Modem (`mba.mbn`, `modem.*`, `adsp.*`, `cdsp.*`): de la partición `modem`
  (`/dev/disk/by-partlabel/modem`, montada vfat). NOTA: hacer dd de esta
  partición corrompe la FAT; mejor copiar los archivos montándola viva.

Se empaquetan como `firmware-xiaomi-platina-bdwlan.tar.gz` y
`firmware-xiaomi-platina-modem.tar.gz` (gitignored), luego `pmbootstrap checksum`.

## Instalación (GOTCHA de storage)
Instalar con el layout combinado (GPT anidado dentro de userdata de 52GB)
**corrompe el GPT/ext4 en cada boot**. Usar:

    pmbootstrap install --split --password XXXX
    fastboot flash userdata ~/.local/var/pmbootstrap/chroot_native/home/pmos/rootfs/xiaomi-platina-root.img
    pmbootstrap flasher flash_kernel
    pmbootstrap flasher flash_vbmeta

El `flasher fastboot` de pmbootstrap no soporta `--split`, por eso el rootfs
(ext4 plano) se flashea manual a `userdata`.

## Notas
- pantalla NO funciona en mainline (kernel solo para desarrollo); el kernel
  downstream (LineageOS) tiene pantalla.
- Caveat sdm660-mainline #75: salir de rango del AP rompe el WiFi hasta reiniciar.
