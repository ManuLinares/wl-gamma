# wl-gamma

Wayland gamma relay daemon written in C3 (`zwlr_gamma_control_v1`).

## Build

```sh
c3c build
# or static standalone:
c3c build static
```

Dependencies: `c3c`, `wayland-client`, `dbus-1`.

## Usage

```sh
wl-gamma run
wl-gamma watch "{bp}% | {t}K"
```

Placeholders: `{t}` (temp K), `{g}` (gamma), `{b}` (brightness 0.0-1.0), `{bp}` (brightness %).

## D-Bus Interface

- **Service:** `rs.wl-gammarelay`
- **Interface:** `rs.wl.gammarelay`
- **Objects:** `/` (global), `/outputs/<name>` (`-` replaced with `_`, e.g. `/outputs/eDP_1`)

| Property | Type | Range |
|---|---|---|
| `Temperature` | `q` (uint16) | `1000..10000` |
| `Gamma` | `d` (double) | `>= 0.1` |
| `Brightness` | `d` (double) | `0.0..1.0` |
| `Inverted` | `b` (bool) | `true`/`false` |

| Method | Signature |
|---|---|
| `UpdateTemperature` | `n` (int16 delta) |
| `UpdateGamma` | `d` (double delta) |
| `UpdateBrightness` | `d` (double delta) |
| `ToggleInverted` | none |

## `busctl` Examples

```sh
# Methods
busctl --user -- call rs.wl-gammarelay / rs.wl.gammarelay UpdateTemperature n 500
busctl --user -- call rs.wl-gammarelay / rs.wl.gammarelay UpdateBrightness d -0.1
busctl --user -- call rs.wl-gammarelay / rs.wl.gammarelay ToggleInverted
busctl --user -- call rs.wl-gammarelay /outputs/eDP_1 rs.wl.gammarelay UpdateGamma d +0.05

# Properties
busctl --user -- set-property rs.wl-gammarelay / rs.wl.gammarelay Temperature q 4500
busctl --user -- set-property rs.wl-gammarelay / rs.wl.gammarelay Brightness d 0.8
busctl --user -- get-property rs.wl-gammarelay / rs.wl.gammarelay Temperature
```

---

_replaces https://github.com/MaxVerevkin/wl-gammarelay-rs and https://github.com/jeremija/wl-gammarelay_