# CollabHub — Auth Service

> Identity, token issuance, and authorization source of truth.
> Read [Platform Conventions](./00-platform-conventions.md) first.

**Status:** Draft · **Runtime:** Python 3.12 / FastAPI (Uvicorn)
**Owns:** users, external identities, roles, workspace membership, tokens
**Depends on:** PostgreSQL (own DB), Redis Cache (R1)

---

## 1. Purpose & Responsibilities

The Auth Service is the identity provider and authorization source of truth for CollabHub.

**Owns:**
- User accounts and profiles.
- Federation with external identity providers via **OpenID Connect** (internal SSO) and
  optionally **SAML 2.0** (enterprise federation).
- Issuance, refresh, and revocation of CollabHub access/refresh tokens (JWTs).
- The JWKS endpoint that all other services use to verify tokens.
- Workspace membership and workspace-level roles (`owner`/`admin`/`member`/`guest`).

**Does NOT own:**
- Per-resource permissions (each service owns its own — see Conventions §5.3).
- Sessions for real-time connections (services validate tokens themselves).

---

## 2. Runtime & Dependencies

- FastAPI routers (Uvicorn ASGI server).
- **Authlib** for the OpenID Connect client flow; **python3-saml** (or equivalent) for SAML.
- **PyJWT** (or Authlib's JWT support) for RS256 signing and JWKS generation
  (`cryptography` provides the underlying RSA primitives).
- SQLAlchemy 2.0 (async) + asyncpg for PostgreSQL; Alembic for migrations.
- `redis-py` (`redis.asyncio`) for the R1 denylist + token cache.
- Signing keys: RSA key pair stored as a secret; supports key rotation (multiple `kid`s,
  one active for signing, several valid for verification).

---

## 3. Public Interface (REST)

Base path `/api/v1`. Token endpoints and JWKS are unauthenticated; all others require Bearer.

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/.well-known/jwks.json` | none | Public verification keys (JWKS). |
| GET | `/.well-known/openid-configuration` | none | OIDC discovery (if acting as OP). |
| GET | `/auth/login/{provider}` | none | Begin external OIDC/SAML login (redirect). |
| GET | `/auth/callback/{provider}` | none | Provider callback; establishes identity, redirects to SPA with auth code. |
| POST | `/auth/token` | none | Exchange auth code (PKCE) for access + refresh tokens. |
| POST | `/auth/refresh` | none | Rotate refresh token → new access + refresh. |
| POST | `/auth/logout` | Bearer | Revoke current token's `jti` + refresh token. |
| GET | `/auth/userinfo` | Bearer | Claims for the current token. |
| GET | `/users/me` | Bearer | Current user profile. |
| PATCH | `/users/me` | Bearer | Update own profile (display name, avatar ref). |
| GET | `/users/{id}` | Bearer | Public profile of a user (name, avatar). |
| GET | `/workspaces/{id}/members` | Bearer (member) | List members + roles. |
| POST | `/workspaces/{id}/members` | Bearer (admin) | Invite/add member. |
| PATCH | `/workspaces/{id}/members/{userId}` | Bearer (admin) | Change role. |
| DELETE | `/workspaces/{id}/members/{userId}` | Bearer (admin) | Remove member. |

### 3.1 Token endpoint payloads

`POST /auth/token`
```json
// request
{ "grant_type": "authorization_code", "code": "...", "code_verifier": "..." }
// response
{ "access_token": "ey...", "refresh_token": "def...", "token_type": "Bearer", "expires_in": 900 }
```

`POST /auth/refresh`
```json
// request
{ "refresh_token": "def..." }
// response — same shape as /auth/token; old refresh_token is now invalid (rotation)
```

Access-token claims follow Conventions §5.1. The Auth Service is the only issuer.

---

## 4. Data Model (PostgreSQL)

```sql
CREATE TABLE users (
    id            uuid PRIMARY KEY,
    email         citext NOT NULL UNIQUE,
    display_name  text NOT NULL,
    avatar_asset  uuid NULL,                 -- references Asset service id (no FK, cross-service)
    status        text NOT NULL DEFAULT 'active',  -- active | suspended | deactivated
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    deleted_at    timestamptz NULL,
    version       integer NOT NULL DEFAULT 0
);

-- Links a user to an external IdP identity (one row per provider).
CREATE TABLE external_identities (
    id            uuid PRIMARY KEY,
    user_id       uuid NOT NULL REFERENCES users(id),
    provider      text NOT NULL,             -- 'oidc:acme' | 'saml:corp'
    subject       text NOT NULL,             -- the IdP's sub / NameID
    created_at    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (provider, subject)
);

CREATE TABLE workspaces (
    id            uuid PRIMARY KEY,
    name          text NOT NULL,
    created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE workspace_members (
    workspace_id  uuid NOT NULL REFERENCES workspaces(id),
    user_id       uuid NOT NULL REFERENCES users(id),
    role          text NOT NULL,             -- owner | admin | member | guest
    joined_at     timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, user_id)
);

-- Refresh tokens are persisted (rotation + revocation). Access tokens are NOT stored.
CREATE TABLE refresh_tokens (
    id            uuid PRIMARY KEY,          -- the token's jti family root
    user_id       uuid NOT NULL REFERENCES users(id),
    token_hash    bytea NOT NULL,            -- SHA-256 of the opaque refresh token
    issued_at     timestamptz NOT NULL DEFAULT now(),
    expires_at    timestamptz NOT NULL,
    rotated_to    uuid NULL REFERENCES refresh_tokens(id),  -- set when rotated
    revoked_at    timestamptz NULL
);
CREATE INDEX ix_refresh_user ON refresh_tokens (user_id) WHERE revoked_at IS NULL;
```

SQLAlchemy models map one-to-one to these tables; Alembic owns the migration history.

### 4.1 Redis (R1) usage
- `auth:revoked:{jti}` → `"1"`, TTL = remaining access-token lifetime. Written on logout.
- `auth:userinfo:{userId}` → cached profile blob, short TTL, to speed up `/userinfo`.

---

## 5. Internal Design

### 5.1 Login flow (OIDC, PKCE)
1. SPA hits `/auth/login/{provider}` → 302 to external IdP.
2. IdP redirects to `/auth/callback/{provider}`; service validates, upserts `users` +
   `external_identities`, then redirects to the SPA redirect URI with a short-lived auth code.
3. SPA calls `/auth/token` with the code + PKCE `code_verifier` → access + refresh tokens.

### 5.2 Refresh rotation
On `/auth/refresh`: look up by `token_hash`, ensure not revoked/expired, mint a new pair,
set `rotated_to` and `revoked_at` on the old row (reuse of a rotated token ⇒ revoke the whole
family and 401 — detects token theft).

### 5.3 Token verification (for other services)
Other services do NOT call this service per request. They fetch JWKS and verify locally with
PyJWT/Authlib (Conventions §5). This service only needs to keep JWKS current and maintain the
denylist.

---

## 6. Configuration

Common vars per Conventions §8, plus:

| Var | Notes |
|-----|-------|
| `AUTH_SIGNING_KEY` | PEM RSA private key (secret). Active `kid`. |
| `AUTH_PREVIOUS_KEYS` | Prior public keys still valid for verification (rotation). |
| `AUTH_ACCESS_TOKEN_MINUTES` | Default 15. |
| `AUTH_REFRESH_TOKEN_DAYS` | Default 30. |
| `OIDC_{PROVIDER}_AUTHORITY` / `_CLIENT_ID` / `_CLIENT_SECRET` | Per external IdP. |
| `SAML_{PROVIDER}_METADATA_URL` | Per SAML IdP. |
| `SPA_REDIRECT_URI` | Allowed post-login redirect. |

---

## 7. Cross-Cutting
Error envelope, health checks, observability, logging per Conventions §4.2, §9, §10.
Emit metric `auth_tokens_issued_total`, `auth_logins_total{provider}`, `auth_refresh_reuse_total`.

---

## 8. Non-Functional & Limits
- Token issuance p99 < 100 ms.
- JWKS cacheable (`Cache-Control`), so verification scales without hitting this service.
- Rate-limit `/auth/token` and `/auth/refresh` per IP + per user.

---

## 9. Open Decisions
- Acting as a full OIDC OP for first-party clients vs. only federating to an upstream IdP.
- Multi-workspace membership and the workspace-switch flow (affects the `wsp` claim — see
  Conventions §12.2).
- Whether SAML is in scope for v1 or deferred.
- Refresh tokens stored hashed in Postgres here; could move to R1 — confirm durability need.
