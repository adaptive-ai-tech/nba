#!/bin/sh
# Removes the NBA Scores user service and its cache. Keeps ~/.config/nba-scores.
set -u
systemctl --user disable --now nba-scores.service 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/nba-scores.service"
rm -rf "$HOME/.local/share/nba-scores" "$HOME/.cache/nba-scores"
systemctl --user daemon-reload
echo "Service removed. Config kept at ~/.config/nba-scores (delete it yourself if you like)."
