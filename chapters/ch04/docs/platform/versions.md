# Platform Versions

Tracks the **platform-level** components (Docker base-image level — runtimes, data
stores, message/stream infrastructure, orchestration, observability) that CollabHub
depends on. This file exists so an agent can periodically check each `check_url` for
newer releases and flag security patches and upgrades. Individual libraries and
packages (FastAPI, SQLAlchemy, React, etc.) are **out of scope** — pin and track those
in each service's dependency manifest.

- `last_reviewed`: 2026-07-16   # last automated stack-update-checker run
- `review_cadence`: monthly (or on any upstream CVE advisory)
- Versions are the current stable releases as of `last_reviewed`; see per-entry sources.

## How to use this file (for an update-checking agent)

For each entry in `platforms` below:

1. Fetch `check_url` (authoritative upstream release list).
2. Compare the newest stable release against `last_notified` (the dedup watermark —
   the newest version already announced to the team).
3. If newer: note whether it's a patch/minor/major bump, check `notes` for the
   pinned track, and check the release notes for security fixes.
4. Respect `pinned_track` — only flag upgrades that cross a pinned major/minor as a
   larger decision, not a routine patch.
5. After announcing, set `last_notified` (and usually `current_stable` + `released`)
   to the new version and update the top-level `last_reviewed` date.

The automated check is implemented by the `stack-update-checker` skill
(`.claude/skills/stack-update-checker/`),
which posts to the `#stack-updates` Slack channel and writes `last_notified` back to
this file so the same release is never announced twice.

## platforms

