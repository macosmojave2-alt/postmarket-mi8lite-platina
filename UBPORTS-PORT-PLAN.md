# Plan: Port Ubuntu Touch a Xiaomi Mi 8 Lite (platina)

## Objetivo
Portar Ubuntu Touch al Mi 8 Lite usando como base el Redmi Note 7 (lavender).
Ambos dispositivos usan Qualcomm SDM660, lo que hace el port viable.

## Referencias
- Guía UBports: https://docs.ubports.com/es/latest/porting/introduction/Intro.html
- Device repo base: https://gitlab.com/ubports/porting (buscar lavender)
- Kernel Xiaomi: https://github.com/MiCode/Xiaomi_Kernel_OpenSource/tree/nitrogen-q-oss
- Device tree lavenderOSS: https://github.com/lavenderOSS/device_xiaomi_sdm660-common

## Paso a paso

### Fase 1: Preparar el entorno de compilación (PC)
- [ ] Instalar dependencias del build (Ubuntu/Debian)
- [ ] Instalar repo de Google
- [ ] Configurar git y crear cuenta GitLab/UBports

### Fase 2: Obtener el código fuente
- [ ] Clonar device repo de lavender de UBports
- [ ] Clonar kernel source de Xiaomi (nitrogen-q-oss)
- [ ] Encontrar defconfig correcto para platina
- [ ] Crear halium.config con configs mínimas

### Fase 3: Configurar deviceinfo
- [ ] Rellenar deviceinfo con datos de platina
- [ ] Extraer offsets del boot.img stock (si disponible)
- [ ] Configurar kernel cmdline

### Fase 4: Compilar
- [ ] Compilar kernel con ./build.sh
- [ ] Verificar que genera boot.img

### Fase 5: Instalar y probar
- [ ] Poner teléfono en fastboot
- [ ] Flashear boot.img
- [ ] Arrancar y verificar consola
- [ ] Verificar WiFi, pantalla, sonido, etc.

### Fase 6: Configurar y pulir
- [ ] Configurar deviceinfo completos
- [ ] Agregar soporte WiFi
- [ ] Agregar soporte pantalla
- [ ] Configurar UBports installer

## Notas importantes
- platina y lavender son casi idénticos (mismo SDM660, mismos PMIC)
- Se puede reutilizar el device tree de lavender con mínimos cambios
- El bootloader ya está desbloqueado
- El kernel de Xiaomi (nitrogen-q-oss) tiene ICNSS incluido
