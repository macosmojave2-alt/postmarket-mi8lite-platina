#!/bin/sh
# Diagnostico de pantalla Mi 8 Lite (platina) - panel BOE TD4320 / DPU SDM660
# Uso:  sudo diag-pantalla.sh            (imprime y guarda en /tmp/diag-pantalla.txt)
# Luego: copiar /tmp/diag-pantalla.txt por SSH para analizarlo.
#
# Recoge todos los frentes que importan para saber si el panel se enciende:
# DPU/DSI/panel, GPU/zap, firmware, regulators/clocks, vsync (INTF vivo?).

OUT=/tmp/diag-pantalla.txt
exec > >(tee "$OUT") 2>&1

sec() { printf '\n========== %s ==========\n' "$1"; }

echo "diag-pantalla  $(date)  kernel=$(uname -r)"

sec "1. dmesg display/GPU (lo mas importante)"
dmesg | grep -iE "dpu|dsi|panel|td4320|drm|msm|mdss|backlight|vsync|underflow|adreno|a512|zap|gpu|gmu|smmu" || echo "(sin coincidencias)"

sec "2. errores y warnings de boot"
dmesg -l err,warn 2>/dev/null | tail -n 60 || dmesg | grep -iE "error|fail|warn|panic|oops" | tail -n 60

sec "3. firmware solicitado / faltante"
dmesg | grep -iE "firmware|direct-loading|failed to load|requesting" || echo "(sin coincidencias)"
echo "--- contenido /lib/firmware/postmarketos ---"
ls -la /lib/firmware/postmarketos/ 2>/dev/null || echo "(no existe)"
echo "--- ath10k WCN3990 ---"
ls -la /lib/firmware/ath10k/WCN3990/hw1.0/ 2>/dev/null || echo "(no existe)"

sec "4. conectores / modos DRM"
for c in /sys/class/drm/card*-DSI-*; do
	[ -e "$c" ] || continue
	echo "--- $c ---"
	echo "status : $(cat "$c/status" 2>/dev/null)"
	echo "enabled: $(cat "$c/enabled" 2>/dev/null)"
	echo "modes  : $(cat "$c/modes" 2>/dev/null | tr '\n' ' ')"
done

sec "5. estado DRM vivo (planes/pipes/encoder)"
cat /sys/kernel/debug/dri/*/state 2>/dev/null || echo "(no accesible - necesita root/debugfs)"

sec "6. vsync: INTF vivo o congelado? (2 lecturas, 1s)"
ENC=$(ls -d /sys/kernel/debug/dri/*/encoder* 2>/dev/null | head -n1)
if [ -n "$ENC" ]; then
	echo "encoder: $ENC"
	echo "--- t0 ---"; cat "$ENC"/* 2>/dev/null | grep -iE "vsync|frame|fps|status|kickoff"
	sleep 1
	echo "--- t1 (1s) ---"; cat "$ENC"/* 2>/dev/null | grep -iE "vsync|frame|fps|status|kickoff"
else
	echo "(no hay debugfs de encoder)"
fi

sec "7. backlight"
for b in /sys/class/backlight/*; do
	[ -e "$b" ] || continue
	echo "--- $b ---"
	echo "power     : $(cat "$b/bl_power" 2>/dev/null)"
	echo "brightness: $(cat "$b/brightness" 2>/dev/null) / $(cat "$b/max_brightness" 2>/dev/null)"
done
[ -e /sys/class/backlight ] || echo "(no hay /sys/class/backlight)"

sec "8. regulators (alimentacion DSI/panel)"
cat /sys/kernel/debug/regulator/regulator_summary 2>/dev/null | grep -iE "vreg_l1a|vreg_l1b|name|dsi|wled|lab|ibb" || echo "(no accesible)"

sec "9. clocks display"
cat /sys/kernel/debug/clk/clk_summary 2>/dev/null | grep -iE "dsi|mdp|disp|byte|pclk|esc|mdss" || echo "(no accesible)"

sec "10. drivers DRM cargados / bind"
cat /sys/kernel/debug/dri/*/clients 2>/dev/null
echo "--- devices que NO bindearon ---"
for d in /sys/bus/platform/devices/*; do
	drv="$d/driver"
	if [ ! -e "$drv" ]; then
		case "$(basename "$d")" in
			*mdss*|*dsi*|*dpu*|*gpu*|*display*) echo "SIN DRIVER: $(basename "$d")";;
		esac
	fi
done

sec "11. modulos cargados (panel/msm)"
lsmod 2>/dev/null | grep -iE "panel|msm|drm|td4320" || echo "(ninguno - todo builtin?)"

echo
echo "==> Guardado en $OUT . Copialo por SSH y pegalo."
