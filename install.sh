#!/bin/sh
# Installs the NBA Scores fetcher as a systemd --user service. No sudo, user scope only.
set -eu
[ "$(id -u)" -eq 0 ] && { echo "Run as your normal user, not root." >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required." >&2; exit 1; }
D=$(cd "$(dirname "$0")" && pwd)
install -Dm755 "$D/fetcher/nba-scores-fetch.py" "$HOME/.local/share/nba-scores/nba-scores-fetch.py"
install -Dm644 "$D/fetcher/nba-scores.service" "$HOME/.config/systemd/user/nba-scores.service"
systemctl --user daemon-reload
systemctl --user enable --now nba-scores.service
echo "nba-scores.service enabled. Cache: ~/.cache/nba-scores/scores.json"