```yaml
- id: python
  name: Python
  category: language-runtime
  used_for: All backend services (Auth, Messaging, Canvas, Asset, Worker) — FastAPI/Uvicorn
  pinned_track: "3.12"           # design docs standardise on Python 3.12
  current_stable: "3.12.13"      # latest patch in the pinned 3.12 series
  last_notified: "3.12.13"   # watermark: last version announced to #stack-updates; skill only alerts when upstream > this
  released: "2026-03-03"
  latest_series: "3.14"          # newest Python series overall; upgrade is a design decision
  base_image_hint: "python:3.12-slim"
  check_url: https://www.python.org/downloads/
  eol_url: https://endoflife.date/python
  notes: >
    Track patch releases within 3.12 for security fixes. 3.12 receives security
    support until ~Oct 2028. Moving to 3.13/3.14 is a deliberate upgrade, not a patch.

- id: postgresql
  name: PostgreSQL
  category: database
  used_for: Primary datastore, one database per service (Auth, Messaging, Canvas, Asset)
  pinned_track: "18"             # not pinned in docs; adopt current major as baseline
  current_stable: "18.4"
  last_notified: "18.4"   # watermark: last version announced to #stack-updates; skill only alerts when upstream > this
  released: "2026-06-04"         # 18.4 / 17.10 / 16.14 / 15.18 / 14.23 release
  base_image_hint: "postgres:18"
  check_url: https://www.postgresql.org/support/versioning/
  eol_url: https://endoflife.date/postgresql
  notes: >
    PostgreSQL 19 is in beta (Beta 1 released 2026-06-04), final expected ~Sep/Oct 2026.
    Apply minor releases promptly — they are the security/bugfix channel.

- id: redis
  name: Redis
  category: cache-and-stream-infra
  used_for: >
    R1 token/denylist cache, R2 Socket.IO real-time backplane, R3 async job Streams
    (consumer groups). Three logical instances, one platform.
  pinned_track: "8"
  current_stable: "8.8.0"
  last_notified: "8.8.0"   # watermark: last version announced to #stack-updates; skill only alerts when upstream > this
  released: "2026-05-25"
  base_image_hint: "redis:8"
  check_url: https://github.com/redis/redis/releases
  eol_url: https://endoflife.date/redis
  notes: >
    Redis provides full support for the latest stable plus maintenance for two prior
    versions. Watch licensing: Redis relicensed away from BSD; Valkey is the OSS fork
    and a drop-in candidate if licence terms matter for on-prem deployment.

- id: elasticsearch
  name: Elasticsearch
  category: search
  used_for: Message (and possibly canvas) full-text search; index lifecycle owned by Worker
  pinned_track: "9"
  current_stable: "9.4.3"
  last_notified: "9.4.3"   # watermark: last version announced to #stack-updates; skill only alerts when upstream > this
  released: "2026-06-30"
  base_image_hint: "docker.elastic.co/elasticsearch/elasticsearch:9.4.3"
  check_url: https://github.com/elastic/elasticsearch/releases
  eol_url: https://endoflife.date/elasticsearch
  notes: >
    8.19 remains supported until 2027-07-15 if a 9.x upgrade must be deferred.
    Check client compatibility (elasticsearch-py) when bumping the server major.

- id: garage
  name: Garage (Deuxfleurs)
  category: object-store
  used_for: S3-compatible object storage for asset uploads and generated variants
  pinned_track: "2"
  current_stable: "2.3.0"
  last_notified: "2.3.0"   # watermark: last version announced to #stack-updates; skill only alerts when upstream > this
  released: "2026-04-16"
  license: AGPL-3.0
  base_image_hint: "dxflrs/garage:v2.3.0"
  check_url: https://git.deuxfleurs.fr/Deuxfleurs/garage/releases
  eol_url: https://garagehq.deuxfleurs.fr/_releases.html
  notes: >
    Chosen over MinIO (2026-07). S3-compatible, so the ObjectStore abstraction is
    unchanged. No breaking changes migrating 2.2.0 -> 2.3.0. AGPLv3 — review licence
    implications for how it's deployed/distributed. Deployment stays flexible: Garage
    self-hosted now, with AWS S3 or Azure Blob as swappable S3-compatible backends
    behind the same interface.

- id: nodejs
  name: Node.js
  category: frontend-build-runtime
  used_for: Frontend SPA build toolchain (React + TypeScript + Vite); CI build image
  pinned_track: "24"             # Active LTS line
  current_stable: "24.x (Active LTS)"
  last_notified: "24.x (Active LTS)"   # watermark: last version announced to #stack-updates; skill only alerts when upstream > this
  released: "2026"
  base_image_hint: "node:24-slim"
  check_url: https://nodejs.org/en/about/previous-releases
  eol_url: https://endoflife.date/nodejs
  notes: >
    Build-time only. Node 24 is Active LTS; Node 22 is in Maintenance LTS; Node 26
    becomes LTS ~Oct 2026. The SPA is served as static files by Nginx (see nginx entry),
    so Node is not in the production runtime path.

- id: nginx
  name: Nginx
  category: web-server
  used_for: Serves the built React/Vite SPA as static files; reverse proxy in front of the SPA
  pinned_track: "1.30"           # stable branch (even minor)
  current_stable: "1.30.3"
  last_notified: "1.30.3"   # watermark: last version announced to #stack-updates; skill only alerts when upstream > this
  released: "2026-06-17"
  base_image_hint: "nginx:1.30-alpine"
  check_url: https://nginx.org/en/download.html
  eol_url: https://endoflife.date/nginx
  notes: >
    Use the stable branch (even second number, e.g. 1.30.x); mainline is 1.31.x.
    Serves static SPA assets and can proxy /api to backend services.

- id: kubernetes
  name: Kubernetes
  category: orchestration
  used_for: Runtime orchestration for all services (on-prem now, Azure later)
  pinned_track: "1.36"
  current_stable: "1.36.2"
  last_notified: "1.36.2"   # watermark: last version announced to #stack-updates; skill only alerts when upstream > this
  released: "2026-06-09"
  base_image_hint: n/a           # cluster/control-plane version, not an app base image
  check_url: https://kubernetes.io/releases/
  eol_url: https://endoflife.date/kubernetes
  notes: >
    N-2 support policy; supported minors are 1.36, 1.35, 1.34. v1.37 expected 2026-08-26.
    Managed clusters (AKS/EKS/GKE) lag upstream — align to the platform's offered versions.

- id: otel-collector
  name: OpenTelemetry Collector
  category: observability
  used_for: Traces/metrics collection (OTLP) across services; runs in docker-compose and cluster
  pinned_track: "0"
  current_stable: "0.156.0"
  last_notified: "0.156.0"   # watermark: last version announced to #stack-updates; skill only alerts when upstream > this
  released: "2026-07-07"
  base_image_hint: "otel/opentelemetry-collector-contrib:0.156.0"
  check_url: https://github.com/open-telemetry/opentelemetry-collector-releases/releases
  eol_url: https://opentelemetry.io/docs/collector/
  notes: >
    Fast release cadence (roughly every 2 weeks). Core stable modules are at 1.x; the
    distribution/release train is tagged 0.x. Use the contrib image if non-core
    receivers/exporters are needed. Exports to the Grafana LGTM backends below (traces
    -> Tempo, logs -> Loki, metrics -> Mimir), viewed in Grafana.

# --- Observability backend: Grafana LGTM stack (chosen over Jaeger, 2026-07) ---

- id: grafana
  name: Grafana
  category: observability-ui
  used_for: Dashboards and query UI over Tempo/Loki/Mimir
  pinned_track: "13"
  current_stable: "13.1.0"
  last_notified: "13.1.0"   # watermark: last version announced to #stack-updates; skill only alerts when upstream > this
  released: "2026-06-23"
  base_image_hint: "grafana/grafana:13.1.0"
  check_url: https://github.com/grafana/grafana/releases
  eol_url: https://endoflife.date/grafana
  notes: "Grafana 13 major line (launched GrafanaCON 2026)."

- id: tempo
  name: Grafana Tempo
  category: observability-traces
  used_for: Distributed tracing backend — replaces Jaeger; receives traces from the OTel Collector
  pinned_track: "2"
  current_stable: "3.0.2"
  last_notified: "3.0.2"   # watermark: last version announced to #stack-updates; skill only alerts when upstream > this
  released: "2026-06-09"
  base_image_hint: "grafana/tempo:2.10.7"
  check_url: https://github.com/grafana/tempo/releases
  eol_url: https://grafana.com/docs/tempo/latest/release-notes/
  notes: >
    Trace backend for the design's tracing requirement (was Jaeger). Tempo 3.0 is a
    new major beyond the pinned 2.x track (announced to #stack-updates 2026-07-16);
    upgrading is a team decision — pinned_track and base image stay on 2.x (2.10.7)
    until decided.

- id: loki
  name: Grafana Loki
  category: observability-logs
  used_for: Log aggregation backend
  pinned_track: "3"
  current_stable: "3.7.3"
  last_notified: "3.7.3"   # watermark: last version announced to #stack-updates; skill only alerts when upstream > this
  released: "2026-06-24"
  base_image_hint: "grafana/loki:3.7.3"
  check_url: https://github.com/grafana/loki/releases
  eol_url: https://endoflife.date/grafana-loki
  notes: "3 versions in active support at any time."

- id: mimir
  name: Grafana Mimir
  category: observability-metrics
  used_for: Long-term Prometheus-compatible metrics storage
  pinned_track: "3"
  current_stable: "3.1.2"
  last_notified: "3.1.2"   # watermark: last version announced to #stack-updates; skill only alerts when upstream > this
  released: "2026-06-24"
  base_image_hint: "grafana/mimir:3.1.2"
  check_url: https://github.com/grafana/mimir/releases
  eol_url: https://grafana.com/docs/mimir/latest/release-notes/
  notes: "3.1.1 bundles a Go 1.26.4 bump addressing multiple CVEs."
```

## Notes on flexibility

- **Object store** — Garage is the self-hosted default. AWS S3 and Azure Blob remain
  swappable backends behind the `ObjectStore` interface; if adopted, track their
  SDK/API compatibility (managed services, no base image to patch).
