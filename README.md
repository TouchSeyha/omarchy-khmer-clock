# Omarchy Khmer Clock

An [Omarchy](https://omarchy.org) clock and calendar bar widget that highlights **Cambodia public holidays** directly on the calendar grid and lists what's happening each month—in **English**, **Khmer**, or **both**.

Holidays are fetched automatically from Google Calendar's public Cambodia holidays `.ics` feed and cached locally, so you never have to update dates manually each year (including lunar holidays like Khmer New Year, Visak Bochea, Pchum Ben, and Water Festival).

## Features

- Replaces the stock Omarchy clock seamlessly (keeps bar time formatting, right-click format cycling, middle-click timezone menu, ISO week numbers, week-start toggle, year progress bar, and keyboard/scroll navigation)
- Highlights Cambodia public holidays directly on the month grid with tooltips
- Shows a clean **Cambodia Holidays** summary for the month you're viewing (and shows the next upcoming holiday when a month has none)
- Instant language switcher (`EN` / `ខ្មែរ` / `EN · ខ្មែរ`) in the panel header (or press `L`)
- Offline-friendly: caches the `.ics` feed in `~/.cache/omarchy-khmer-clock/cambodia-holidays.ics` and refreshes automatically once every 7 days

## Install

```bash
omarchy plugin add https://github.com/TouchSeyha/omarchy-khmer-clock.git --enable
```

Then replace `omarchy.clock` with `touchseyha.khmer-clock` in `~/.config/omarchy/shell.json` (in `bar.layout.center`).

## Update

```bash
omarchy plugin update touchseyha.khmer-clock
omarchy restart shell
```

## Configuration

All settings are optional and live on the widget entry in `~/.config/omarchy/shell.json`:

```json
{
  "id": "touchseyha.khmer-clock",
  "format": "h:mm AP",
  "formatAlt": "d MMMM 'W'ww yyyy",
  "verticalFormat": "HH\n—\nmm",
  "holidayLanguage": "en",
  "autoRefresh": true
}
```

| Option | Values | Default | Description |
| --- | --- | --- | --- |
| `holidayLanguage` | `"en"`, `"km"`, `"both"` | `"en"` | Language for holiday names (also switchable live in the panel) |
| `autoRefresh` | `true`, `false` | `true` | Automatically refresh the cached feed every 7 days when stale; set `false` for cache-only mode (manual refresh button still works) |

## Keyboard shortcuts (when popup is open)

- `←` / `→` or `[` / `]` — previous / next month
- `↑` / `↓` or `{` / `}` — previous / next year
- `T` — jump back to today
- `W` — toggle week start (Sunday / Monday)
- `L` — cycle holiday language (`EN` → `ខ្មែរ` → `EN · ខ្មែរ`)

## Data & Network

- Connects only to Google Calendar's fixed HTTPS public Cambodia holidays feed:
  `https://calendar.google.com/calendar/ical/en.kh%23holiday%40group.v.calendar.google.com/public/basic.ics`
- Enforces a 15-second timeout and 256 KiB response size cap.
- Caches only the `.ics` file in `~/.cache/omarchy-khmer-clock/cambodia-holidays.ics` (or `$XDG_CACHE_HOME/omarchy-khmer-clock/`).

## Development

```bash
node --test tests/model.test.js
omarchy plugin validate .
```

## License

MIT
