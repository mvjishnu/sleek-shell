# Sleek Shell Calculator & Unit Converter

An offline scientific calculator and unit converter that runs inside rofi 2.0 (Wayland).
The engine is pure Python stdlib. Input goes through a hand-written tokenizer and
recursive-descent parser. Nothing is ever passed to `eval`/`exec`/`compile` or a shell.

## Launch

```sh
sleek-calc                 # toggle the rofi calculator (closes rofi if it is already open)
sleek-calc "10 mi to km"   # open with the input pre-filled
sleek-calc --cli "2^10"    # print the result in the terminal (records history and ans)
```

What the launcher runs:

```sh
rofi -plugin-path ~/.local/lib/rofi -modi calc -show calc -no-sort -no-show-icons -theme-str '…'
```

The `-theme-str` adds the `message` widget, which shows the angle mode, key hints and errors,
and sets a placeholder. It does not change any theme files. If `sleekcalc.so` is missing, the
launcher falls back to rofi script mode (`sleek_calc.py --script`). In that mode the result
appears after you press Enter.

Example Hyprland bind (add it yourself):
`bind = SUPER, C, exec, ~/.local/bin/sleek-calc`

## Keys (rofi defaults)

| Key | Action |
| --- | --- |
| typing | Live result in row 0; conversions list alternative units below it |
| Enter | Copy the selected row's result (`wl-copy`), save it to history, close |
| Shift+Enter / Alt+1 | Reuse: put the result back into the input to keep calculating |
| Alt+2 | Copy only the number (no unit) |
| Ctrl+Enter | Copy the live result even if another row is selected |
| Ctrl+Shift+Enter | Reuse the live result |
| Ctrl+Space | Put the selected row's result into the input |
| Shift+Delete | Remove the selected history entry |
| Escape | Close |

When the input is empty, the last 50 calculations are listed (`↺`). Live rows: `=` result,
`→` alternative unit, `⚠` error, `↵` command.

## Syntax

- `+ - * /` and parentheses. `^` or `**` for powers (right-associative, `-2^2 = -4`).
  Implicit multiplication works: `2pi`, `3(4+1)`.
- `%` is a percentage: `50%` = 0.5, `25% of 840` = 210, `840 + 10%` = 924,
  `840 - 10%` = 756.
- `mod` for modulo (`17 mod 5`), `!` for factorial (`5!`). Scientific notation:
  `1.5e-3`, `1E6`. Hex input: `0xff`.
- Functions: `sqrt cbrt root(x,n) abs exp ln log log(x,base) log2 sin cos tan asin acos
  atan atan2 sinh cosh tanh asinh acosh atanh floor ceil round(x[,n]) trunc sign min max
  sum avg hypot gcd lcm nCr nPr fact gamma deg rad`.
- Constants: `pi π tau e phi`. `ans` is the last copied or committed result.
- Angle mode: degrees by default. Type `:rad` or `:deg` and press Enter to switch;
  the setting is saved. A one-off prefix also works: `:rad sin(pi/2)`. Angle units
  override the mode: `sin(90 deg)`, `cos(pi rad)`.

## Units

Convert with `to`, `in`, `as`, `into`, `->` or `→`. For example: `10 miles to km`,
`100 km/h to mph`, `32 F to C`, `1 GB to MiB`, `5 uk gal to L`, `30 mpg to L/100km`.
A bare quantity like `10 km` lists common equivalents.

Supported categories: length, area, volume (US and `uk`/imperial), mass, time,
temperature (°C °F K °R; handled as affine offsets), speed, acceleration, pressure,
energy, power, force, frequency, angle, data (SI and IEC bytes/bits), data rate and
fuel economy. Unit arithmetic works too: `5 km / 20 min to km/h`.

Ambiguities:
- `C`/`F` mean °C/°F. `t` is the metric tonne, `ton` is the US short ton.
- `gal`, `pt`, `qt`, `cup` and `floz` are US measures; use a `uk`/`imp` prefix for imperial.
- `in` is both the inch and a conversion keyword. The **rightmost** separator is
  the conversion, so `1 kg to lb in` behaves unexpectedly. Write `inch` when in doubt.
- After a quantity, `/ number unit` divides by the whole measure: `100 km / 2 h` = 50 km/h.
  With a plain number on the left, it reads like a desk calculator: `1/2 km` = 0.5 km.
- Converting incompatible units gives an error, e.g. `Cannot convert mass to length`.

## Limits

Input is limited to 512 characters and nesting to 60 levels. Factorials go up to 1000.
Results with exponents above about 10^100000 give `Result too large` (for example `9^9^9`).
Numbers are computed with exact fractions and 50-digit decimals; trig uses floats.
Results show 12 significant digits by default and switch to scientific notation for
exponents ≥ 15 or < -7.

Not supported: physical constants such as `c`, charge or capacitance units
(coulomb, farad), and currencies.
Compound units can display unsimplified (`10 m/s^2 * 2 s` shows `20 m/s^2*s`).
In the plugin, the row count and message bar can lag about 66 ms behind typing.

## Files

| Path | Purpose |
| --- | --- |
| `~/.local/share/sleek-shell/calc/sleek_calc.py` | Engine + CLI (`--json [--commit]`, `--serve`, `--script`) |
| `~/.local/share/sleek-shell/calc/test_sleek_calc.py` | Unit tests: `python3 -m unittest test_sleek_calc` |
| `~/.local/share/sleek-shell/calc/rofi-sleek-calc.c`, `Makefile` | Rofi 2.0 plugin source (ABI 7) |
| `~/.local/lib/rofi/sleekcalc.so` | Installed plugin |
| `~/.local/bin/sleek-calc` | Launcher |
| `~/.local/share/applications/sleek-calc.desktop` | Desktop entry ("Calculator") |
| `$XDG_CONFIG_HOME/sleek-shell/settings.json` | `calc.angleMode` (`deg`/`rad`), `calc.precision` (1–40) |
| `$XDG_STATE_HOME/sleek-shell/calc-history.json`, `calc-state.json` | History (50 entries) and `ans` |

Environment overrides: `SLEEK_CALC_CONFIG`, `SLEEK_CALC_STATE`, `SLEEK_CALC_SCRIPT`,
`SLEEK_CALC_PYTHON`, `SLEEK_CALC_PLUGIN_DIR`.

## Rebuild the plugin

```sh
make -C ~/.local/share/sleek-shell/calc install
```

Rofi 2.0 has no system plugin directory on this machine, so the plugin is loaded with
`-plugin-path ~/.local/lib/rofi` (or `ROFI_PLUGIN_PATH`). After a rofi upgrade that changes
`ABI_VERSION` in `/usr/include/rofi/mode.h`, rebuild the plugin.
