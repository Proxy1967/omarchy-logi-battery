# omarchy-logi-battery

An [Omarchy](https://omarchy.org/) shell bar widget showing a Logitech wireless
mouse's battery percentage.

```
󰍽 90%
```

## Why this exists

The kernel's `hid-logitech-hidpp` driver already talks to these mice, but for
some of them — the Logitech G603 among them — it publishes only a coarse level:

```
$ cat /sys/class/power_supply/hidpp_battery_0/capacity_level
Full                       # and no `capacity` file beside it
$ upower -i .../battery_hidpp_battery_0
  percentage:          100% (should be ignored)
```

The percentage does exist. The driver reads a numeric discharge level from
HID++ feature `0x1000`, but only exposes it as a `capacity` file when the device
advertises the "mileage" capability flag — which these devices don't, even
though they answer the query perfectly well. Logitech's own G HUB shows the
number; it just asks directly.

So `logi-battery` asks directly too: two short HID++ requests over the mouse's
`hidraw` node, about 0.15s, Python standard library only.

Note the reading is a **stepped gauge, not a smooth readout** — a G603 reports
90% with "next level 50%".

## Requirements

- Omarchy 4.x (the Quickshell-based `omarchy-shell`)
- **`solaar`** — installed for its udev rule
  (`42-logitech-unify-permissions.rules`, which tags Logitech hidraw nodes
  `uaccess`). Without that rule the node is root-only and this widget cannot
  read it. Solaar itself is not used at runtime; it is also the easiest way to
  confirm your device reports a percentage at all:

  ```bash
  omarchy pkg add solaar
  solaar show | grep -A1 'BATTERY STATUS'
  ```

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

## Behavior

| State | Shown |
|---|---|
| Percentage available | mouse glyph + `NN%` |
| HID++ unreachable, kernel level readable | mouse glyph + a battery glyph for `Full`/`High`/`Normal`/`Low`/`Critical` |
| No Logitech HID++ device | widget hides itself |

At or below 20% the widget switches to the theme's `urgent` color. The tooltip
carries the device name and reading. On a vertical bar the mouse glyph is
dropped and the bare number shown.

Polled every 5 minutes: the value moves in coarse steps over weeks, and each
poll briefly wakes the mouse's radio.

## Limitations

- Takes the **first** `logitech-hidpp-device` node it finds. A second HID++
  device (keyboard, headset) would need a way to say which one is meant.
- An idle mouse ignores the first request or two — those wake the radio link
  rather than answer it. The reader retries up to 5 times at 0.5s; a device
  that is off simply falls back to the kernel level.
- The 20% urgent threshold is a guess. The step ladder below 50% is unknown
  until a set of batteries actually drains.

## License

MIT
