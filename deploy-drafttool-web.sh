#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$ROOT_DIR"

flutter build web --release --pwa-strategy=none

rm -rf "$ROOT_DIR/build/web/api"
mkdir -p "$ROOT_DIR/build/web/api"
cp "$ROOT_DIR/api/tournament-ticket.js" "$ROOT_DIR/build/web/api/tournament-ticket.js"
cp "$ROOT_DIR/api/_firebase.js" "$ROOT_DIR/build/web/api/_firebase.js"
cp "$ROOT_DIR/api/_tournament_tickets.js" "$ROOT_DIR/build/web/api/_tournament_tickets.js"
cp "$ROOT_DIR/package.json" "$ROOT_DIR/build/web/package.json"
cp "$ROOT_DIR/package-lock.json" "$ROOT_DIR/build/web/package-lock.json"
cp "$ROOT_DIR/vercel.json" "$ROOT_DIR/build/web/vercel.json"

echo "DraftTool web build is ready in build/web."
echo "Deploy build/web to the standalone Vercel project for makepair.pokoin.com."
