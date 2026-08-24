# NOTICE — Herkunft, Lizenz und Aenderungen

## Upstream

Dieses Repository enthaelt unter `upstream/` einen unveraenderten Teilbaum des
Projekts **IFC-Lite**:

| Feld | Wert |
|---|---|
| Projekt | IFC-Lite |
| Quelle | https://github.com/LTplus-AG/ifc-lite |
| Doku | https://ifclite.dev |
| Lizenz | Mozilla Public License 2.0 (MPL-2.0) |
| Vendorierter Commit | `329bf8c70809eb8a41d3a8751334d681416aadec` |
| Commit-Datum | 2026-08-24 |
| Branch | `main` |
| Cargo-Workspace-Version | `5.0.0` |
| Beschafft am | 2026-08-24 |
| Beschafft per | `git clone --filter=blob:none --sparse` + `git sparse-checkout set Cargo.toml rust apps/server .cargo` |

Vendorierte Pfade (Teilmenge des Upstream-Repos, nur was der Cargo-Build des
Server-Crates braucht):

```
upstream/.cargo/config.toml
upstream/Cargo.toml
upstream/Cargo.lock
upstream/rust-toolchain.toml
upstream/rust/**            (alle Rust-Crates des Workspace)
upstream/apps/server/**     (Crate ifc-lite-server inkl. Dockerfile)
upstream/LICENSE
upstream/LICENSE_HEADER.md
```

Bewusst NICHT vendoriert: die TypeScript-/pnpm-Teile des Monorepos
(`packages/`, `apps/viewer`, `tests/`, Doku, Lockfiles der JS-Toolchain).
Sie werden fuer `cargo build --package ifc-lite-server` nicht gebraucht.
Der vollstaendige Quellcode ist jederzeit unter der oben genannten URL und
dem oben genannten Commit abrufbar.

## Unsere Aenderungen an MPL-lizenzierten Dateien

**Keine.** Es wurde keine einzige Datei unter `upstream/` inhaltlich veraendert.
Es wurden lediglich Dateien *weggelassen* (siehe oben) — das ist keine
Modifikation im Sinne von MPL-2.0 §1.10.

## Unsere Zusatzdateien (Build-/Deploy-Glue)

Alles ausserhalb von `upstream/` ist neu und stammt nicht vom Upstream:

| Datei | Zweck |
|---|---|
| `.github/workflows/build-image.yml` | baut das Container-Image und pusht es nach GHCR |
| `deploy/docker-compose.yml` | Beispiel-Stack fuer Unraid (Dockge / Compose Manager Plus) |
| `README.md`, `NOTICE.md` | Doku, Herkunftsnachweis |
| `.gitignore`, `.gitattributes` | Repo-Hygiene |
| `scripts/update-upstream.sh` | vendorierten Baum auf einen neuen Upstream-Commit heben |
| `LICENSE` | Kopie der Upstream-MPL-2.0 (unveraendert) |

Diese Zusatzdateien sind reine Build-/Deploy-Konfiguration und enthalten keinen
Code aus MPL-lizenzierten Dateien. Sie stehen unter derselben Lizenz (MPL-2.0),
damit das Gesamtrepo einheitlich bleibt.

## Was MPL-2.0 hier bedeutet

- MPL-2.0 ist file-basiertes Copyleft: nur *veraenderte* MPL-Dateien muessen im
  Quellcode weitergegeben werden. Da wir nichts veraendern, entsteht keine
  zusaetzliche Pflicht ueber die Weitergabe dieses Repos hinaus.
- Die Lizenzdatei und die Copyright-/Lizenzheader in den Quelldateien bleiben
  erhalten (`upstream/LICENSE`, Header in jeder `.rs`-Datei).
- Das gebaute Container-Image enthaelt kompilierten MPL-Code. Wer das Image
  bekommt, muss den Quellcode erhalten koennen — dafuer reicht der Verweis auf
  dieses Repo bzw. auf den oben genannten Upstream-Commit. Das Image traegt
  darum das Label `org.opencontainers.image.source`.
