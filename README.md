# Xiaomi Mi 8 Lite (xiaomi-platina) — postmarketOS mainline port

postmarketOS port for the **Xiaomi Mi 8 Lite** (codename `platina`, Qualcomm
SDM660), using the mainline kernel package `linux-postmarketos-qcom-sdm660`
(6.19.10).

## Status

| Feature | Status |
|---|---|
| Boot to userspace | ✅ |
| Display (BOE TD4320, 1080x2280) | ✅ working |
| Backlight (PM660L WLED) | ✅ |
| GUI (Weston) | ✅ desktop shows up |
| USB networking | ✅ |
| Touchscreen (Novatek NT36xxx) | 🚧 work in progress (currently disabled) |
| WiFi (WCN3990) | 🚧 bring-up done, blocked on firmware (earlier work) |
| Modem (MSS) | 🚧 earlier work |

## Display — how it works

The Mi 8 Lite uses a **BOE TD4320** 1080x2280 DSI video-mode panel (same
controller family as the Redmi Note 7 *lavender*, different resolution/init).

The key to getting a stable image was to **not** re-initialize the panel from
the kernel. The bootloader already powers and initializes the panel (the boot
splash is visible), so the kernel only needs to keep the video stream running.
Using a command-mode panel driver (re-running reset + init sequence) left the
panel showing vertical stripes and then black.

What works (see the kernel patches):

- Use the **`panel-simple`** driver with `compatible = "boe,td4320"`, **no**
  command init sequence. (Per the postmarketOS Mainlining FAQ: "if your device
  shows the boot splash with mainline, simple panel should work".)
- DSI flags: `MIPI_DSI_MODE_VIDEO | MIPI_DSI_MODE_VIDEO_HSE |
  MIPI_DSI_CLOCK_NON_CONTINUOUS`, 4 lanes, RGB888.
- Mode (from downstream `qcom,mdss_dsi_boe_fhd_td4320_video`): 1080x2280@60,
  hfp=92 hpw=20 hbp=112, vfp=12 vpw=4 vbp=60.
- Set `has_idle_pc = false` in the SDM660 DPU catalog: with idle power collapse
  the INTF is switched off after the first frame and the panel goes black.
- PM660L LCDB VSP/VSN supplies do **not** need a driver — the bootloader leaves
  them on. (Modeled as fixed regulators here; not strictly required.)

## Layout

- `linux-postmarketos-qcom-sdm660/` — kernel package patches and config:
  - `0001-platina-enable-display.patch` — DT: enable display pipeline + panel,
    reserved-memory cleanup, touch/audio disabled for a clean log.
  - `0002-panel-simple-td4320.patch` — add BOE TD4320 to `panel-simple`.
  - `0003-dpu-sdm660-disable-idle-pc.patch` — disable DPU idle power collapse.
- `device-xiaomi-platina/` — device package (deviceinfo, modules, helper scripts).
- `firmware-xiaomi-platina/` — firmware packaging (proprietary blobs are **not**
  versioned; see `.gitignore`).

## Credits

Thanks to the postmarketOS / sdm660-mainline community — Alexey Minnekhanov
(alexeymin), Barnabas Czeman (bbarni2000) and setotau — for guidance on the
SDM660 display bring-up.

## Notes

Proprietary firmware (modem/WiFi/zap blobs) is intentionally excluded from this
repository.
