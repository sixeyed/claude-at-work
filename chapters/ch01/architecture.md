# CollabHub — System Architecture

> Infrastructure-agnostic · Kubernetes-native · .NET 10

---

## Overview

CollabHub is an internal real-time collaboration platform that combines the messaging capabilities of Slack with the collaborative design canvas of Figma into a single unified application. The system enables teams to communicate through channels and threads while simultaneously co-editing visual design documents in real time, with live cursors, presence indicators, and conflict-free concurrent editing powered by CRDTs.

The platform is built as a set of independently deployable .NET 10 microservices, each owning a distinct domain: authentication and identity, messaging, collaborative canvas editing, and asset management. A shared SignalR-based real-time layer provides persistent WebSocket connections across the messaging and canvas services, enabling sub-second updates for chat messages, cursor movements, and design operations. Background processing — search indexing, thumbnail generation, notifications — is handled asynchronously via Redis Streams and a dedicated worker service.

The frontend is a React + TypeScript single-page application (with a React Native or PWA path for mobile) that communicates with backend services over REST for standard operations and SignalR for all real-time interactions. Collaborative editing on the canvas uses the Yjs CRDT library on the client side, with the backend acting as a relay and persistence layer rather than processing merge logic directly.

The architecture is designed to be infrastructure-agnostic from day one. All services are containerised and orchestrated via Kubernetes, with no dependencies on any specific cloud provider. The initial deployment target is on-premises Kubernetes, with a planned migration path to Azure using managed equivalents for each infrastructure component — achievable through configuration changes rather than code changes.

---

## Original Whiteboard Sketch

The initial architecture concept, as sketched during our first whiteboard session:

```mermaid
graph LR
    WEB[Web] -->|request| API[API]
    MOB[Mobile] -->|request| API
    API --> Q[(Queue)]
    Q --> WRK[Worker]
    API --> DB[(DB)]
```

This captured the core request/response flow — clients talking to a central API, with a queue and worker for async processing, and a database for persistence. The full architecture below builds on this foundation, adding the real-time layer, separated service domains, asset storage, search, and observability needed for a collaborative platform.

---

## System Diagram

```mermaid
graph TB
    subgraph Clients
        WEB[Web App<br/>React + TypeScript]
        MOB[Mobile App<br/>React Native / PWA]
    end

    subgraph Backend Services
        MSG[Messaging Service<br/>.NET 10 · SignalR]
        CVS[Canvas Service<br/>.NET 10 · SignalR · Yjs sync]
        AST[Asset Service<br/>.NET 10 · file I/O]
        AUTH[Auth Service<br/>.NET 10 · OpenID / SAML]
        WRK[Worker Service<br/>.NET 10 · background jobs]
    end

    subgraph Redis Instances
        R1[Redis — Cache<br/>sessions · tokens · hot data]
        R2[Redis — Real-time<br/>SignalR backplane · presence · pub/sub]
        R3[Redis — Streams<br/>task queue · notifications · indexing jobs]
    end

    subgraph Data Stores
        PG[(PostgreSQL<br/>users · channels · messages<br/>canvas docs JSONB · permissions)]
        MINIO[(MinIO<br/>images · fonts · exports<br/>avatars · attachments)]
        ES[(Elasticsearch<br/>message search · file search<br/>canvas content · autocomplete)]
    end

    subgraph Observability
        OBS[OpenTelemetry → Prometheus · Grafana · Loki · Jaeger]
    end

    WEB & MOB -->|REST + SignalR| MSG
    WEB & MOB -->|REST + SignalR| CVS
    WEB & MOB -->|REST / presigned URLs| AST
    WEB & MOB -->|REST| AUTH

    AUTH --> R1
    AUTH --> PG

    MSG --> R2
    MSG --> R1
    MSG --> PG
    MSG -->|index jobs| R3

    CVS --> R2
    CVS --> R1
    CVS --> PG

    AST --> MINIO
    AST --> PG
    AST -->|thumbnail jobs| R3

    WRK -->|consume| R3
    WRK --> ES
    WRK --> MINIO
    WRK --> PG

    MSG & CVS & AST & AUTH & WRK -.-> OBS
```

---

## Service Breakdown

### Auth Service
Handles identity via OpenID Connect for internal SSO and optionally SAML for enterprise federation. Issues JWTs consumed by all other services. User profiles and permissions stored in PostgreSQL, session tokens cached in Redis for fast validation.

### Messaging Service
Owns channels, threads, messages, reactions, and read receipts. Exposes REST endpoints for CRUD and a SignalR hub for real-time delivery. Messages persisted to PostgreSQL, then asynchronously indexed into Elasticsearch via Redis Streams.

### Canvas Service
The collaborative design half. Manages documents, layers, and components. Yjs CRDT state syncs between clients via SignalR — the backend relays updates and periodically snapshots document state to PostgreSQL as JSONB. CRDT merge logic lives entirely in the Yjs client library.

### Asset Service
Handles file uploads via presigned MinIO URLs to avoid proxying large blobs. Publishes processing tasks (thumbnails, image optimisation) to Redis Streams for the worker.

