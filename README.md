# ifc-lite-server (Trassia-Build)

Eigener Container-Build des **IFC-Lite-Servers** (Rust, MPL-2.0) als Backend fuer den
Trassia-IFC-Viewer. Er uebernimmt das Parsen und Meshen grosser IFC-Modelle, damit der
Browser nicht alles selbst rechnen muss (Briefing §5: "optionaler Server-Container, erst
wenn Browser-Parsing bei grossen Modellen zu langsam wird").

## Warum dieses Repo ueberhaupt existiert

Das Briefing nennt `ghcr.io/ltplus-ag/ifc-lite-server` als fertiges Image. Dieses Package
ist jedoch **nicht oeffentlich** — ein anonymer Pull liefert `401 Unauthorized` (geprueft
am 2026-08-24). Der Quellcode ist offen (MPL-2.0), also bauen wir das Image selbst:

- `upstream/` = unveraenderter Teilbaum von `LTplus-AG/ifc-lite`
  (Commit `329bf8c7`, Version 5.0.0) — siehe [NOTICE.md](NOTICE.md)
- alles andere = unser Build-/Deploy-Glue

Es wurde **keine** Upstream-Datei veraendert. Damit entstehen aus MPL-2.0 keine weiteren
Pflichten als die Weitergabe dieses Repos bzw. der Verweis auf den Upstream-Commit.

## Build-Weg

Lokal wird **nicht** gebaut (auf der Arbeitsmaschine ist kein Docker installiert).
Gebaut wird in GitHub Actions:

```
Push auf main
  -> .github/workflows/build-image.yml
  -> docker/build-push-action (Kontext: upstream/, Dockerfile: upstream/apps/server/Dockerfile)
  -> ghcr.io/salathem/ifc-lite-server:latest
     ghcr.io/salathem/ifc-lite-server:sha-<kurzer-commit>
```

Eckdaten des Builds:

- Mehrstufig (`cargo-chef` -> `rust:1.97-bookworm` Builder -> `debian:bookworm-slim`
  Runtime), non-root User `appuser` (UID 1000), `EXPOSE 8080`, Healthcheck auf
  `/api/v1/health`. Das Dockerfile stammt unveraendert vom Upstream.
- Nur `linux/amd64` (Unraid). arm64 waere per QEMU moeglich, verdoppelt aber die Bauzeit.
- Cache: Buildx-Layer-Cache in der GitHub-Actions-Cache-Backend (`type=gha,mode=max`).
  Damit bleibt die teure `cargo chef cook`-Stage (alle Crates vorkompiliert) zwischen
  Builds erhalten. `actions/cache` auf `~/.cargo` waere wirkungslos, weil cargo im
  Container laeuft und dessen `CARGO_HOME` nie auf dem Runner liegt.
- Der erste (kalte) Build kompiliert den ganzen Rust-Workspace und dauert entsprechend
  lange (Groessenordnung 30-90 Minuten auf einem Standard-Runner). Danach Minuten.

Rechte im Workflow: `contents: read`, `packages: write`; Login mit dem
automatischen `GITHUB_TOKEN`, keine zusaetzlichen Secrets noetig.

### Lokal bauen (falls doch mal eine Docker-Maschine da ist)

```bash
docker build -f upstream/apps/server/Dockerfile -t ifc-lite-server:local upstream
```

Der Build-Kontext ist `upstream/` (nicht das Repo-Root), weil das Dockerfile
`COPY . .` macht und den Cargo-Workspace-Root oben erwartet.

## Nach dem ersten erfolgreichen Build: Package sichtbar machen

Ein per `GITHUB_TOKEN` gepushtes GHCR-Package ist zunaechst **privat**. Zwei Wege:

1. **Package auf "public" stellen** (einfachster Weg): GitHub -> Profil -> Packages ->
   `ifc-lite-server` -> Package settings -> Change visibility -> Public.
   Danach zieht Unraid ohne jedes Credential.
2. **Privat lassen und auf Unraid einloggen**: GitHub-Token mit ausschliesslich
   `read:packages`, dann auf dem Server `docker login ghcr.io`. Das ist der in
   `website/docs/VIEWER-UNRAID.md` (Schritt 4) bereits vorgesehene Weg — dort liegt
   ohnehin schon ein solches Token fuer den Viewer.

Ausserdem im Package unter "Package settings" das Repository verknuepfen, damit die
Herkunft sichtbar bleibt (das Image traegt dafuer bereits
`org.opencontainers.image.source`).

## Deployment auf Unraid

Kontext und Grundeinrichtung: **`website/docs/VIEWER-UNRAID.md`**. Der Server ist dort
unter "Bewusst NICHT in diesem Pfad" als spaeterer zweiter Container im selben Stack
vorgesehen — genau das ist dieses Image.

Fertiger Compose-Ausschnitt: [`deploy/docker-compose.yml`](deploy/docker-compose.yml).
Kurzfassung:

- Netz `trassia` (extern), **kein** Portmapping.
- Erreichbarkeit ueber den bestehenden Cloudflare-Tunnel, z. B. Public Hostname
  `ifc-api.trassia.com` -> `http://trassia-ifc-server:8080`.
- `CORS_ORIGINS` muss auf die Viewer-Origin gesetzt werden
  (Default sind nur localhost-Dev-Origins, der Browser blockt sonst).
- Cache als Docker-Volume auf `/app/cache` (Caching per SHA-256 des Dateiinhalts;
  der Client prueft den Cache vor dem Upload).
- Memory-Limit setzen: der Server leitet daraus (cgroup) sein Admission-Budget ab.

**Kein Deployment ohne Freigabe von Marco** (Briefing §11 / Agentregel 2).

## Konfiguration (Environment)

Defaults kommen aus dem Dockerfile bzw. `upstream/apps/server/src/config.rs`.

| Variable | Default | Bedeutung |
|---|---|---|
| `PORT` | `8080` | Listen-Port |
| `RUST_LOG` | `info` | Log-Level (`tracing-subscriber`, env-filter) |
| `MAX_FILE_SIZE_MB` | `500` | maximale Uploadgroesse |
| `WORKER_THREADS` | `4` (Image) / Kernanzahl (Code) | Worker-Threads, zugleich Default fuer die Parallelitaet der Admission-Control |
| `CACHE_DIR` | `/app/cache` | Cache-Verzeichnis (Volume!) |
| `CACHE_MAX_AGE_DAYS` | `7` | Aufbewahrung im Cache |
| `REQUEST_TIMEOUT_SECS` | `300` | Request-Timeout |
| `CORS_ORIGINS` | localhost-Dev-Origins | kommaseparierte erlaubte Origins — **produktiv setzen** |
| `IFC_SERVER_API_TOKEN` / `API_TOKEN` | leer | Bearer-Token; ohne Token ist die API offen |
| `IFC_MEM_BUDGET_MB` | 70% des cgroup-/RAM-Limits | Speicherbudget der Admission-Control, `0` = aus |
| `IFC_MAX_CONCURRENT_PARSES` | `WORKER_THREADS` | gleichzeitige Parse-Jobs |
| `IFC_ADMISSION_QUEUE_DEPTH` | `2 * WORKER_THREADS` | Warteschlange vor `503` |
| `IFC_ADMISSION_QUEUE_TIMEOUT_SECS` | `5` | maximale Wartezeit in der Schlange |
| `IFC_MEM_SHED_PCT` | `85` | RSS-Prozentsatz, ab dem abgewiesen wird |
| `IFC_METRICS_ENABLED` | aus | `GET /api/v1/metrics` (Prometheus) |
| `INITIAL_BATCH_SIZE` / `MAX_BATCH_SIZE` | `100` / `1000` | Streaming-Batchgroessen |

Endpunkte (Auswahl): `/api/v1/health` (Liveness), `/api/v1/ready` (Readiness),
`/api/v1/metrics`, Parse-Routen unter `/api/v1/parse*`.
Details: `upstream/apps/server/OPERATIONS.md`.

## Quellstruktur

```
ifc-lite-server/
├─ .github/workflows/build-image.yml   Build + Push nach GHCR
├─ deploy/docker-compose.yml           Unraid-Stack (Beispiel)
├─ scripts/update-upstream.sh          Upstream-Teilbaum aktualisieren
├─ LICENSE  NOTICE.md  README.md
└─ upstream/                           unveraenderter Upstream-Teilbaum
   ├─ Cargo.toml                       Workspace-Root (members: rust/*, apps/server)
   ├─ Cargo.lock                       gepinnte Abhaengigkeiten
   ├─ rust-toolchain.toml              nightly-2025-11-15 (Upstream-Pin)
   ├─ .cargo/config.toml               nur wasm32-Flags, fuer den Server irrelevant
   ├─ rust/                            core, geometry, processing, clash, export,
   │                                   ffi, wasm-bindings (+ python, csg-thread-bench)
   └─ apps/server/                     Crate `ifc-lite-server`
      ├─ Cargo.toml                    axum 0.8, tokio, rayon, arrow/parquet 59,
      │                                cacache, mimalloc; Pfad-Deps auf rust/*
      ├─ Dockerfile                    Multi-Stage (cargo-chef), non-root, EXPOSE 8080
      ├─ OPERATIONS.md                 Betriebsdoku (Admission-Control, Speicher)
      └─ src/                          main.rs, config.rs, routes/, services/, middleware/
```

Gebaut wird das Profil `server-release` (`panic = "unwind"`, damit ein Panic beim
Parsen fremder IFC-Bytes zu einem HTTP 500 wird statt den Prozess zu killen).

## Lizenz

MPL-2.0, wie der Upstream. Siehe [LICENSE](LICENSE) und [NOTICE.md](NOTICE.md).
