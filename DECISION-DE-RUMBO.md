# Decisión de rumbo — postmarketOS en Xiaomi Mi 8 Lite (platina)

**Fecha:** 2026-06-13
**Estado:** DECISIÓN FIRME. Este documento es la fuente de verdad del rumbo del proyecto.
Reemplaza la estrategia de `PROXIMOS-PASOS-DOWNSTREAM.md` y `WIFI-FIX-PLAN.md`.

---

## TL;DR

> **Kernel de trabajo: `linux-postmarketos-qcom-sdm660` 6.17.4** (mainline-ish, paquete
> oficial pmaports). NO el downstream LineageOS 4.19. NO qcacld.
>
> Es **el mismo kernel** que usan tanto la pantalla validada de platina como el
> **WiFi usable de lavender** (Redmi Note 7) → un solo kernel para los dos objetivos.
>
> **Orden de objetivos: 1º PANTALLA (UI usable), 2º WiFi (portando la receta de lavender).**
>
> Se ABANDONA la vía downstream/qcacld para WiFi: callejón sin salida en este SoC
> y sin DRM para la pantalla. **lavender NO se descarta: es el plano de referencia
> del WiFi mainline (ath10k + board-2.bin + firmware-5.bin), portable a platina.**

### Hechos confirmados (2026-06-13)
- Paquete kernel oficial `linux-postmarketos-qcom-sdm660` hoy = **6.17.4** (la wiki de
  platina dice 4.4.296, está **desactualizada**). El repo ya tiene 6.17.4.
- `device-xiaomi-lavender` (pmaports oficial) **depende de `linux-postmarketos-qcom-sdm660`**
  → mismo kernel que platina. Mismo SoC (SDM660), mismo chip WiFi (WCN3990).
- WiFi de lavender = **ath10k mainline**: `ath10k/WCN3990/hw1.0/firmware-5.bin` +
  `board-2.bin` (paquete `firmware-xiaomi-lavender`). NO qcacld.
- Wiki platina: Screen=**Works**, Touch=**Works**, WiFi=**Broken** (pero la wiki no
  probó el board-2.bin/orden correctos que sí funcionan en lavender).
- Recursos en disco: wiki+firmware de lavender guardados; `firmware-xiaomi-lavender`
  y `device-xiaomi-lavender` en `~/.local/var/pmbootstrap/cache_git/pmaports/...`.

---

## Por qué se abandona el kernel downstream (4.19 LineageOS)

La premisa original para elegir downstream fue: *"qcacld maneja el firmware WLAN
mejor que ath10k mainline, y el kernel del fabricante trae soporte de hardware
(pantalla)"*. Tras ~6 días de trabajo, esa premisa resultó **falsa en lo que importa**:

### WiFi en downstream — BLOQUEADO sin salida (diagnóstico concluyente 2026-06-13)
- Toda la cadena de arranque del modem y servreg se construyó y funciona:
  modem MSS ONLINE estable, `qrtr-ns`, rmtfs/tqftpserv, daemon `servreg-locator`
  propio publicando el servicio QMI 64, e icnss localiza el `wlan_pd`
  (`LOCATOR_UP`, state `0x180`).
- **El bloqueo real:** el firmware WLAN nunca arranca dentro del `wlan_pd`, así que
  el servidor QMI **WLFW (4116) nunca aparece** e icnss queda esperando para
  siempre (`FW is not ready yet`).
- **Causa raíz:** el modelo de *user PD dinámico* arrancado por servreg desde el AP
  es de **SDM845+**. En este SDM660 con este firmware de modem, nadie arranca el
  user PD `wlan_pd` (el modem ni siquiera pide `wlanmdsp.mbn`), y el AP no tiene
  mecanismo para forzarlo. El servreg notification "conectado" estaba en el nodo
  local (host), no en el modem.
- **Conclusión:** sin salida razonable en software. Es un límite de plataforma.

### Pantalla en downstream — panel enciende pero la UI no pinta
- El panel DSI **sí inicializa** (`FrameBuffer[0] 1080x2280 registered`,
  "Continuous splash enabled") → se ve el logo de Mi (splash del bootloader).
- Pero el kernel 4.19 expone solo **framebuffer legacy (`/dev/fb0`), NO DRM/KMS**
  (`/dev/dri/card0` no existe). Las UIs de postmarketOS (Phosh/Plasma) necesitan
  DRM/KMS → el compositor no tiene dónde dibujar → pantalla congelada en el splash.

**Resultado: el downstream pierde en los DOS objetivos.** Rama muerta.

---

## Por qué MAINLINE es el camino correcto

