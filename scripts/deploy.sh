#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QUADLET_DIR="$HOME/.config/containers/systemd"
mkdir -p "$QUADLET_DIR"
for f in "$REPO_DIR"/quadlet/*; do
  ln -sf "$f" "$QUADLET_DIR/$(basename "$f")"
done
systemctl --user daemon-reload
systemctl --user restart postiz-pod.service
systemctl --user restart postiz-app.service
tailscale serve --bg --https=4443 http://127.0.0.1:4007
echo "Postiz deployed."
