{{/*
Expand the name of the chart.
*/}}
{{- define "kubex-automation-controller.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "kubex-automation-controller.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "kubex-automation-controller.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "kubex-automation-controller.labels" -}}
helm.sh/chart: {{ include "kubex-automation-controller.chart" . }}
{{ include "kubex-automation-controller.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "kubex-automation-controller.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubex-automation-controller.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "kubex-automation-controller.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "kubex-automation-controller.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "kubex-automation-controller.env_vars" }}
- name: CLUSTER_NAME
  valueFrom:
    configMapKeyRef:
      name: kubex-config
      key: CLUSTER_NAME
- name: DEBUG
  value: {{ .Values.deployment.controllerEnv.debug | quote }}
{{- end }}

{{- define "kubex-automation-controller.kubex-automation-controller-clusterrole-rules" }}
  - apiGroups: [""]
    resources: ["namespaces", "nodes", "limitranges", "resourcequotas", "services"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["replicasets", "deployments"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["batch"]
    resources: ["jobs"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["pods/eviction"]
    verbs: ["create"]
  - nonResourceURLs:
    - "/metrics"
    verbs:
    - "get"
{{- end }}

{{/*
Generate Densify epassword that persists across upgrades
*/}}
{{- define "kubex-automation-controller.densifyEpassword" -}}
{{- if .Values.createSecrets }}
{{- .Values.densifyCredentials.epassword | required "An epassword must be provided in kubex-automation-values.yaml under densifyCredentials.epassword" -}}
{{- end }}
{{- end }}
{{/*
Generate Densify username that persists across upgrades
*/}}
{{- define "kubex-automation-controller.densifyUsername" -}}
{{- if .Values.createSecrets }}
{{- .Values.densifyCredentials.username | required "A username must be provided in kubex-automation-values.yaml under valkey.densifyCredentials.username" -}}
{{- end }}
{{- end }}
{{/*
Generate Valkey password that persists across upgrades
*/}}
{{- define "kubex-automation-controller.valkeyPassword" -}}
{{- if .Values.createSecrets }}
{{- .Values.valkey.credentials.password | required "A password must be provided in kubex-automation-values.yaml under valkey.credentials.password" -}}
{{- end }}
{{- end }}
{{/*
Generate Valkey username - defaults to kubexAutomation but can be overridden
*/}}
{{- define "kubex-automation-controller.valkeyUsername" -}}
{{- if .Values.createSecrets }}
{{- .Values.valkey.credentials.user | default "kubexAutomation" -}}
{{- end }}
{{- end }}

{{- define "kubex-automation-controller.densifyUserSecretName" -}}
{{- .Values.densifyCredentials.userSecretName | default "kubex-api-secret-container-automation" -}}
{{- end }}
