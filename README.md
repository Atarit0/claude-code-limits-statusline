# claude-code-limits-statusline

A drop-in `statusLine` script for [Claude Code](https://claude.com/claude-code) that shows your **5-hour** and **7-day** rate-limit usage as two bars — plus a live countdown to each window's reset, and a marker showing how much of the window's *time* has elapsed, so you can tell at a glance whether you're burning quota faster or slower than the clock.

![screenshot of the statusline in a real terminal](screenshot.jpg)

```
Sonnet 5:  7d>0/06:45 76% ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▀  5h>2:32 37% ▄▄▄▄▄▄▄▄▄▄▄▄▀▄▄▄▄▄▄▄▄▄▄▄▄
```

(in a real terminal the bar is colored green → yellow → red as it fills, and the marker cell is genuinely two-tone: white on top, colored background on the bottom — see "How the marker works" below.)

## What it shows

- **`7d>0/06:45`** — bold label + countdown to the 7-day window reset, `days/HH:MM`.
- **`76%`** — percentage of that window's quota used (`used_percentage` from the JSON).
- **the bar** — 25 cells of `▄` (lower-half block), colored green/yellow/red as it fills based on usage%. One cell is replaced by `▀` (upper-half block) in white-on-colored-background: its position marks what **% of the window's time** has already elapsed.
- Same pair of fields for the 5-hour window (`5h>H:MM`).

Comparing the fill (usage) against the single `▀` marker (time) tells you in one glance whether you're ahead of or behind the clock for that window.

## How the marker works

The marker cell prints `▀` with `ESC[97m` (white foreground) and a background color matching whatever segment it lands on (`ESC[42m` green / `ESC[103m` bright yellow / `ESC[41m` red / `ESC[100m` gray). `▀` only fills the top half of the cell in the foreground color, so the top half renders white while the bottom half shows through as the background color — a two-tone cell without needing two characters.

## Install

1. Save `statusline.sh` somewhere, e.g. `~/.claude/statusline.sh`, and make it executable:
   ```bash
   chmod +x ~/.claude/statusline.sh
   ```
2. Point Claude Code at it in `~/.claude/settings.json`:
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "/home/you/.claude/statusline.sh"
     }
   }
   ```
3. Requires `bash` and `jq`. Nothing else.

## Why this exists / where the data comes from

Claude Code's statusLine hook sends a JSON payload on stdin. For Pro/Max subscribers (or behind a gateway with spend limits), it includes `rate_limits.five_hour` and `rate_limits.seven_day`, each with `used_percentage` and `resets_at` (Unix epoch seconds) — this is Claude Code's own documented statusLine schema, read the way it's meant to be read (stdin → your own script → stdout). This script just turns those two numbers per window into something worth glancing at mid-work.

## License

MIT — see [LICENSE](LICENSE). Free to copy, adapt, and reshare.

## Notes

- Not a Claude Code plugin: as of writing, the plugin manifest only lets a plugin set the `agent` and `subagentStatusLine` settings keys, not the main `statusLine` command — so this has to be wired up by hand per the Install steps above, it can't be distributed as an installable plugin.
- If `rate_limits` isn't present in the payload (free tier, or not populated yet on the very first response), the script just prints the model name with no bars — it degrades gracefully instead of erroring out.
