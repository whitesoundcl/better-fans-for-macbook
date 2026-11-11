# Better Fans For Macbook

English · **[Español](README.es.md)**

Fan control for Apple Silicon MacBooks, from the menu bar. It replaces macOS's conservative fan behavior with an **editable temperature → speed curve** and several profiles.

- Menu bar app (SwiftUI) showing live temperature and RPM.
- Built-in profiles: *Automático (Apple)* (macOS default), *Frío para piernas* (cool for your lap), *Silencioso* (quiet) and *Máximo* (maximum). You can create your own.
- Visual curve editor: drag points, double-click to add one, right-click to remove it.
- Hysteresis and speed ramping to avoid oscillating fan noise.
- Debug CLI (`fanctl`) to read sensors and test the fans.

> **Note.** The app is currently in Spanish (menus and profile names).

> **Warning.** This project writes to the SMC through an **undocumented** Apple interface. Use it at your own risk. It has only been tested on the machines listed in [Tested machines](#tested-machines). It is not affiliated with any other fan-control software vendor.

## Requirements

- A Mac with **Apple Silicon** and **macOS 13 or later**.
- **Xcode** (or the *Command Line Tools*) with **Swift 5.9+**: `xcode-select --install`.
- Administrator rights (`sudo`) to install the helper.

## Build

```bash
git clone https://github.com/whitesoundcl/better-fans-for-macbook.git
cd better-fans-for-macbook
./scripts/build.sh
```

This produces, in `dist/`:

| File | What it is |
|---|---|
| `Better Fans For Macbook.app` | The menu bar app |
| `fanhelperd` | The privileged helper that writes to the fans |
| `fanctl` | Command-line tool |

## Test before installing (recommended)

1. Read-only, no privileges needed:

   ```bash
   dist/fanctl status
   ```

   It should list your fans (current, minimum and maximum RPM) and the hottest sensors.

2. Write test, with `sudo`. It holds the fans at 3000 RPM for 20 s and then hands control back to macOS:

   ```bash
   sudo dist/fanctl set 3000 20
   ```

   If the `actual` RPM approaches 3000, manual control works on your machine. If not, **stop here** and open an issue with the output of `dist/fanctl dump`.

## Install and run

1. Quit any other app that controls the fans. This app shows a warning in its menu if it detects that another app has the fans in manual mode.
2. Install the helper as a system service:

   ```bash
   sudo scripts/install-helper.sh
   ```

3. Open the app:

   ```bash
   open "dist/Better Fans For Macbook.app"
   ```

   The temperature and RPM appear in the menu bar. Pick a profile from the menu; if it says **"Curva activa"** (curve active), it's working.

Optional: copy `dist/Better Fans For Macbook.app` to `/Applications` and enable **"Abrir al iniciar sesión"** (open at login) in the menu.

## Uninstall

```bash
sudo scripts/uninstall.sh
```

This returns the fans to macOS and removes the helper. You can then delete `Better Fans For Macbook.app`. Your custom profiles are stored in `~/Library/Application Support/BetterFans/profiles.json`.

## Safety

- The helper **always clamps** the target to each fan's own minimum and maximum.
- **Watchdog:** if the app stops responding for 10 s (it quits or hangs), the helper hands the fans back to macOS.
- **Thermal limit:** at 90 °C or above, the curve is ignored and the fans go to maximum.
- If the sensors can't be read, control is handed back to macOS.
- The helper only accepts connections from the logged-in user (or root). The app and helper are *ad-hoc* signed, which is fine for personal use.

## Development

```bash
swift build        # build everything
swift test         # tests for the curve, the controller and SMC decoding
```

```
Sources/
  FanCore/     SMC (IOKit), sensors, curve, profiles, controller, fan driver
  fanhelperd/  privileged helper (LaunchDaemon + XPC)
  BetterFans/  menu bar app (SwiftUI)
  fanctl/      debug CLI
scripts/       build, install and uninstall
```

## Tested machines

| Machine | Chip | macOS | Result |
|---|---|---|---|
| MacBook Pro | M1 Pro | 26 | Works |
| MacBook Pro (`Mac15,6`) | M3 Pro | 15.7 | Works: sensors, manual control and curves |

## Other chips (M2, M4…)

Fan control is generic, but **temperature sensor names vary by chip**. The app currently only considers the `Tp*`, `Te*` and `Tg*` keys (present on M1 and M3). On other chips it may underestimate the CPU temperature. If you try it on another machine, please attach the output of `dist/fanctl dump` to an issue.

## License

[MIT](LICENSE). The software is provided "as is", without warranty of any kind.
