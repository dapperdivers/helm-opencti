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
     AUTO-WIRING: Resolve service names from chart state
     ====================================================================== */}}

{{/*
Fullname of a subchart that uses the standard Helm fullname convention.
Usage: include "opencti.subchartFullname" (dict "root" . "name" "redis" "values" .Values.redis)
*/}}
{{- define "opencti.subchartFullname" -}}
{{- if .values.fullnameOverride -}}
  {{- .values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
  {{- $name := default .name .values.nameOverride -}}
  {{- if contains $name .root.Release.Name -}}
    {{- .root.Release.Name | trunc 63 | trimSuffix "-" -}}
  {{- else -}}
    {{- printf "%s-%s" .root.Release.Name $name | trunc 63 | trimSuffix "-" -}}
  {{- end -}}
{{- end -}}
{{- end }}

{{/*
OpenSearch subchart service name. The opensearch chart names its service
<clusterName>-<nodeGroup> and does not include the release name.
*/}}
{{- define "opencti.opensearchHost" -}}
{{- if .Values.opensearch.fullnameOverride -}}
  {{- .Values.opensearch.fullnameOverride -}}
{{- else -}}
  {{- printf "%s-%s" (.Values.opensearch.clusterName | default "opensearch-cluster") (.Values.opensearch.nodeGroup | default "master") -}}
{{- end -}}
{{- end }}

{{/*
RustFS subchart service name (the rustfs chart always appends "-svc")
*/}}
{{- define "opencti.rustfsHost" -}}
{{- include "opencti.subchartFullname" (dict "root" . "name" "rustfs" "values" .Values.rustfs) -}}-svc
{{- end }}

{{- define "opencti.redisSubchartHost" -}}
{{- include "opencti.subchartFullname" (dict "root" . "name" "redis" "values" .Values.redis) -}}
{{- end }}

{{/*
Elasticsearch/OpenSearch URL
*/}}
{{- define "opencti.elasticsearchUrl" -}}
{{- if .Values.externalElasticsearch.enabled -}}
  {{- required "externalElasticsearch.url is required when externalElasticsearch.enabled=true" .Values.externalElasticsearch.url -}}
{{- else if .Values.opensearch.enabled -}}
  http://{{ include "opencti.opensearchHost" . }}:9200
{{- else -}}
  {{- fail "Either opensearch.enabled or externalElasticsearch.enabled must be true" -}}
{{- end -}}
{{- end }}

{{/*
Redis — bundled Dragonfly subchart (redis.enabled) wins, otherwise externalRedis
*/}}
{{- define "opencti.redisHostname" -}}
{{- if .Values.redis.enabled -}}
  {{- include "opencti.redisSubchartHost" . -}}
{{- else if .Values.externalRedis.enabled -}}
  {{- required "externalRedis.hostname is required (or set redis.enabled=true to deploy the bundled Dragonfly)" .Values.externalRedis.hostname -}}
{{- else -}}
  {{- fail "Either redis.enabled or externalRedis.enabled must be true" -}}
{{- end -}}
{{- end }}

{{- define "opencti.redisPort" -}}
{{- if .Values.redis.enabled -}}
  6379
{{- else -}}
  {{- .Values.externalRedis.port | default 6379 -}}
{{- end -}}
{{- end }}

{{- define "opencti.redisMode" -}}
{{- if .Values.redis.enabled -}}
  single
{{- else -}}
  {{- .Values.externalRedis.mode | default "single" -}}
{{- end -}}
{{- end }}

{{/*
RabbitMQ
*/}}
{{- define "opencti.rabbitmqHostname" -}}
{{- if .Values.externalRabbitmq.enabled -}}
  {{- required "externalRabbitmq.hostname is required when externalRabbitmq.enabled=true" .Values.externalRabbitmq.hostname -}}
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
  {{- .Values.rabbitmq.auth.username | default "user" -}}
{{- end -}}
{{- end }}

{{/*
S3 — externalS3 (Garage, AWS, Ceph RGW, ...) or the RustFS subchart
*/}}
{{- define "opencti.minioEndpoint" -}}
{{- if .Values.externalS3.enabled -}}
  {{- required "externalS3.endpoint is required when externalS3.enabled=true" .Values.externalS3.endpoint -}}
{{- else if .Values.rustfs.enabled -}}
  {{- include "opencti.rustfsHost" . -}}
{{- else -}}
  {{- fail "Either rustfs.enabled or externalS3.enabled must be true" -}}
{{- end -}}
{{- end }}

{{/*
OpenCTI server internal URL (for workers + connectors)
*/}}
{{- define "opencti.serverUrl" -}}
http://{{ include "opencti.fullname" . }}-server:{{ .Values.server.service.port }}{{ include "opencti.basePathPrefix" . }}
{{- end }}

{{/*
Base path without trailing slash ("" when basePath is "/")
*/}}
{{- define "opencti.basePathPrefix" -}}
{{- .Values.opencti.basePath | default "/" | trimSuffix "/" -}}
{{- end }}

{{/* ======================================================================
     CREDENTIALS: every credential reaches pods through a secretKeyRef.
     Inline values land in the chart-managed "<fullname>-credentials" Secret;
     *ExistingSecret / existingSecret options point at your own Secret.
     ====================================================================== */}}

{{- define "opencti.credentialsSecretName" -}}
{{- include "opencti.fullname" . }}-credentials
{{- end }}

{{/*
Render a valueFrom.secretKeyRef block.
Usage: include "opencti.secretRef" (dict "root" . "existing" $ref "defaultKey" "token" "chartKey" "admin-token")
  existing   — optional {name, key} pointing at a user-managed Secret
  defaultKey — key used when existing.key is not set
  chartKey   — key in the chart-managed credentials Secret (used when existing is empty)
*/}}
{{- define "opencti.secretRef" -}}
valueFrom:
  secretKeyRef:
    {{- if and .existing .existing.name }}
    name: {{ .existing.name }}
    key: {{ .existing.key | default .defaultKey }}
    {{- else }}
    name: {{ include "opencti.credentialsSecretName" .root }}
    key: {{ .chartKey }}
    {{- end }}
{{- end }}

{{- define "opencti.adminTokenRef" -}}
{{- include "opencti.secretRef" (dict "root" . "existing" .Values.opencti.adminTokenExistingSecret "defaultKey" "token" "chartKey" "admin-token") }}
{{- end }}

{{- define "opencti.connectorTokenRef" -}}
{{- if .Values.opencti.connectorTokenExistingSecret }}
{{- include "opencti.secretRef" (dict "root" . "existing" .Values.opencti.connectorTokenExistingSecret "defaultKey" "token" "chartKey" "admin-token") }}
{{- else }}
{{- include "opencti.adminTokenRef" . }}
{{- end }}
{{- end }}

{{/*
Health access key: its own secret, its own inline value, or the admin token.
*/}}
{{- define "opencti.healthAccessKeyRef" -}}
{{- if .Values.opencti.healthAccessKeyExistingSecret }}
{{- include "opencti.secretRef" (dict "root" . "existing" .Values.opencti.healthAccessKeyExistingSecret "defaultKey" "health-access-key" "chartKey" "health-access-key") }}
{{- else if .Values.opencti.healthAccessKey }}
{{- include "opencti.secretRef" (dict "root" . "chartKey" "health-access-key") }}
{{- else }}
{{- include "opencti.adminTokenRef" . }}
{{- end }}
{{- end }}

{{- define "opencti.rabbitmqPasswordRef" -}}
{{- if .Values.externalRabbitmq.enabled }}
{{- include "opencti.secretRef" (dict "root" . "existing" .Values.externalRabbitmq.existingSecret "defaultKey" "rabbitmq-password" "chartKey" "rabbitmq-password") }}
{{- else }}
{{- include "opencti.secretRef" (dict "root" . "existing" .Values.rabbitmq.auth.existingSecret "defaultKey" "rabbitmq-password" "chartKey" "rabbitmq-password") }}
{{- end }}
{{- end }}

{{/*
Contents of the chart-managed credentials Secret (only inline values).
*/}}
{{- define "opencti.credentialsData" -}}
{{- if not .Values.opencti.adminTokenExistingSecret }}
admin-token: {{ required "opencti.adminToken is required (or set opencti.adminTokenExistingSecret)" .Values.opencti.adminToken | quote }}
{{- end }}
{{- if not .Values.opencti.adminPasswordExistingSecret }}
admin-password: {{ required "opencti.adminPassword is required (or set opencti.adminPasswordExistingSecret)" .Values.opencti.adminPassword | quote }}
{{- end }}
{{- if not .Values.opencti.encryptionKeyExistingSecret }}
encryption-key: {{ required "opencti.encryptionKey is required since OpenCTI 7 (generate with: openssl rand -base64 32), or set opencti.encryptionKeyExistingSecret" .Values.opencti.encryptionKey | quote }}
{{- end }}
{{- if and .Values.opencti.healthAccessKey (not .Values.opencti.healthAccessKeyExistingSecret) }}
health-access-key: {{ .Values.opencti.healthAccessKey | quote }}
{{- end }}
{{- if .Values.externalRabbitmq.enabled }}
{{- if not .Values.externalRabbitmq.existingSecret }}
rabbitmq-password: {{ required "externalRabbitmq.password is required (or set externalRabbitmq.existingSecret)" .Values.externalRabbitmq.password | quote }}
{{- end }}
{{- else if and .Values.rabbitmq.enabled (not .Values.rabbitmq.auth.existingSecret) }}
rabbitmq-password: {{ required "rabbitmq.auth.password is required (or set rabbitmq.auth.existingSecret)" .Values.rabbitmq.auth.password | quote }}
{{- end }}
{{- if and (not .Values.redis.enabled) .Values.externalRedis.password (not .Values.externalRedis.existingSecret) }}
redis-password: {{ .Values.externalRedis.password | quote }}
{{- end }}
{{- if and .Values.externalElasticsearch.enabled .Values.externalElasticsearch.password (not .Values.externalElasticsearch.existingSecret) }}
elasticsearch-password: {{ .Values.externalElasticsearch.password | quote }}
{{- end }}
{{- if .Values.externalS3.enabled }}
{{- if not .Values.externalS3.existingSecret }}
s3-access-key: {{ required "externalS3.accessKey is required (or set externalS3.existingSecret)" .Values.externalS3.accessKey | quote }}
s3-secret-key: {{ required "externalS3.secretKey is required (or set externalS3.existingSecret)" .Values.externalS3.secretKey | quote }}
{{- end }}
{{- else if .Values.rustfs.enabled }}
s3-access-key: {{ required "rustfs.secret.rustfs.access_key is required" .Values.rustfs.secret.rustfs.access_key | quote }}
s3-secret-key: {{ required "rustfs.secret.rustfs.secret_key is required (or disable rustfs and use externalS3)" .Values.rustfs.secret.rustfs.secret_key | quote }}
{{- end }}
{{- end }}

{{/*
Build the auto-wired environment variables for the server
*/}}
{{- define "opencti.serverEnv" -}}
# -- App config
- name: APP__ADMIN__EMAIL
  value: {{ .Values.opencti.adminEmail | quote }}
- name: APP__ADMIN__PASSWORD
  {{- include "opencti.secretRef" (dict "root" . "existing" .Values.opencti.adminPasswordExistingSecret "defaultKey" "password" "chartKey" "admin-password") | nindent 2 }}
- name: APP__ADMIN__TOKEN
  {{- include "opencti.adminTokenRef" . | nindent 2 }}
- name: APP__ENCRYPTION_KEY
  {{- include "opencti.secretRef" (dict "root" . "existing" .Values.opencti.encryptionKeyExistingSecret "defaultKey" "encryption-key" "chartKey" "encryption-key") | nindent 2 }}
- name: APP__HEALTH_ACCESS_KEY
  {{- include "opencti.healthAccessKeyRef" . | nindent 2 }}
- name: APP__BASE_PATH
  value: {{ .Values.opencti.basePath | default "/" | quote }}
- name: APP__TELEMETRY__METRICS__ENABLED
  value: {{ .Values.opencti.metrics.enabled | quote }}
- name: APP__APP_LOGS__LOGS_FILES
  value: "false"
- name: APP__AUDIT_LOGS__LOGS_FILES
  value: "false"
- name: NODE_OPTIONS
  value: {{ .Values.server.nodeOptions | default "--max-old-space-size=8096" | quote }}
# -- Auto-wired: Elasticsearch/OpenSearch
- name: ELASTICSEARCH__URL
  value: {{ include "opencti.elasticsearchUrl" . | trim | quote }}
{{- if .Values.externalElasticsearch.enabled }}
{{- if .Values.externalElasticsearch.username }}
- name: ELASTICSEARCH__USERNAME
  value: {{ .Values.externalElasticsearch.username | quote }}
{{- end }}
{{- if or .Values.externalElasticsearch.password .Values.externalElasticsearch.existingSecret }}
- name: ELASTICSEARCH__PASSWORD
  {{- include "opencti.secretRef" (dict "root" . "existing" .Values.externalElasticsearch.existingSecret "defaultKey" "password" "chartKey" "elasticsearch-password") | nindent 2 }}
{{- end }}
{{- end }}
# -- Auto-wired: Redis
- name: REDIS__HOSTNAME
  value: {{ include "opencti.redisHostname" . | trim | quote }}
- name: REDIS__PORT
  value: {{ include "opencti.redisPort" . | trim | quote }}
- name: REDIS__MODE
  value: {{ include "opencti.redisMode" . | trim | quote }}
{{- if and (not .Values.redis.enabled) (or .Values.externalRedis.password .Values.externalRedis.existingSecret) }}
- name: REDIS__PASSWORD
  {{- include "opencti.secretRef" (dict "root" . "existing" .Values.externalRedis.existingSecret "defaultKey" "password" "chartKey" "redis-password") | nindent 2 }}
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
- name: RABBITMQ__PASSWORD
  {{- include "opencti.rabbitmqPasswordRef" . | nindent 2 }}
# -- Auto-wired: S3 (RustFS subchart, Garage, AWS, ...). OpenCTI names these settings MINIO__*.
- name: MINIO__ENDPOINT
  value: {{ include "opencti.minioEndpoint" . | trim | quote }}
- name: MINIO__PORT
  value: {{ ternary (.Values.externalS3.port | default 9000) 9000 .Values.externalS3.enabled | quote }}
- name: MINIO__ACCESS_KEY
  {{- include "opencti.secretRef" (dict "root" . "existing" (ternary .Values.externalS3.existingSecret nil .Values.externalS3.enabled) "defaultKey" (dig "accessKeyKey" "access-key" (.Values.externalS3.existingSecret | default dict)) "chartKey" "s3-access-key") | nindent 2 }}
- name: MINIO__SECRET_KEY
  {{- include "opencti.secretRef" (dict "root" . "existing" (ternary .Values.externalS3.existingSecret nil .Values.externalS3.enabled) "defaultKey" (dig "secretKeyKey" "secret-key" (.Values.externalS3.existingSecret | default dict)) "chartKey" "s3-secret-key") | nindent 2 }}
- name: MINIO__BUCKET_NAME
  value: {{ ternary (.Values.externalS3.bucketName | default "opencti-bucket") "opencti-bucket" .Values.externalS3.enabled | quote }}
{{- if and .Values.externalS3.enabled .Values.externalS3.region }}
- name: MINIO__BUCKET_REGION
  value: {{ .Values.externalS3.region | quote }}
{{- end }}
- name: MINIO__USE_SSL
  value: {{ and .Values.externalS3.enabled .Values.externalS3.useSSL | ternary "true" "false" | quote }}
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
  {{- include "opencti.adminTokenRef" . | nindent 2 }}
{{- if .Values.worker.logLevel }}
- name: WORKER_LOG_LEVEL
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
  {{- include "opencti.connectorTokenRef" .root | nindent 2 }}
{{- end }}

{{/*
Health probe handler. Runs inside the server container so the access key is
read from the environment (a Secret) instead of being written into the pod spec.
*/}}
{{- define "opencti.healthProbe" -}}
exec:
  command:
    - node
    - -e
    - {{ printf "require('http').get({host:'127.0.0.1',port:%v,path:'%s/health?health_access_key='+encodeURIComponent(process.env.APP__HEALTH_ACCESS_KEY)},r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))" (.Values.server.service.targetPort | default 4000) (include "opencti.basePathPrefix" .) | quote }}
{{- end }}

{{/*
readyChecker init container — checks if a host:port is reachable
*/}}
{{- define "opencti.readyChecker" -}}
- name: ready-checker-{{ .name }}
  image: {{ .root.Values.readyChecker.image | default "busybox:1.37" }}
  imagePullPolicy: IfNotPresent
  securityContext:
    allowPrivilegeEscalation: false
    capabilities:
      drop: ["ALL"]
    readOnlyRootFilesystem: true
    runAsNonRoot: true
    runAsUser: 65534
  command:
    - sh
    - -c
    - |
      RETRY=0
      MAX={{ .root.Values.readyChecker.retries | default 60 }}
      until [ $RETRY -eq $MAX ]; do
        if nc -z -w 3 {{ .host }} {{ .port }} 2>&1; then
          echo "{{ .name }} ({{ .host }}:{{ .port }}) is ready"
          exit 0
        fi
        echo "[$RETRY/$MAX] waiting for {{ .name }} ({{ .host }}:{{ .port }})..."
        sleep {{ .root.Values.readyChecker.timeout | default 5 }}
        RETRY=$((RETRY + 1))
      done
      echo "{{ .name }} ({{ .host }}:{{ .port }}) not ready after $MAX retries"
      exit 1
{{- end }}

{{/*
readyChecker init containers for every backend the server depends on
*/}}
{{- define "opencti.dependencyCheckers" -}}
{{- if .Values.externalElasticsearch.enabled }}
{{- $es := urlParse .Values.externalElasticsearch.url }}
{{- $esHost := regexReplaceAll ":[0-9]+$" $es.host "" }}
{{- $esPort := regexFind "[0-9]+$" (regexFind ":[0-9]+$" $es.host) | default (ternary "443" "9200" (eq $es.scheme "https")) }}
{{ include "opencti.readyChecker" (dict "root" . "name" "elasticsearch" "host" $esHost "port" $esPort) }}
{{- else if .Values.opensearch.enabled }}
{{ include "opencti.readyChecker" (dict "root" . "name" "opensearch" "host" (include "opencti.opensearchHost" .) "port" 9200) }}
{{- end }}
{{ include "opencti.readyChecker" (dict "root" . "name" "rabbitmq" "host" (include "opencti.rabbitmqHostname" . | trim) "port" (include "opencti.rabbitmqPort" . | trim)) }}
{{ include "opencti.readyChecker" (dict "root" . "name" "redis" "host" (include "opencti.redisHostname" . | trim) "port" (include "opencti.redisPort" . | trim)) }}
{{ include "opencti.readyChecker" (dict "root" . "name" "s3" "host" (include "opencti.minioEndpoint" . | trim) "port" (ternary (.Values.externalS3.port | default 9000) 9000 .Values.externalS3.enabled)) }}
{{- end }}
