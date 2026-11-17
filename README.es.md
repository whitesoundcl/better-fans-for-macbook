# Better Fans For Macbook

**[English](README.md)** · Español

Control de ventiladores para MacBook con Apple Silicon, desde la barra de menús. Reemplaza la curva conservadora de macOS por una **curva temperatura → velocidad editable**, con varios perfiles.

- App de barra de menús (SwiftUI) con temperatura de CPU/GPU en vivo, mini gráfico de 10 minutos y velocidad de ventiladores.
- Ventana *Monitor* con gráficos de temperatura y velocidad (de 5 min a 1 h; al pasar el mouse muestra los valores exactos).
- Temperatura ambiente desde el sensor de aire del equipo (`TAOL` en M5 Pro; si no, la primera clave `TA*`). Es aire *dentro* del Mac, así que marca unos grados más que la sala; solo se muestra, nunca mueve los ventiladores.
- Perfiles incluidos: *Automático (Apple)*, *Frío para piernas*, *Silencioso* y *Máximo*. Puedes crear los tuyos.
- Ventana *Curvas*: editor visual (arrastra puntos, doble clic añade uno, clic derecho lo elimina), histéresis y rampas, y duplicar, eliminar o restablecer perfiles.
- Histéresis y rampa de velocidad para evitar zumbidos oscilantes.
- Ventana *Sensores* con todos los sensores de temperatura del SMC (agrupados, con filtro, en vivo).
- CLI de depuración (`fanctl`) para leer sensores y probar los ventiladores.

> **Aviso.** Este proyecto escribe en el SMC mediante una interfaz **no documentada** de Apple. Úsalo bajo tu responsabilidad. Se ha probado solo en los equipos de [Equipos probados](#equipos-probados). No está afiliado a ningún otro fabricante de software de control de ventiladores.

## Requisitos

- Mac con **Apple Silicon** y **macOS 13 o superior**.
- **Xcode** (o las *Command Line Tools*) con **Swift 5.9+**: `xcode-select --install`.
- Permisos de administrador (`sudo`) para instalar el helper.

## Compilar

```bash
git clone https://github.com/whitesoundcl/better-fans-for-macbook.git
cd better-fans-for-macbook
./scripts/build.sh
```

Esto genera en `dist/`:

| Archivo | Qué es |
|---|---|
| `Better Fans For Macbook.app` | La app de barra de menús |
| `fanhelperd` | El helper con privilegios que escribe en los ventiladores |
| `fanctl` | Herramienta de línea de comandos |

## Probar antes de instalar (recomendado)

1. Lectura, sin privilegios:

   ```bash
   dist/fanctl status
   ```

   Debe mostrar tus ventiladores (RPM actual, mínimo y máximo) y los sensores más calientes.

2. Escritura, con `sudo`. Fija los ventiladores a 3000 RPM durante 20 s y luego devuelve el control a macOS:

   ```bash
   sudo dist/fanctl set 3000 20
   ```

   Si las RPM (`actual`) se acercan a 3000, el control manual funciona en tu equipo. Si no, **no sigas**: abre un issue con la salida de `dist/fanctl dump`.

## Instalar y ejecutar

1. Cierra cualquier otra app que controle los ventiladores. La app avisa en el menú si detecta que otra app los tiene en modo manual.
2. Instala el helper como servicio del sistema:

   ```bash
   sudo scripts/install-helper.sh
   ```

3. Abre la app:

   ```bash
   open "dist/Better Fans For Macbook.app"
   ```

   Aparecerá la temperatura y las RPM en la barra de menús. Elige un perfil en el menú; si dice **«Curva activa»**, está funcionando.

Opcional: copia `dist/Better Fans For Macbook.app` a `/Applications` y activa **«Abrir al iniciar sesión»** en el menú.

## Desinstalar

```bash
sudo scripts/uninstall.sh
```

Devuelve los ventiladores a macOS y elimina el helper. Después puedes borrar `Better Fans For Macbook.app`. Tus perfiles personalizados se guardan en `~/Library/Application Support/BetterFans/profiles.json`.

## Seguridad

- El helper **limita siempre** el objetivo al mínimo y máximo de cada ventilador.
- **Watchdog:** si la app no da señales durante 10 s (se cierra o se cuelga), el helper devuelve los ventiladores a macOS.
- **Límite térmico:** a 90 °C o más ignora la curva y sube los ventiladores al máximo.
- Si no se pueden leer los sensores, se devuelve el control a macOS.
- El helper solo acepta conexiones del usuario que tiene la sesión iniciada (o root). La app y el helper se firman de forma *ad-hoc*, adecuada para uso personal.

## Desarrollo

```bash
swift build        # compila todo
swift test         # tests de la curva, el controlador, el historial y la decodificación del SMC
```

Para revisar la interfaz sin abrir la barra de menús, renderiza todas las ventanas con datos de ejemplo a PNG (claro y oscuro):

```bash
"$(swift build -c release --show-bin-path)/BetterFans" --snapshot /tmp/betterfans-ui
```

```
Sources/
  FanCore/     SMC (IOKit), sensores, curva, perfiles, controlador, driver de ventiladores
  fanhelperd/  helper privilegiado (LaunchDaemon + XPC)
  BetterFans/  app de barra de menús (SwiftUI)
  fanctl/      CLI de depuración
scripts/       build, instalación y desinstalación
```

## Equipos probados

| Equipo | Chip | macOS | Resultado |
|---|---|---|---|
| MacBook Pro | M1 Pro | 26 | Funciona |
| MacBook Pro (`Mac15,6`) | M3 Pro | 15.7 | Funciona: sensores, control manual y curvas |
| MacBook Pro (`Mac17,9`) | M5 Pro | 27.2 | Funciona: sensores, control manual y curvas (la clave de modo es `F<n>md`, sin `Ftst`) |

## Otros chips (M2, M4…)

El control de ventiladores es genérico, pero los **nombres de los sensores de temperatura varían según el chip**. La app solo considera hoy las claves `Tp*`, `Te*` y `Tg*` (presentes en M1, M3 y M5; el M5 no tiene `Te*`). En otros chips puede subestimar la temperatura del CPU. Si pruebas en otro equipo, adjunta la salida de `dist/fanctl dump` en un issue.

## Licencia

[MIT](LICENSE). El software se entrega «tal cual», sin garantía de ningún tipo.
