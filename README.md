# helm-opencti 🛡️

An opinionated Helm chart for [OpenCTI](https://github.com/OpenCTI-Platform/opencti) — built from scratch after 14 PRs of lessons learned with `devops-ia/helm-opencti`.

## Why Another Chart?

The community `devops-ia/helm-opencti` chart works, but has friction:

| Pain Point | devops-ia | This Chart |
|---|---|---|
| **Service URLs** | Hardcoded to `release-name-*` in default env | Auto-wired from subchart state |
| **Admin token** | Must be duplicated in server + workers + each connector | Single source in `opencti.adminToken`, auto-propagated |
| **External Redis** | Raw env vars (`REDIS__HOSTNAME`) | First-class `externalRedis:` config block |
| **External ES** | Raw env vars | First-class `externalElasticsearch:` block |
| **External RabbitMQ** | Raw env vars | First-class `externalRabbitmq:` block |
| **External S3** | Raw env vars | First-class `externalS3:` block |
| **readyChecker** | Disabled by default | **Enabled by default** — dependencies checked before startup |
| **Connector config** | Each connector needs `OPENCTI_URL` + `OPENCTI_TOKEN` | Auto-injected, you only set connector-specific env |
| **Connector presets** | Copy-paste examples | Pre-built values files for common connector bundles |
| **Secrets** | Inline plaintext or manual secret refs | `existingSecret` pattern + ExternalSecret examples |
| **Health probes** | Basic | Startup probe (5-min grace), liveness, readiness all configured |
| **Values structure** | Flat `env:` map with 1300 lines | Structured `server:`/`worker:`/`connectors:` hierarchy |

## Quick Start

```bash
# Install from OCI registry
helm install opencti oci://ghcr.io/dapperdivers/helm-opencti/opencti \
  -n opencti --create-namespace \
  --set opencti.adminPassword=changeme \
  --set opencti.adminToken=$(uuidgen) \
  --set rabbitmq.auth.password=changeme \
  --set externalRedis.hostname=your-redis-host
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    OpenCTI Namespace                      │
│                                                          │
│  ┌──────────┐    ┌──────────┐    ┌──────────────────┐   │
│  │  Server   │◄──│ Workers  │    │   Connectors     │   │
│  │ (GraphQL) │    │  (×3)    │    │ (CISA, CVE, ...) │   │
│  └────┬──┬──┘    └────┬─────┘    └────────┬─────────┘   │
│       │  │            │                    │             │
│       │  └────────────┴────────────────────┘             │
│       │         OPENCTI_URL + OPENCTI_TOKEN              │
│       │              (auto-wired)                        │
│  ┌────┴────┐  ┌──────────┐  ┌───────┐  ┌──────────┐   │
│  │OpenSearch│  │ RabbitMQ │  │ MinIO │  │  Redis   │   │
│  │(subchart)│  │(subchart)│  │(sub.) │  │(external)│   │
│  └─────────┘  └──────────┘  └───────┘  └──────────┘   │
└─────────────────────────────────────────────────────────┘
```

## Configuration

### Core Config (Single Source of Truth)

```yaml
opencti:
  adminEmail: admin@opencti.io
  adminPassword: "my-secret-password"
  adminToken: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
```

These values are automatically propagated to:
- ✅ Server deployment
- ✅ All worker pods
- ✅ Every connector

### Dedicated Connector Token

Use a separate token for connectors (least-privilege):

```yaml
opencti:
  adminTokenExistingSecret:
    name: opencti-secrets
    key: admin-token
  connectorTokenExistingSecret:
    name: opencti-secrets
    key: connector-token
```

### External Services

Instead of raw env vars, use structured config blocks:

```yaml
# External Redis (Dragonfly, Valkey, etc.)
externalRedis:
  enabled: true
  hostname: dragonfly.database.svc.cluster.local
  port: 6379
  mode: single

# External Elasticsearch/OpenSearch
externalElasticsearch:
  enabled: true
  url: http://opensearch.database:9200

# Disable the corresponding subchart
opensearch:
  enabled: false
```

### Connectors

Connectors only need their specific config — `OPENCTI_URL` and `OPENCTI_TOKEN` are auto-injected:

```yaml
connectors:
  cisa-known-exploited-vulnerabilities:
    enabled: true
    image:
      repository: opencti/connector-cisa-known-exploited-vulnerabilities
    env:
      CONNECTOR_ID: "my-uuid"
      CONNECTOR_NAME: "CISA KEV"
      CONNECTOR_SCOPE: "cisa"
      CONNECTOR_DURATION_PERIOD: "PT24H"
```

Per-connector secrets via `envFromSecrets`:

```yaml
connectors:
  alienvault:
    enabled: true
    image:
      repository: opencti/connector-alienvault
    env:
      CONNECTOR_ID: "my-uuid"
      CONNECTOR_NAME: "AlienVault OTX"
    envFromSecrets:
      ALIENVAULT_API_KEY:
        name: opencti-secrets
        key: alienvault-api-key
```

### Connector Presets

Pre-built connector bundles in `connector-presets/`:

| Preset | Connectors | API Keys? |
|--------|-----------|-----------|
| `free-threat-intel.yaml` | CISA KEV, CVE, MITRE, EPSS, OpenCTI Datasets, URLhaus, ThreatFox, MalwareBazaar, DISARM | ❌ All free |

### Secrets Management

Three patterns supported:

```yaml
# 1. Inline (dev/testing only)
opencti:
  adminToken: "my-token"

# 2. Existing K8s Secret
opencti:
  adminTokenExistingSecret:
    name: opencti-credentials
    key: admin-token

# 3. ExternalSecret (recommended for production)
# Create an ExternalSecret that produces the K8s Secret referenced above
```

## Flux GitOps (OCI)

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
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: opencti
spec:
  chart:
    spec:
      chart: opencti
      version: "0.1.x"
      sourceRef:
        kind: HelmRepository
        name: opencti
  values:
    # your overrides here
```

## Resource Budget

| Component | CPU | Memory | Storage |
|-----------|-----|--------|---------|
| Server | 2 | 4-8Gi | — |
| Workers ×3 | 1.5 | 1.5-3Gi | — |
| OpenSearch | 2 | 4-6Gi | 100Gi |
| RabbitMQ | 0.5 | 1Gi | 10Gi |
| MinIO | 0.25 | 512Mi | 20Gi |
| Connectors (×10) | 1 | 2.5-5Gi | — |
| **Total** | **~7** | **~14-24Gi** | **~130Gi** |

## License

MIT
