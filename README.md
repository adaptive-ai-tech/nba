# NBA Scores for Omarchy

Live NBA scores in the Omarchy (Quattro) bar, by [Adaptive AI Technologies](https://adaptiveai.in).
Free for everyone, no account or login needed.

<!-- Screenshot: add preview.png (bar + open dropdown) here -->
<!-- ![NBA Scores](preview.png) -->

## How it works
- A small Python fetcher runs as a **systemd `--user` service** and polls the public NBA CDN
  (today's scoreboard, per-game box scores, season schedule). It writes `~/.cache/nba-scores/scores.json`.
- The bar widget only reads that local file, so the shell never waits on the network.
- Polls every 30 s while games are live and every 10 min otherwise. Times use your system time zone.

## Install
```sh
omarchy plugin add https://github.com/adaptive-ai-tech/nba.git --enable
~/.config/omarchy/plugins/io.github.adaptive-ai-tech.nba/install.sh   # starts the user service, no sudo
```
Optional: `omarchy bar move io.github.adaptive-ai-tech.nba --section right`

Requires `python3`, `systemd --user`, and `chromium` (or Omarchy's `omarchy-launch-webapp`) for game pages.

## Usage
- **Bar:** rotates live scores (`LAL 102–98 BOS Q4 3:12`), otherwise the next tip-off, otherwise `No games`.
- **Click the widget:** a dropdown under the bar lists today's games with score, clock/status and start time.
- **Click a game:** opens its live page, `https://www.nba.com/game/<gameId>`, in an app window.
- **▸ next to a game:** top three scorers per team. **Escape** closes the dropdown.
- Video: NBA League Pass is Widevine DRM, so it only plays in the browser window (signed in there).
  This plugin does not stream or bypass anything.

## Configure
`~/.config/nba-scores/config.json` (created on first run):
```json
{
  "favourites": ["LAL", "GSW"],
  "notify": true,
  "liveInterval": 30,
  "idleInterval": 600,
  "scheduleHours": 12,
  "donateUrl": "upi://pay?..."
}
```
- `favourites`: team tricodes that get a desktop notification (`notify-send`) at tip-off and at the final.
- `donateUrl`: payment link behind "Open in UPI app" under **♥ Support** (defaults to the maintainer's UPI link; set `""` to hide that link).

Logs: `journalctl --user -u nba-scores -f`

## Privacy
No telemetry, no analytics, no accounts. The only network calls are HTTPS GETs for NBA's public JSON files: `cdn.nba.com`, falling back
to NBA's own origin `nba-prod-us-east-1-mediaops-stats.s3.amazonaws.com` where the CDN returns 403.
They are made by the local fetcher. Nothing is sent anywhere else.

## Remove
```sh
~/.config/omarchy/plugins/io.github.adaptive-ai-tech.nba/uninstall.sh   # stops service, deletes cache
omarchy plugin remove io.github.adaptive-ai-tech.nba
rm -rf ~/.config/nba-scores   # optional: your settings
```

## Support / Donate
NBA Scores is free for everyone, with no login. Donations are entirely optional.
If you'd like to support development by [Adaptive AI Technologies](https://adaptiveai.in), scan this
UPI QR (also shown from **♥ Support** in the dropdown footer):

<img src="assets/donate-qr.jpg" alt="UPI donation QR" width="240">

UPI ID: `9629734560@hdfc`

## License
MIT © Adaptive AI Technologies. Not affiliated with the NBA. Team names and data belong to their owners.
