# CollabHub — Asset Service

> File uploads, downloads, and metadata via presigned object-storage URLs.
> Read [Platform Conventions](./00-platform-conventions.md) first.

**Status:** Draft · **Runtime:** .NET 10 / ASP.NET Core
**Owns:** asset metadata, presigned URL issuance, bucket layout
**Depends on:** PostgreSQL (own DB), MinIO (S3-compatible), Redis Streams (R3)

---

## 1. Purpose & Responsibilities

Handles all binary assets — images, fonts, exports, avatars, attachments. The defining design
choice: **large blobs never transit the service**. Clients upload and download **directly to
MinIO using presigned URLs**; the service only issues URLs and tracks metadata.

**Owns:** asset metadata (owner, type, size, status), presigned URL generation, bucket/key
layout, post-upload confirmation, enqueuing processing jobs.
**Produces:** thumbnail/optimisation jobs to `jobs:thumbnail` (R3), consumed by the Worker.
**Does NOT own:** actual image processing (Worker does it), referencing logic (Messaging/Canvas
store asset IDs and decide what an asset belongs to).

---

## 2. Runtime & Dependencies
- ASP.NET Core REST only (no SignalR).
- S3-compatible client (`AWSSDK.S3` pointed at MinIO, or `Minio` .NET SDK) **behind an
  `IObjectStore` interface** so MinIO ↔ Azure Blob is a config/implementation swap, not a code
  change (Conventions §8).
- EF Core + Npgsql.
- StackExchange.Redis for R3.

---

## 3. Public Interface (REST `/api/v1`)

The upload is a three-step handshake so the blob goes client → MinIO directly.

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/assets/upload-url` | member | Reserve an asset; return presigned **PUT** URL + asset id. |
| POST | `/assets/{id}/confirm` | owner | Mark upload complete; validate object exists; enqueue processing. |
| GET | `/assets/{id}` | viewer | Metadata (type, size, status, variants). |
| GET | `/assets/{id}/download-url` | viewer | Presigned **GET** URL (time-limited). |
| GET | `/assets/{id}/thumbnail-url?size=` | viewer | Presigned GET for a generated variant. |
| DELETE | `/assets/{id}` | owner | Soft-delete metadata; schedule blob deletion via retention job. |

`POST /assets/upload-url`
```json
// request
{ "fileName": "logo.png", "contentType": "image/png", "sizeBytes": 482113, "purpose": "attachment" }
// response
{
  "assetId": "uuid",
  "uploadUrl": "https://minio/collabhub-uploads/...&X-Amz-Signature=...",
  "method": "PUT",
  "headers": { "Content-Type": "image/png" },
  "expiresAt": "2026-06-03T10:20:00Z"
}
```

Flow (matches the architecture sequence): client requests URL → uploads bytes straight to
MinIO → calls `confirm` → service verifies the object, writes metadata, enqueues a thumbnail
job. Until confirmed, the asset is `status = 'pending'` and not downloadable.

---

## 4. Data Model (PostgreSQL)

```sql
CREATE TABLE assets (
    id            uuid PRIMARY KEY,
    workspace_id  uuid NOT NULL,
    owner_id      uuid NOT NULL,
    file_name     text NOT NULL,
    content_type  text NOT NULL,
    size_bytes    bigint NOT NULL,
    purpose       text NOT NULL,            -- avatar | attachment | font | export | canvas-image
    bucket        text NOT NULL,
    object_key    text NOT NULL,            -- e.g. {workspace}/{purpose}/{assetId}/{fileName}
    status        text NOT NULL DEFAULT 'pending',  -- pending | ready | failed | deleted
    checksum      text NULL,                -- ETag / sha256 after confirm
    created_at    timestamptz NOT NULL DEFAULT now(),
    confirmed_at  timestamptz NULL,
    deleted_at    timestamptz NULL,
    UNIQUE (bucket, object_key)
);

-- Generated variants (thumbnails, optimised renditions) produced by the Worker.
CREATE TABLE asset_variants (
    id            uuid PRIMARY KEY,
    asset_id      uuid NOT NULL REFERENCES assets(id),
    kind          text NOT NULL,            -- thumb-128 | thumb-512 | webp | ...
    object_key    text NOT NULL,
    size_bytes    bigint NOT NULL,
    created_at    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (asset_id, kind)
);
```

### 4.1 MinIO layout
- Bucket `collabhub-assets` (or per-purpose buckets). Object key
  `{workspaceId}/{purpose}/{assetId}/{fileName}`. Variants under
  `{...}/{assetId}/variants/{kind}`.
- Presigned PUT/GET expiry short (e.g. 15 min). Enforce `Content-Type` and a max size via the
  presigned policy where the backend supports it.

### 4.2 Redis usage
- **R3:** `jobs:thumbnail` — `{ assetId, objectKey, variants: ["thumb-128","thumb-512"] }`
  enqueued on confirm. Worker stores variants back in MinIO and inserts `asset_variants` rows
  (or calls back via an internal endpoint — see Open Decisions).

---

## 5. Internal Design — Upload & Process
1. `POST /assets/upload-url`: insert `assets` row (`pending`), generate presigned PUT, return.
2. Client `PUT`s bytes directly to MinIO.
3. `POST /assets/{id}/confirm`: HEAD the object to confirm existence/size/ETag, set
   `status='ready'`, `confirmed_at`, `checksum`.
4. `XADD jobs:thumbnail` with the variants to generate.
5. Worker consumes, generates variants (ImageSharp), stores them in MinIO, records
   `asset_variants`.

Orphan cleanup: `pending` assets older than a TTL (no confirm) are swept by a retention job
(Worker) which deletes both the row and any stray object.

---

## 6. Configuration
Common vars (Conventions §8). Plus:

| Var | Notes |
|-----|-------|
| `ObjectStore__Endpoint` | MinIO endpoint (or Azure Blob S3 endpoint). |
| `ObjectStore__AccessKey` / `__SecretKey` | Secret. |
| `ObjectStore__Bucket` | Default bucket. |
| `ObjectStore__PresignTtlSeconds` | Default 900. |
| `Asset__MaxUploadBytes` | e.g. 50 MB (per purpose overrides). |
| `Asset__AllowedContentTypes` | Allow-list per purpose. |

## 7. Cross-Cutting
Auth, errors, health, observability per Conventions. Metrics: `assets_uploaded_total`,
`asset_bytes_total`, `presign_issued_total{kind}`.

## 8. Non-Functional & Limits
- Service never streams blob bodies (memory-flat regardless of file size).
- Max upload size per purpose; content-type allow-list; virus-scan hook optional (Open Decision).
- Download URLs are short-lived and per-request; no public buckets.

## 9. Open Decisions
- **Worker → variants callback:** Worker writes `asset_variants` directly to this service's DB
  (breaks the no-shared-DB rule) vs. calls an internal `POST /assets/{id}/variants` endpoint
  (preferred) vs. emits an event the Asset service consumes. Recommend an internal endpoint.
- Whether avatars/exports use the same bucket or dedicated buckets.
- Virus/malware scanning of uploads before marking `ready`.
- Direct Azure Blob SDK vs. S3-compat layer for the Azure phase (Conventions favours S3-compat).
