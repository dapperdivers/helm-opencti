{{/*
Expand the name of the chart.
*/}}
{{- define "opencti.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "opencti.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Chart label
*/}}
{{- define "opencti.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "opencti.labels" -}}
helm.sh/chart: {{ include "opencti.chart" . }}
{{ include "opencti.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | default .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "opencti.selectorLabels" -}}
app.kubernetes.io/name: {{ include "opencti.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Component-specific labels
*/}}
{{- define "opencti.serverLabels" -}}
{{ include "opencti.labels" . }}
app.kubernetes.io/component: server
{{- end }}

{{- define "opencti.serverSelectorLabels" -}}
{{ include "opencti.selectorLabels" . }}
app.kubernetes.io/component: server
{{- end }}

{{- define "opencti.workerLabels" -}}
{{ include "opencti.labels" . }}
app.kubernetes.io/component: worker
{{- end }}

{{- define "opencti.workerSelectorLabels" -}}
{{ include "opencti.selectorLabels" . }}
app.kubernetes.io/component: worker
{{- end }}

{{/*
ServiceAccount name
*/}}
{{- define "opencti.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "opencti.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/* ======================================================================
     AUTO-WIRING: Resolve service URLs from chart state
     ====================================================================== */}}

{{/*
Elasticsearch/OpenSearch URL — auto-wired from subchart or external config
*/}}
{{- define "opencti.elasticsearchUrl" -}}
{{- if .Values.externalElasticsearch.enabled -}}
  {{- .Values.externalElasticsearch.url -}}
{{- else if .Values.opensearch.enabled -}}
  http://{{ .Values.opensearch.fullnameOverride | default "opensearch-cluster-master" }}:9200
{{- else -}}
  {{- fail "Either opensearch.enabled or externalElasticsearch.enabled must be true" -}}
{{- end -}}
{{- end }}

{{/*
Redis URL components — auto-wired from subchart or external config
*/}}
{{- define "opencti.redisHostname" -}}
{{- if .Values.externalRedis.enabled -}}
  {{- .Values.externalRedis.hostname -}}
{{- else -}}
  {{- fail "externalRedis.enabled must be true (no built-in Redis subchart; use Dragonfly, Redis, or Valkey)" -}}
{{- end -}}
{{- end }}

{{- define "opencti.redisPort" -}}
{{- if .Values.externalRedis.enabled -}}
  {{- .Values.externalRedis.port | default 6379 -}}
{{- else -}}
  6379
{{- end -}}
{{- end }}

{{- define "opencti.redisMode" -}}
{{- if .Values.externalRedis.enabled -}}
  {{- .Values.externalRedis.mode | default "single" -}}
{{- else -}}
  single
{{- end -}}
{{- end }}

{{/*
RabbitMQ — auto-wired from subchart or external config
*/}}
{{- define "opencti.rabbitmqHostname" -}}
{{- if .Values.externalRabbitmq.enabled -}}
  {{- .Values.externalRabbitmq.hostname -}}
{{- else if .Values.rabbitmq.enabled -}}
  {{- include "opencti.fullname" . }}-rabbitmq
{{- else -}}
  {{- fail "Either rabbitmq.enabled or externalRabbitmq.enabled must be true" -}}
{{- end -}}
{{- end }}

{{- define "opencti.rabbitmqPort" -}}
{{- if .Values.externalRabbitmq.enabled -}}
  {{- .Values.externalRabbitmq.port | default 5672 -}}
{{- else -}}
  5672
{{- end -}}
{{- end }}

{{- define "opencti.rabbitmqManagementPort" -}}
{{- if .Values.externalRabbitmq.enabled -}}
  {{- .Values.externalRabbitmq.managementPort | default 15672 -}}
{{- else -}}
  15672
{{- end -}}
{{- end }}

{{- define "opencti.rabbitmqUsername" -}}
{{- if .Values.externalRabbitmq.enabled -}}
  {{- .Values.externalRabbitmq.username | default "user" -}}
{{- else -}}
  user
{{- end -}}
{{- end }}

{{/*
MinIO/S3 — auto-wired from subchart or external config
*/}}
{{- define "opencti.minioEndpoint" -}}
{{- if .Values.externalS3.enabled -}}
  {{- .Values.externalS3.endpoint -}}
{{- else if .Values.minio.enabled -}}
  {{- printf "http://%s-minio:9000" (include "opencti.fullname" .) -}}
{{- else -}}
  {{- fail "Either minio.enabled or externalS3.enabled must be true" -}}
{{- end -}}
{{- end }}

{{/*
OpenCTI server internal URL (for workers + connectors)
*/}}
{{- define "opencti.serverUrl" -}}
http://{{ include "opencti.fullname" . }}-server:{{ .Values.server.service.port }}
{{- end }}

{{/*
Admin token — resolved from secret or values
The single source of truth, propagated to workers + connectors automatically.
*/}}
{{- define "opencti.adminToken" -}}
{{- if .Values.opencti.adminTokenExistingSecret -}}
  __FROM_SECRET__
{{- else -}}
  {{- required "opencti.adminToken is required (or set opencti.adminTokenExistingSecret)" .Values.opencti.adminToken -}}
{{- end -}}
{{- end }}

{{/*
Health access key
*/}}
{{- define "opencti.healthAccessKey" -}}
{{- if .Values.opencti.healthAccessKey -}}
  {{- .Values.opencti.healthAccessKey -}}
{{- else if not .Values.opencti.adminTokenExistingSecret -}}
  {{- include "opencti.adminToken" . -}}
{{- else -}}
  {{- fail "opencti.healthAccessKey is required when using adminTokenExistingSecret (token not available at template time)" -}}
{{- end -}}
{{- end }}

{{/*
Build the auto-wired environment variables for the server
*/}}
{{- define "opencti.serverEnv" -}}
# -- App config
- name: APP__ADMIN__EMAIL
  value: {{ .Values.opencti.adminEmail | quote }}
- name: APP__ADMIN__PASSWORD
  {{- if .Values.opencti.adminPasswordExistingSecret }}
  valueFrom:
    secretKeyRef:
      name: {{ .Values.opencti.adminPasswordExistingSecret.name }}
      key: {{ .Values.opencti.adminPasswordExistingSecret.key | default "password" }}
  {{- else }}
  value: {{ required "opencti.adminPassword is required" .Values.opencti.adminPassword | quote }}
  {{- end }}
- name: APP__ADMIN__TOKEN
  {{- if .Values.opencti.adminTokenExistingSecret }}
  valueFrom:
    secretKeyRef:
      name: {{ .Values.opencti.adminTokenExistingSecret.name }}
      key: {{ .Values.opencti.adminTokenExistingSecret.key | default "token" }}
  {{- else }}
  value: {{ include "opencti.adminToken" . | quote }}
  {{- end }}
- name: APP__BASE_PATH
  value: {{ .Values.opencti.basePath | default "/" | quote }}
- name: APP__HEALTH_ACCESS_KEY
  value: {{ include "opencti.healthAccessKey" . | quote }}
- name: APP__TELEMETRY__METRICS__ENABLED
  value: {{ .Values.opencti.metrics.enabled | default true | quote }}
- name: NODE_OPTIONS
  value: {{ .Values.server.nodeOptions | default "--max-old-space-size=8096" | quote }}
# -- Auto-wired: Elasticsearch/OpenSearch
- name: ELASTICSEARCH__URL
  value: {{ include "opencti.elasticsearchUrl" . | quote }}
{{- if .Values.externalElasticsearch.username }}
- name: ELASTICSEARCH__USERNAME
  value: {{ .Values.externalElasticsearch.username | quote }}
{{- end }}
{{- if .Values.externalElasticsearch.password }}
- name: ELASTICSEARCH__PASSWORD
  value: {{ .Values.externalElasticsearch.password | quote }}
{{- end }}
# -- Auto-wired: Redis
- name: REDIS__HOSTNAME
  value: {{ include "opencti.redisHostname" . | trim | quote }}
- name: REDIS__PORT
  value: {{ include "opencti.redisPort" . | trim | quote }}
- name: REDIS__MODE
  value: {{ include "opencti.redisMode" . | trim | quote }}
{{- if .Values.externalRedis.password }}
- name: REDIS__PASSWORD
  value: {{ .Values.externalRedis.password | quote }}
{{- end }}
# -- Auto-wired: RabbitMQ
- name: RABBITMQ__HOSTNAME
  value: {{ include "opencti.rabbitmqHostname" . | trim | quote }}
- name: RABBITMQ__PORT
  value: {{ include "opencti.rabbitmqPort" . | trim | quote }}
- name: RABBITMQ__PORT_MANAGEMENT
  value: {{ include "opencti.rabbitmqManagementPort" . | trim | quote }}
- name: RABBITMQ__USERNAME
  value: {{ include "opencti.rabbitmqUsername" . | trim | quote }}
{{- if .Values.externalRabbitmq.password }}
- name: RABBITMQ__PASSWORD
  value: {{ .Values.externalRabbitmq.password | quote }}
{{- else if .Values.rabbitmq.enabled }}
- name: RABBITMQ__PASSWORD
  {{- if .Values.rabbitmq.auth.existingSecret }}
  valueFrom:
    secretKeyRef:
      name: {{ .Values.rabbitmq.auth.existingSecret.name }}
      key: {{ .Values.rabbitmq.auth.existingSecret.key | default "rabbitmq-password" }}
  {{- else }}
  value: {{ .Values.rabbitmq.auth.password | quote }}
  {{- end }}
{{- end }}
# -- Auto-wired: MinIO/S3
- name: MINIO__ENDPOINT
  value: {{ include "opencti.minioEndpoint" . | trim | quote }}
{{- if or .Values.externalS3.accessKey .Values.minio.enabled }}
- name: MINIO__ACCESS_KEY
  {{- if .Values.externalS3.enabled }}
  value: {{ .Values.externalS3.accessKey | quote }}
  {{- else }}
  value: {{ .Values.minio.rootUser | default "minioadmin" | quote }}
  {{- end }}
- name: MINIO__SECRET_KEY
  {{- if .Values.externalS3.enabled }}
  value: {{ .Values.externalS3.secretKey | quote }}
  {{- else }}
  value: {{ .Values.minio.rootPassword | default "minioadmin" | quote }}
  {{- end }}
{{- end }}
{{- if .Values.externalS3.bucketName }}
- name: MINIO__BUCKET_NAME
  value: {{ .Values.externalS3.bucketName | quote }}
{{- end }}
{{- if .Values.externalS3.region }}
- name: MINIO__BUCKET_REGION
  value: {{ .Values.externalS3.region | quote }}
{{- end }}
{{- if .Values.externalS3.useSSL }}
- name: MINIO__USE_SSL
  value: "true"
{{- end }}
# -- Auth provider
- name: PROVIDERS__LOCAL__STRATEGY
  value: "LocalStrategy"
{{- end }}

{{/*
Build the auto-wired environment variables for workers
*/}}
{{- define "opencti.workerEnv" -}}
- name: OPENCTI_URL
  value: {{ include "opencti.serverUrl" . | quote }}
- name: OPENCTI_TOKEN
  {{- if .Values.opencti.adminTokenExistingSecret }}
  valueFrom:
    secretKeyRef:
      name: {{ .Values.opencti.adminTokenExistingSecret.name }}
      key: {{ .Values.opencti.adminTokenExistingSecret.key | default "token" }}
  {{- else }}
  value: {{ include "opencti.adminToken" . | quote }}
  {{- end }}
{{- if .Values.worker.logLevel }}
- name: OPENCTI_LOG_LEVEL
  value: {{ .Values.worker.logLevel | quote }}
{{- end }}
{{- if .Values.worker.telemetry.enabled }}
- name: WORKER_TELEMETRY_ENABLED
  value: "true"
- name: WORKER_PROMETHEUS_TELEMETRY_PORT
  value: {{ .Values.worker.telemetry.port | default 14269 | quote }}
{{- end }}
{{- end }}

{{/*
Build the auto-wired environment variables for a connector
*/}}
{{- define "opencti.connectorEnv" -}}
- name: OPENCTI_URL
  value: {{ include "opencti.serverUrl" .root | quote }}
- name: OPENCTI_TOKEN
  {{- if .root.Values.opencti.connectorTokenExistingSecret }}
  valueFrom:
    secretKeyRef:
      name: {{ .root.Values.opencti.connectorTokenExistingSecret.name }}
      key: {{ .root.Values.opencti.connectorTokenExistingSecret.key | default "token" }}
  {{- else if .root.Values.opencti.adminTokenExistingSecret }}
  valueFrom:
    secretKeyRef:
      name: {{ .root.Values.opencti.adminTokenExistingSecret.name }}
      key: {{ .root.Values.opencti.adminTokenExistingSecret.key | default "token" }}
  {{- else }}
  value: {{ include "opencti.adminToken" .root | quote }}
  {{- end }}
{{- end }}

{{/*
readyChecker init container — checks if a host:port is reachable
*/}}
{{- define "opencti.readyChecker" -}}
- name: ready-checker-{{ .name }}
  image: {{ $.image | default "busybox:1.37" }}
  imagePullPolicy: IfNotPresent
  command:
    - sh
    - -c
    - |
      RETRY=0
      MAX={{ $.retries | default 60 }}
      until [ $RETRY -eq $MAX ]; do
        if nc -zv {{ .host }} {{ .port }} 2>&1; then
          echo "✅ {{ .name }} ({{ .host }}:{{ .port }}) is ready"
          exit 0
        fi
        echo "⏳ [$RETRY/$MAX] waiting for {{ .name }} ({{ .host }}:{{ .port }})..."
        sleep {{ $.timeout | default 5 }}
        RETRY=$((RETRY + 1))
      done
      echo "❌ {{ .name }} ({{ .host }}:{{ .port }}) not ready after $MAX retries"
      exit 1
{{- end }}
