# helm-opencti 🛡️

An opinionated Helm chart for [OpenCTI](https://github.com/OpenCTI-Platform/opencti) with auto-wiring, external service support, and native RabbitMQ.

Published to OCI: `oci://ghcr.io/dapperdivers/helm-opencti/opencti`

## Install

```bash
helm install opencti oci://ghcr.io/dapperdivers/helm-opencti/opencti \
  -n opencti --create-namespace \
  --set opencti.adminPassword=changeme \
  --set opencti.adminToken=$(uuidgen) \
  --set opencti.encryptionKey=$(openssl rand -base64 32) \
  --set rabbitmq.auth.password=changeme \
  --set rustfs.secret.rustfs.secret_key=$(openssl rand -hex 20) \
  --set externalRedis.hostname=your-redis-host
```

No Redis yet? Replace the last flag with `--set redis.enabled=true` to deploy the bundled Dragonfly.

> `opencti.encryptionKey` is mandatory since OpenCTI 7. Generate it once and keep it: the platform uses it to encrypt stored API tokens.

## Key Design Decisions

**Auto-wired service URLs** — Service hostnames for OpenSearch, RabbitMQ, S3, and Redis are resolved from chart state. No hardcoded `release-name-*` defaults to override.

**Single-source admin token** — Set `opencti.adminToken` once. It propagates to server, workers, and all connectors automatically. Optional `connectorTokenExistingSecret` for least-privilege separation.

**No credentials in pod specs** — Every credential reaches containers through a `secretKeyRef`, whether you set it inline (stored in the chart's `<fullname>-credentials` Secret) or point at your own Secret. Health probes run inside the container and read the access key from the environment, so it never appears in a probe URL.

**Hardened by default** — Server and workers run as non-root with a read-only root filesystem, all capabilities dropped and the `RuntimeDefault` seccomp profile.

**Native RabbitMQ** — No Bitnami subchart dependency. Purpose-built StatefulSet using `rabbitmq:4.1-management-alpine` with OpenCTI-tuned settings (`consumer_timeout=24h`, `max_message_size=512MB`).

**External service blocks** — First-class config for `externalRedis`, `externalElasticsearch`, `externalRabbitmq`, and `externalS3`, each with an `existingSecret` option. Toggle subcharts on/off, point at your existing infrastructure.

**readyChecker enabled by default** — Init containers verify all dependencies (OpenSearch, RabbitMQ, Redis, S3) are reachable before server/workers/connectors start. Eliminates crashloop cascades.

**Connector auto-injection** — Connectors only need their specific env vars. `OPENCTI_URL` and `OPENCTI_TOKEN` are injected automatically. Per-connector secrets via `envFromSecrets`. Global connector env via `connectorsGlobal`.

**Structured values** — `server:`, `worker:`, `connectors:` hierarchy instead of a flat 1300-line env map.

## Architecture

```
┌──────────────────────────────────────────────────────┐
│  ┌──────────┐   ┌──────────┐   ┌────────────────┐   │
│  │  Server   │◄──│ Workers  │   │  Connectors    │   │
│  │ (GraphQL) │   │  (×N)    │   │ (CISA,CVE,...) │   │
│  └────┬──┬──┘   └────┬─────┘   └───────┬────────┘   │
│       │  └────────────┴─────────────────┘            │
│       │       OPENCTI_URL + OPENCTI_TOKEN            │
│       │            (auto-wired)                      │
│  ┌────┴────┐  ┌──────────┐  ┌───────┐  ┌────────┐   │
│  │OpenSearch│  │ RabbitMQ │  │RustFS │  │ Redis  │   │
│  │(subchart)│  │ (native) │  │(sub.) │  │(extern)│   │
│  └─────────┘  └──────────┘  └───────┘  └────────┘   │
└──────────────────────────────────────────────────────┘
```

## Connectors

```yaml
connectors:
  cisa-known-exploited-vulnerabilities:
    enabled: true
    env:
      CONNECTOR_ID: "uuid"
      CONNECTOR_NAME: "CISA KEV"
      CONNECTOR_SCOPE: "cisa"
      CONNECTOR_DURATION_PERIOD: "PT24H"

  alienvault:
    enabled: true
    env:
      CONNECTOR_ID: "uuid"
      CONNECTOR_NAME: "AlienVault OTX"
    envFromSecrets:
      ALIENVAULT_API_KEY:
        name: opencti-secrets
        key: alienvault-api-key
```

Pre-built bundles in `connector-presets/free-threat-intel.yaml` (CISA KEV, CVE, MITRE, EPSS, URLhaus, ThreatFox, MalwareBazaar, DISARM — all free, no API keys).

## Secrets

```yaml
# Inline (dev only) — stored in the chart-managed <fullname>-credentials Secret
opencti:
  adminPassword: "..."
  adminToken: "..."
  encryptionKey: "..."

# Existing Secret (recommended)
opencti:
  adminPasswordExistingSecret: {name: opencti-credentials, key: password}
  adminTokenExistingSecret:    {name: opencti-credentials, key: token}
  encryptionKeyExistingSecret: {name: opencti-credentials, key: encryption-key}
  # Optional
  connectorTokenExistingSecret:  {name: opencti-credentials, key: connector-token}
  healthAccessKeyExistingSecret: {name: opencti-credentials, key: health-access-key}
```

The external service blocks and the built-in RabbitMQ take `existingSecret` the same way.

### Generated credentials with External Secrets

None of these values need to be typed by a person. Generate them in the cluster, let the chart read the resulting Secret, and back it up to your secret manager with a `PushSecret` so a rebuild restores the same values (the encryption key in particular must survive a rebuild).

```yaml
apiVersion: external-secrets.io/v1alpha1
kind: PushSecret
metadata:
  name: opencti-credentials
spec:
  refreshInterval: 1h
  secretStoreRefs:
    - kind: ClusterSecretStore
      name: infisical
  selector:
    secret:
      name: opencti-credentials
  data:
    - match:
        secretKey: encryption-key
        remoteRef:
          remoteKey: /OpenCTI/encryption-key   # keep pushed secrets in a folder, not the vault root
    - match:
        secretKey: token
        remoteRef:
          remoteKey: /OpenCTI/admin-token
```

## External S3 (Garage, AWS, Ceph RGW)

```yaml
rustfs:
  enabled: false
externalS3:
  enabled: true
  endpoint: garage.storage.svc.cluster.local   # hostname only
  port: 3900
  region: garage                               # must match s3_region in garage.toml
  bucketName: opencti-bucket
  existingSecret: {name: opencti-s3}           # keys: access-key, secret-key
```

## Exposure and monitoring

```yaml
server:
  route:                    # Gateway API HTTPRoute (or use server.ingress)
    enabled: true
    parentRefs: [{name: internal, namespace: kube-system}]
    hostnames: [opencti.example.com]
  podDisruptionBudget:
    enabled: true

serviceMonitor:             # ServiceMonitor (server) + PodMonitor (workers)
  enabled: true
```

## Flux CD (OCI)

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: opencti
  namespace: flux-system
spec:
  type: oci
  interval: 1h
  url: oci://ghcr.io/dapperdivers/helm-opencti
```

> ⚠️ `flux reconcile source helm` does not work for OCI HelmRepositories. Use suspend/resume to force updates.

## Resource Budget

| Component | CPU | Memory | Storage |
|-----------|-----|--------|---------|
| Server | 2 | 4–8Gi | — |
| Workers (×3) | 1.5 | 1.5–3Gi | — |
| OpenSearch | 2 | 4–6Gi | 100Gi |
| RabbitMQ | 0.25 | 0.5–1Gi | 10Gi |
| RustFS (optional) | 0.25 | 512Mi | 20Gi |
| Dragonfly (optional) | 0.25 | 0.5–1Gi | — |
| Connectors (×8) | 0.8 | 2–4Gi | — |
| **Total** | **~7** | **~13–23Gi** | **~130Gi** |

## Upgrading to 0.5.0

- **OpenCTI 7.** Read the upstream [breaking changes](https://docs.opencti.io/latest/deployment/breaking-changes/) first: SSO configured through environment variables no longer works on Community Edition, and existing API tokens are migrated and encrypted.
- **`opencti.encryptionKey` is required** (or `encryptionKeyExistingSecret`).
- **Security context defaults changed.** Server and workers now run as UID 1000 with a read-only root filesystem. Override `server.securityContext` / `worker.securityContext` if you mount something that needs otherwise.
- **MinIO is replaced by RustFS.** MinIO's container images are no longer published, so the `minio` subchart could not be installed any more. Rename `minio:` to `rustfs:` (the values differ, see `values.yaml`) and set `rustfs.secret.rustfs.secret_key`, or switch to `externalS3`. Objects are **not** migrated: copy the bucket with `mc mirror` or `rclone sync` before upgrading if you need them.
- **The OpenSearch service name is now derived correctly** (`opensearch-cluster-master`); drop any `fullnameOverride` you added to work around the old name.
- **Redis:** set `redis.enabled=true` for the bundled Dragonfly, otherwise `externalRedis.hostname` is still required.
- The EPSS preset now uses the `opencti/connector-first-epss` image.

## License

MIT
