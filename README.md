# omarchy-logi-battery

An [Omarchy](https://omarchy.org/) shell bar widget showing a wireless mouse's
battery percentage.

```
󰍽 90%
```

## Why this exists

The kernel's `hid-logitech-hidpp` driver already talks to Logitech wireless
mice, but for many of them — the Logitech G603 among them — it publishes only a
coarse level:

```
$ cat /sys/class/power_supply/hidpp_battery_0/capacity_level
Full                       # and no `capacity` file beside it
$ upower -i .../battery_hidpp_battery_0
  percentage:          100% (should be ignored)
```

The percentage does exist. The driver reads a numeric charge from the device
but only exposes it as a `capacity` file when the device advertises a
"mileage" capability flag — which these mice don't set, even though they answer
the query perfectly well. Logitech's own G HUB shows the number; it just asks
directly.

So `logi-battery` asks directly too, in Python with nothing but the standard
library.

## What it reads

| Source | Gives | Covers |
|---|---|---|
| HID++ `0x1004` UNIFIED BATTERY | state-of-charge %, else a coarse level | newer Logitech devices |
| HID++ `0x1000` BATTERY STATUS | discharge level % | older Logitech devices (G603 and friends) |
| HID++ `0x1001` BATTERY VOLTAGE | mV, converted with a Li-ion curve | Logitech rechargeables |
| sysfs `capacity` | % | anything else the kernel already reports properly, e.g. Bluetooth mice using the HID battery service |
| sysfs `capacity_level` | Full/High/Normal/Low/Critical | the fallback when no number is available |

It considers **only mice** — the widget draws a mouse, so a keyboard's battery
under that glyph would be a lie, and a device it won't report on is a device it
won't wake. Among mice it prefers a real percentage over a coarse level, which
is what makes a live HID++ reading win over the same device's sysfs entry, and
what lets that entry stand in while the mouse sleeps.

**Not covered:** mice whose battery is reported only over Bluetooth's GATT
battery service through BlueZ, with no kernel power supply behind it. Those
need UPower/D-Bus rather than the two paths above.

## Requirements

- Omarchy 4.x (the Quickshell-based `omarchy-shell`)
- For **Logitech HID++ devices**: `solaar`, installed for its udev rule
  (`42-logitech-unify-permissions.rules`, which tags Logitech hidraw nodes
  `uaccess`). Without that rule the node is root-only and the HID++ path cannot
  read it. Solaar is not used at runtime; it is also the easiest way to check
  what your device reports:

  ```bash
  omarchy pkg add solaar
  solaar show | grep -i battery
  ```

  The sysfs paths need no permissions and no extra packages.

## Install

```bash
omarchy plugin add https://github.com/Proxy1967/omarchy-logi-battery.git --enable
```

Or by hand:

```bash
git clone https://github.com/Proxy1967/omarchy-logi-battery.git \
  ~/.config/omarchy/plugins/proxy.logi-battery
omarchy-shell shell rescanPlugins
omarchy plugin enable proxy.logi-battery
omarchy bar move proxy.logi-battery --section right
```

Note that editing a bar widget's QML does **not** hot-reload the running
instance, despite the `Local plugin changed, reloading` log line. Use
`omarchy restart shell` after changes.

## Uninstall

```bash
omarchy plugin remove proxy.logi-battery
```

That disables the widget, unloads it from the running shell and deletes
`~/.config/omarchy/plugins/proxy.logi-battery/`. The plugin writes nothing
outside that directory and its own entry in `~/.config/omarchy/shell.json`, so
there is nothing further to clean up — `solaar`, if you installed it for the
udev rule, is yours to keep or remove with `omarchy pkg remove solaar`.

To keep the plugin installed but take it off the bar:

```bash
omarchy plugin disable proxy.logi-battery
```

## Settings

| Key | Default | What it does |
|---|---|---|
| `device` | `""` | Case-insensitive substring of the device name, for when more than one mouse is connected. Empty lets the widget pick. |

```bash
omarchy bar set proxy.logi-battery device "MX Master"
```

## Behavior

| State | Shown |
|---|---|
| Percentage available | mouse glyph + `NN%` |
| Only a coarse level readable | mouse glyph + a battery glyph for `Full`/`High`/`Normal`/`Low`/`Critical` |
| No mouse battery at all | widget hides itself |

At or below 20% it switches to the theme's `urgent` color. The tooltip carries
the device name and reading. On a vertical bar the mouse glyph is dropped and
the bare number shown. Polled every 5 minutes: the value moves in coarse steps,
and each poll briefly wakes the mouse's radio.

## Limitations

- **The number is a coarse ladder, not a gauge.** A G603 steps 100 → 90 → 50,
  and the reading bounces between the top steps as cell voltage recovers while
  the mouse rests. Don't read a trend into small changes.
- An idle mouse ignores requests until its radio link wakes, so the reader
  retries; a device that is off falls back to the kernel's level.
- The 20% urgent threshold is a guess. The step ladder below 50% is unknown
  until a set of batteries actually drains.
- A device is recognised as a mouse by the kernel's `mouseN` node. Something
  that reports a battery without presenting as a pointing device won't show up.
- HID++ `0x1004` reports 0 for "no state-of-charge here" and for a flat
  battery alike, so a genuinely empty one falls back to its coarse level.

## License

MIT
