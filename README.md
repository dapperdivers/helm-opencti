# helm-opencti 🛡️

An opinionated Helm chart for [OpenCTI](https://github.com/OpenCTI-Platform/opencti) with auto-wiring, external service support, and native RabbitMQ.

Published to OCI: `oci://ghcr.io/dapperdivers/helm-opencti/opencti`

## Install

```bash
helm install opencti oci://ghcr.io/dapperdivers/helm-opencti/opencti \
  -n opencti --create-namespace \
  --set opencti.adminPassword=changeme \
  --set opencti.adminToken=$(uuidgen) \
  --set rabbitmq.auth.password=changeme \
  --set externalRedis.hostname=your-redis-host
```

## Key Design Decisions

**Auto-wired service URLs** — Service hostnames for OpenSearch, RabbitMQ, MinIO, and Redis are resolved from chart state. No hardcoded `release-name-*` defaults to override.

**Single-source admin token** — Set `opencti.adminToken` once. It propagates to server, workers, and all connectors automatically. Optional `connectorTokenExistingSecret` for least-privilege separation.

**Native RabbitMQ** — No Bitnami subchart dependency. Purpose-built StatefulSet using `rabbitmq:4.1-management-alpine` with OpenCTI-tuned settings (`consumer_timeout=24h`, `max_message_size=512MB`).

**External service blocks** — First-class config for `externalRedis`, `externalElasticsearch`, `externalRabbitmq`, and `externalS3`. Toggle subcharts on/off, point at your existing infrastructure.

**readyChecker enabled by default** — Init containers verify all dependencies (OpenSearch, RabbitMQ, Redis, MinIO) are reachable before server/workers/connectors start. Eliminates crashloop cascades.

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
│  │OpenSearch│  │ RabbitMQ │  │ MinIO │  │ Redis  │   │
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
# Inline (dev only)
opencti:
  adminToken: "my-token"

# Existing Secret (recommended)
opencti:
  adminTokenExistingSecret:
    name: opencti-credentials
    key: admin-token

# Separate connector token (least-privilege)
opencti:
  connectorTokenExistingSecret:
    name: opencti-credentials
    key: connector-token
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
| MinIO | 0.25 | 512Mi | 20Gi |
| Connectors (×8) | 0.8 | 2–4Gi | — |
| **Total** | **~7** | **~13–23Gi** | **~130Gi** |

## License

MIT