| Criterio | Downstream 4.19 | **Mainline (elegido)** |
|---|---|---|
| WiFi | ⛔ imposible (PD no arranca) | ✅ usable (ver lavender abajo) |
| Pantalla / UI | fbdev sin DRM → UI no pinta | ✅ DRM/KMS nativo, ruta soportada por pmOS |
| Modem | PIL + daemons servreg a mano (frágil) | remoteproc + rmtfs/pd-mapper estándar pmOS |
| Mantenimiento | solo nosotros, rama muerta | mainlining de platina activo |
| WiFi previo logrado | — | en mainline ya tuvimos wlan0 + fw cargado |

### La evidencia decisiva: lavender (Redmi Note 7)
Mismo chip WiFi **WCN3990 + SoC SDM660 + kernel mainline**. Estado documentado:
> *Funciona bien si NO te desconectas del WiFi. Al desconectar →
> `EX:wlan_process:WLAN RT:PC=b00c87e0` → modem crash; hay que reiniciar.*

Nuestro propio crash en la vía mainline del Mi 8 Lite fue
`EX:wlan_process:WLAN RT:PC=b00c75b8` — **el mismo crash, misma función**. Esto
confirma que (a) no es un bug de nuestro port, es un límite conocido del firmware
`WLAN.HL.1.0.1.c6`, y (b) **en mainline el WiFi LLEGA A SER USABLE** (asocia,
navega), con la sola salvedad del crash al desconectar — manejable.

> Cambiar el firmware del modem entre teléfonos NO es opción: el modem va dentro del
> SoC y su firmware es específico de la build; además los candidatos usan modems
> distintos. Se descarta.

---

## Plan de ejecución (en mainline, en este orden)

### Fase 1 — PANTALLA / UI usable  ← PRIORIDAD ACTUAL
Objetivo: ver y tocar postmarketOS en la pantalla del teléfono.
1. Bootear el kernel mainline `linux-postmarketos-qcom-sdm660` en platina.
2. Confirmar DRM/KMS: debe existir `/dev/dri/card0` (`msm_drm`/`sde_kms`).
3. Verificar nodo de panel del platina en el devicetree mainline (DSI + panel).
4. Elegir UI ligera de pmOS que arranque con DRM (Phosh o Plasma Mobile) y validar
   que el compositor pinta. Ajustar `deviceinfo` (`deviceinfo_gpu_accelerated`,
   `deviceinfo_getty`, splash) según haga falta.
5. Touchscreen funcional.

### Fase 2 — WiFi usable (portar la receta de lavender, ath10k mainline)
Lavender corre el MISMO kernel (`linux-postmarketos-qcom-sdm660` 6.17.4) y el MISMO
chip (WCN3990) → su WiFi es directamente portable a platina.
1. Tomar de `firmware-xiaomi-lavender` el modelo: `ath10k/WCN3990/hw1.0/firmware-5.bin`
   + `board-2.bin`. Adaptar el board-2.bin a platina con `qmi-board-id=ff` en HEX
   (ya resuelto antes; ver memoria mi8lite-wifi-funcionando).
2. DT platina: `&wifi` okay + 4 regulators (vdd 0.8/1.8/1.3/3.3), `&remoteproc_mss`
   con `firmware-name` apuntando a mba.mbn/modem.mdt (`firmware-xiaomi-platina`).
3. Servicios: rmtfs (con `-s`, enciende MSS) + diag-router + tqftpserv en runlevel.
   Orden: recargar `ath10k_snoc` DESPUÉS de que el MSS esté arriba (~100s).
4. Aceptar la salvedad conocida de lavender (crash del WLAN al *desconectar*:
   `EX:wlan_process:WLAN RT:PC=b00c87e0`, idéntico a nuestro b00c75b8). Mitigación a
   investigar después: recuperación automática del MSS, o no desconectar.

> Nota: este WiFi es **ath10k mainline**, NO qcacld. Toda la maquinaria servreg/PD del
> downstream NO aplica aquí — en mainline el modem es remoteproc y rmtfs/pd-mapper de
> pmOS funcionan de fábrica.

### Fase 3 — Pulido
MAC (bootmac), arranque automático de servicios, energía, etc.

---

## Qué se conserva del trabajo downstream
- Conocimiento del firmware del modem extraído del teléfono (válido).
- board-2.bin con board-id hex + alias `ff` (reutilizable en mainline).
- Método de storage (`--single-partition` / `--split`) y fix de `e2fsck`.
- Diagnóstico completo de por qué qcacld no es viable aquí (este documento + memoria).

El árbol downstream (`device-xiaomi-platina-downstream`, `linux-xiaomi-platina`,
`servreg-locator`) se archiva como referencia; **no se sigue desarrollando**.
