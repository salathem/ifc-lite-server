#!/usr/bin/env bash
# Hebt den vendorierten Upstream-Teilbaum unter upstream/ auf einen neuen
# Commit von LTplus-AG/ifc-lite. Danach NOTICE.md (Commit/Datum/Version)
# nachfuehren und committen.
#
#   ./scripts/update-upstream.sh <commit-oder-tag>
#
# Braucht git. Laeuft auf Linux/macOS und in Git Bash unter Windows.
set -euo pipefail

REF="${1:-main}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Hole LTplus-AG/ifc-lite @ ${REF} ..."
# core.eol=lf ist zwingend: der Upstream setzt `* text=auto`, unter Windows
# landen sonst CRLF-Zeilen im Dockerfile.
git -c core.autocrlf=false -c core.eol=lf clone --filter=blob:none --no-checkout \
    https://github.com/LTplus-AG/ifc-lite.git "$TMP/src"
cd "$TMP/src"
git config core.autocrlf false
git config core.eol lf
git sparse-checkout init --cone
git sparse-checkout set Cargo.toml rust apps/server .cargo
git checkout "$REF"
SHA="$(git rev-parse HEAD)"
DATE="$(git log -1 --date=short --format=%ad)"

echo "Ersetze upstream/ ..."
rm -rf "$REPO_ROOT/upstream"
mkdir -p "$REPO_ROOT/upstream/apps"
cp -r .cargo Cargo.toml Cargo.lock rust-toolchain.toml rust LICENSE LICENSE_HEADER.md "$REPO_ROOT/upstream/"
cp -r apps/server "$REPO_ROOT/upstream/apps/"

echo
echo "Fertig. Vendorierter Commit: $SHA ($DATE)"
echo "Jetzt NOTICE.md aktualisieren und committen."