### Worker Service
Headless .NET 10 background service consuming jobs from Redis Streams. Handles image thumbnailing (ImageSharp), Elasticsearch index updates, notification dispatch, export jobs, and data retention cleanup. Scales horizontally via KEDA based on queue depth.

---

## Data Flow Examples

### Sending a Chat Message

```mermaid
sequenceDiagram
    participant C as Client
    participant M as Messaging Svc
    participant PG as PostgreSQL
    participant R2 as Redis (Real-time)
    participant R3 as Redis (Streams)
    participant W as Worker
    participant ES as Elasticsearch

    C->>M: Send message (SignalR)
    M->>PG: Persist message
    M->>R2: Publish to channel (pub/sub)
    R2-->>C: Broadcast to members
    M->>R3: Enqueue index job
    W->>R3: Consume job
    W->>ES: Index message
```

### Collaborative Canvas Edit

```mermaid
sequenceDiagram
    participant A as Client A (Yjs)
    participant S as Canvas Svc
    participant R2 as Redis (Real-time)
    participant B as Client B (Yjs)
    participant PG as PostgreSQL

    A->>S: Yjs update (SignalR)
    S->>R2: Relay via backplane
    R2-->>S: Fan out
    S-->>B: Yjs update (SignalR)
    Note over S,PG: Periodic snapshot
    S->>PG: Persist Yjs doc state (JSONB)
```

### File Upload

```mermaid
sequenceDiagram
    participant C as Client
    participant A as Asset Svc
    participant MI as MinIO
    participant PG as PostgreSQL
    participant R3 as Redis (Streams)
    participant W as Worker

    C->>A: Request upload URL
    A->>MI: Generate presigned URL
    A-->>C: Return presigned URL
    C->>MI: Upload file directly
    C->>A: Confirm upload
    A->>PG: Save metadata
    A->>R3: Enqueue thumbnail job
    W->>R3: Consume job
    W->>MI: Store thumbnail
```

---

## Tech Stack Summary

| Layer | Technology | Rationale |
|---|---|---|
| Frontend | React + TypeScript | Rich ecosystem for canvas + chat UIs |
| Real-time CRDT | Yjs | Best-in-class CRDT library, strong community |
| Backend Services | .NET 10 (ASP.NET Core) | Team expertise, performance, SignalR built-in |
| Real-time Transport | SignalR | Native .NET, WebSocket with fallbacks |
| Primary Database | PostgreSQL | JSONB for canvas docs, strong .NET support, free |
| Cache / RT / Queue | Redis (3× independent) | Isolated failure domains, simple ops |
| Object Storage | MinIO | S3-compatible, runs anywhere |
| Search | Elasticsearch | Full-text across messages, files, canvas content |
| Observability | OTel + Prometheus + Grafana + Loki + Jaeger | K8s-native, open-source |
| Orchestration | Kubernetes | Portable across on-prem and cloud |

---

## Infrastructure

### Approach

The system is designed around a two-phase deployment strategy. Phase one is on-premises Kubernetes — all infrastructure components (PostgreSQL, Redis, MinIO, Elasticsearch) run as workloads within the cluster, managed via Helm charts or operators. This gives the team full control during initial development and early adoption, with no cloud spend or external dependencies.

Phase two is a migration to Azure, replacing self-hosted infrastructure with managed equivalents: Azure Database for PostgreSQL, Azure Cache for Redis, Azure Blob Storage, and Elastic Cloud or Azure AI Search. Because every service reads its configuration from environment variables and Kubernetes ConfigMaps/Secrets, this migration is a configuration change — connection strings, endpoints, and credentials — rather than a code change. The application layer remains untouched.

All container images are built once and run identically in both environments. No cloud-specific SDKs are used in the application code where an infrastructure-agnostic alternative exists (e.g. S3-compatible API for object storage rather than the Azure Blob SDK directly).

### Infrastructure Portability

| Concern | On-Prem (K8s) | Azure (future) |
|---|---|---|
| Object Storage | MinIO | Azure Blob (S3-compat or SDK swap) |
| Database | PostgreSQL on K8s | Azure Database for PostgreSQL |
| Redis | 3× standalone on K8s | 3× Azure Cache for Redis |
| Search | Self-hosted Elasticsearch | Elastic Cloud or Azure AI Search |
| Secrets | Sealed Secrets / Vault | Azure Key Vault + CSI driver |
| CI/CD | GitLab CI / GitHub Actions | Same, or Azure DevOps |

### Redis Instance Strategy

Three independent Redis instances, each with a single concern:

| Instance | Purpose | Failure Impact |
|---|---|---|
| Cache | Sessions, tokens, hot data | Users may need to re-auth; slightly slower reads |
| Real-time | SignalR backplane, presence, pub/sub | Real-time updates pause; clients reconnect automatically |
| Streams | Task queue for async work | Background jobs queue on restart; no user-facing impact |

This avoids a single Redis failure taking down everything, and lets you size and tune each instance independently. No Sentinel or Cluster overhead to start — just three standalone instances with periodic RDB snapshots for durability.
