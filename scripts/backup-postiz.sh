#!/usr/bin/env bash
set -euo pipefail
DEST="$HOME/backups/postiz"
STAMP="$(date +%Y%m%d-%H%M%S)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$DEST"
podman exec postiz-postgres pg_dump -U postiz -Fc postiz > "$WORK/postiz.dump"
podman volume export postiz-uploads > "$WORK/uploads.tar"
tar -czf "$DEST/postiz-$STAMP.tar.gz" -C "$WORK" postiz.dump uploads.tar
ls -1t "$DEST"/postiz-*.tar.gz | tail -n +8 | xargs -r rm --
echo "$DEST/postiz-$STAMP.tar.gz"
